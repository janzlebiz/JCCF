-- ==============================================================================
-- Migration: 20261113_2345_m13_hardening_and_provenance.sql
-- Subsystem: M13 Interactive Personalization Engine (Hardening + Atomic Provenance)
-- Supersedes:
--   - 20261113_1335_m13_production_hardening.sql
--   - 20261113_2200_m13_rollback_provenance_fix.sql
-- Target DB: PostgreSQL 17.11 / Supabase
-- Scope:
--   1. Enforces transaction-local lock_timeout (5s) and statement_timeout (30s).
--   2. Verifies M13 tables, function, triggers, FK, and provenance preconditions.
--   3. Fixes search_path = pg_catalog and revokes unnecessary EXECUTE privileges
--      on public.m13_set_updated_at().
--   4. Inspects public.order_customizations(session_id) indexes:
--      - If a valid covering index already exists (exact name or another name),
--        preserves it and records NO ownership provenance.
--      - If no covering index exists, creates idx_order_customizations_session_id
--        and atomically records OID + definition provenance in
--        m13_internal.migration_index_provenance.
--   5. Does NOT alter public.rls_auto_enable().
-- Status: PRE-AUTHORIZATION SPECIFICATION (DO NOT APPLY WITHOUT OWNER RELEASE)
-- ==============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ==============================================================================
-- 0. Fail-Closed Precondition, Provenance Integrity & Drift Verification
-- ==============================================================================
DO $$
DECLARE
    v_func_count INT;
    v_func_oid OID;
    v_nargs INT;
    v_lang TEXT;
    v_rettype TEXT;
    v_secdef BOOLEAN;
    v_src TEXT;
    v_trg_count INT;
    v_fk_exists BOOLEAN;
    v_session_attnum SMALLINT;
    v_target_idx_def TEXT;
    v_existing_idx_name TEXT;
    v_col_count INT;
    v_conflict_count INT;
    v_prov RECORD;
    v_live_oid OID;
    v_live_def TEXT;
BEGIN
    -- 0.1 Verify all 3 M13 tables exist
    IF to_regclass('public.personalization_templates') IS NULL
       OR to_regclass('public.customization_sessions') IS NULL
       OR to_regclass('public.order_customizations') IS NULL THEN
        RAISE EXCEPTION 'M13 Preflight Failed: One or more M13 tables are missing. Aborting.';
    END IF;

    -- 0.2 Verify public.m13_set_updated_at() exists with exact signature & SECURITY INVOKER
    SELECT count(*), min(p.oid)
    INTO v_func_count, v_func_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';

    IF v_func_count <> 1 THEN
        RAISE EXCEPTION 'M13 Preflight Failed: Expected 1 public.m13_set_updated_at() function, found %. Aborting.', v_func_count;
    END IF;

    SELECT p.pronargs, l.lanname, p.prorettype::regtype::text, p.prosecdef, p.prosrc
    INTO v_nargs, v_lang, v_rettype, v_secdef, v_src
    FROM pg_proc p
    JOIN pg_language l ON p.prolang = l.oid
    WHERE p.oid = v_func_oid;

    IF v_nargs <> 0 OR v_lang <> 'plpgsql' OR v_rettype <> 'trigger' OR v_secdef IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION 'M13 Preflight Failed: Function signature/mode mismatch (nargs=%, lang=%, ret=%, secdef=%). Aborting.',
            v_nargs, v_lang, v_rettype, v_secdef;
    END IF;

    IF v_src NOT LIKE '%NEW.updated_at = now()%' THEN
        RAISE EXCEPTION 'M13 Preflight Failed: Function body mismatch on public.m13_set_updated_at(). Aborting.';
    END IF;

    -- 0.3 Verify all 3 M13 triggers exist and reference public.m13_set_updated_at()
    SELECT count(*)
    INTO v_trg_count
    FROM pg_trigger t
    WHERE NOT t.tgisinternal
      AND t.tgfoid = v_func_oid
      AND (
          (t.tgrelid = 'public.personalization_templates'::regclass AND t.tgname = 'trg_personalization_templates_updated_at')
          OR (t.tgrelid = 'public.customization_sessions'::regclass AND t.tgname = 'trg_customization_sessions_updated_at')
          OR (t.tgrelid = 'public.order_customizations'::regclass AND t.tgname = 'trg_order_customizations_updated_at')
      );

    IF v_trg_count <> 3 THEN
        RAISE EXCEPTION 'M13 Preflight Failed: Expected 3 M13 triggers referencing public.m13_set_updated_at(), found %. Aborting.', v_trg_count;
    END IF;

    -- 0.4 Verify FK order_customizations_session_id_fkey -> customization_sessions(id) ON DELETE RESTRICT
    SELECT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_namespace n ON c.connamespace = n.oid
        WHERE n.nspname = 'public'
          AND c.conrelid = 'public.order_customizations'::regclass
          AND c.conname = 'order_customizations_session_id_fkey'
          AND c.contype = 'f'
          AND c.confrelid = 'public.customization_sessions'::regclass
          AND c.confdeltype = 'r'
          AND c.convalidated = TRUE
          AND (
              SELECT array_agg(a.attname::text ORDER BY k.ord)
              FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
          ) = ARRAY['session_id']
          AND (
              SELECT array_agg(a.attname::text ORDER BY k.ord)
              FROM unnest(c.confkey) WITH ORDINALITY AS k(attnum, ord)
              JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.attnum
          ) = ARRAY['id']
    ) INTO v_fk_exists;

    IF NOT v_fk_exists THEN
        RAISE EXCEPTION 'M13 Preflight Failed: Expected validated FK order_customizations_session_id_fkey on (session_id) -> customization_sessions(id) ON DELETE RESTRICT. Aborting.';
    END IF;

    -- 0.5 Verify index state on public.order_customizations(session_id)
    SELECT a.attnum
    INTO v_session_attnum
    FROM pg_attribute a
    WHERE a.attrelid = 'public.order_customizations'::regclass
      AND a.attname = 'session_id'
      AND NOT a.attisdropped;

    SELECT pg_get_indexdef(i.oid)
    INTO v_target_idx_def
    FROM pg_index ix
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_namespace n ON n.oid = i.relnamespace
    WHERE n.nspname = 'public'
      AND i.relname = 'idx_order_customizations_session_id';

    IF v_target_idx_def IS NOT NULL THEN
        IF v_target_idx_def NOT LIKE 'CREATE INDEX idx_order_customizations_session_id ON public.order_customizations USING btree (session_id)%' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Index idx_order_customizations_session_id exists with incompatible definition: %. Aborting.', v_target_idx_def;
        END IF;
    ELSE
        SELECT i.relname
        INTO v_existing_idx_name
        FROM pg_index ix
        JOIN pg_class i ON i.oid = ix.indexrelid
        WHERE ix.indrelid = 'public.order_customizations'::regclass
          AND ix.indisvalid = TRUE
          AND ix.indisready = TRUE
          AND ix.indpred IS NULL
          AND ix.indexprs IS NULL
          AND (ix.indkey::smallint[])[0] = v_session_attnum
        LIMIT 1;

        IF v_existing_idx_name IS NOT NULL THEN
            RAISE NOTICE 'Equivalent valid index % already covers order_customizations(session_id).', v_existing_idx_name;
        END IF;
    END IF;

    -- 0.6 Verify provenance table integrity if it already exists
    IF to_regclass('m13_internal.migration_index_provenance') IS NOT NULL THEN
        SELECT count(*)
        INTO v_col_count
        FROM information_schema.columns
        WHERE table_schema = 'm13_internal'
          AND table_name = 'migration_index_provenance'
          AND column_name IN (
              'migration_id', 'owning_migration', 'schema_name', 'table_name',
              'table_oid', 'index_name', 'index_oid', 'index_def',
              'created_by_migration', 'created_at'
          );

        IF v_col_count <> 10 THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Provenance table m13_internal.migration_index_provenance schema structure mismatch (expected 10 columns, found %). Aborting.', v_col_count;
        END IF;

        SELECT count(*)
        INTO v_conflict_count
        FROM m13_internal.migration_index_provenance p
        WHERE p.migration_id <> '20261113_2345_m13_hardening_and_provenance'
          AND (
              (p.schema_name = 'public' AND p.table_name = 'order_customizations' AND p.index_name = 'idx_order_customizations_session_id')
              OR p.owning_migration = '20261113_2345_m13_hardening_and_provenance'
          );

        IF v_conflict_count > 0 THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Conflicting provenance ownership record detected for idx_order_customizations_session_id. Aborting.';
        END IF;

        SELECT *
        INTO v_prov
        FROM m13_internal.migration_index_provenance p
        WHERE p.migration_id = '20261113_2345_m13_hardening_and_provenance';

        IF FOUND THEN
            SELECT c.oid, pg_get_indexdef(c.oid)
            INTO v_live_oid, v_live_def
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relname = 'idx_order_customizations_session_id'
              AND c.relkind = 'i';

            IF v_prov.created_by_migration IS DISTINCT FROM TRUE
               OR v_live_oid IS NULL
               OR v_live_oid <> v_prov.index_oid
               OR v_prov.table_oid <> 'public.order_customizations'::regclass
               OR v_live_def IS DISTINCT FROM v_prov.index_def THEN
                RAISE EXCEPTION 'M13 Preflight Failed: Existing provenance record does not match live index state. Aborting.';
            END IF;
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 1. Fix Function search_path
-- ==============================================================================
ALTER FUNCTION public.m13_set_updated_at() SET search_path = pg_catalog;

-- ==============================================================================
-- 2. Revoke Unnecessary Direct EXECUTE Privileges
-- ==============================================================================
REVOKE ALL ON FUNCTION public.m13_set_updated_at() FROM PUBLIC, anon, authenticated, service_role;

-- ==============================================================================
-- 3. Conditional Index Creation + Atomic Provenance Recording
-- ==============================================================================
DO $$
DECLARE
    v_session_attnum SMALLINT;
    v_has_covering_idx BOOLEAN;
    v_table_oid OID;
    v_index_oid OID;
    v_index_def TEXT;
BEGIN
    SELECT a.attnum
    INTO v_session_attnum
    FROM pg_attribute a
    WHERE a.attrelid = 'public.order_customizations'::regclass
      AND a.attname = 'session_id'
      AND NOT a.attisdropped;

    SELECT EXISTS (
        SELECT 1
        FROM pg_index ix
        WHERE ix.indrelid = 'public.order_customizations'::regclass
          AND ix.indisvalid = TRUE
          AND ix.indisready = TRUE
          AND ix.indpred IS NULL
          AND ix.indexprs IS NULL
          AND (ix.indkey::smallint[])[0] = v_session_attnum
    ) INTO v_has_covering_idx;

    IF NOT v_has_covering_idx THEN
        CREATE INDEX idx_order_customizations_session_id
            ON public.order_customizations (session_id);

        v_table_oid := 'public.order_customizations'::regclass;
        SELECT c.oid, pg_get_indexdef(c.oid)
        INTO v_index_oid, v_index_def
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = 'idx_order_customizations_session_id'
          AND c.relkind = 'i';

        IF v_index_oid IS NULL OR v_index_def IS NULL THEN
            RAISE EXCEPTION 'M13 Migration Failed: Created index OID lookup failed.';
        END IF;

        CREATE SCHEMA IF NOT EXISTS m13_internal;
        REVOKE ALL ON SCHEMA m13_internal FROM PUBLIC, anon, authenticated, service_role;

        CREATE TABLE IF NOT EXISTS m13_internal.migration_index_provenance (
            migration_id TEXT PRIMARY KEY,
            owning_migration TEXT NOT NULL,
            schema_name TEXT NOT NULL,
            table_name TEXT NOT NULL,
            table_oid OID NOT NULL,
            index_name TEXT NOT NULL,
            index_oid OID NOT NULL,
            index_def TEXT NOT NULL,
            created_by_migration BOOLEAN NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        ALTER TABLE m13_internal.migration_index_provenance ENABLE ROW LEVEL SECURITY;
        REVOKE ALL ON TABLE m13_internal.migration_index_provenance FROM PUBLIC, anon, authenticated, service_role;

        INSERT INTO m13_internal.migration_index_provenance (
            migration_id,
            owning_migration,
            schema_name,
            table_name,
            table_oid,
            index_name,
            index_oid,
            index_def,
            created_by_migration
        ) VALUES (
            '20261113_2345_m13_hardening_and_provenance',
            '20261113_2345_m13_hardening_and_provenance',
            'public',
            'order_customizations',
            v_table_oid,
            'idx_order_customizations_session_id',
            v_index_oid,
            v_index_def,
            TRUE
        );

        RAISE NOTICE 'Created idx_order_customizations_session_id (OID %) and recorded atomic provenance.', v_index_oid;
    ELSE
        RAISE NOTICE 'Covering index on public.order_customizations(session_id) already exists; skipping creation and claiming no ownership.';
    END IF;
END $$;

COMMIT;
