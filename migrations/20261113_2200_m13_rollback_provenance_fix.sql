-- ==============================================================================
-- Migration: 20261113_2200_m13_rollback_provenance_fix.sql
-- Subsystem: M13 Interactive Personalization Engine (Rollback Provenance Fix)
-- Target DB: PostgreSQL 17.11 / Supabase
-- Scope:
--   1. Verifies M13 tables, function, triggers, and FK preconditions.
--   2. Inspects public.order_customizations(session_id) indexes.
--   3. If a valid covering index already exists (exact name or another name),
--      skips index creation and records NO ownership provenance.
--   4. If no covering index exists, creates idx_order_customizations_session_id
--      and atomically records durable OID + definition provenance in
--      m13_internal.migration_index_provenance.
--   5. Does NOT alter function ACLs, search_path, tables, policies, triggers,
--      or public.rls_auto_enable().
-- Status: PRE-AUTHORIZATION SPECIFICATION (DO NOT APPLY WITHOUT OWNER RELEASE)
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 1. Fail-Closed M13 State & Index Precondition Verification
-- ==============================================================================
DO $$
DECLARE
    v_func_count INT;
    v_func_oid OID;
    v_trg_count INT;
    v_fk_exists BOOLEAN;
    v_session_attnum SMALLINT;
    v_target_idx_def TEXT;
    v_existing_idx_name TEXT;
    v_prov_exists BOOLEAN := FALSE;
    v_prov_oid OID;
    v_prov_def TEXT;
    v_live_oid OID;
    v_live_def TEXT;
BEGIN
    -- Verify 3 M13 tables exist
    IF to_regclass('public.personalization_templates') IS NULL
       OR to_regclass('public.customization_sessions') IS NULL
       OR to_regclass('public.order_customizations') IS NULL THEN
        RAISE EXCEPTION 'M13 Provenance Preflight Failed: One or more M13 tables are missing. Aborting.';
    END IF;

    -- Verify public.m13_set_updated_at() exists with expected 0-arg trigger signature
    SELECT count(*), min(p.oid)
    INTO v_func_count, v_func_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'm13_set_updated_at'
      AND p.pronargs = 0
      AND p.prorettype = 'trigger'::regtype;

    IF v_func_count <> 1 THEN
        RAISE EXCEPTION 'M13 Provenance Preflight Failed: Expected 1 public.m13_set_updated_at() trigger function, found %. Aborting.', v_func_count;
    END IF;

    -- Verify all 3 M13 triggers reference public.m13_set_updated_at()
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
        RAISE EXCEPTION 'M13 Provenance Preflight Failed: Expected 3 M13 triggers referencing public.m13_set_updated_at(), found %. Aborting.', v_trg_count;
    END IF;

    -- Verify FK order_customizations_session_id_fkey
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
    ) INTO v_fk_exists;

    IF NOT v_fk_exists THEN
        RAISE EXCEPTION 'M13 Provenance Preflight Failed: Expected validated FK order_customizations_session_id_fkey. Aborting.';
    END IF;

    -- Verify existing provenance consistency if provenance table already exists
    IF to_regclass('m13_internal.migration_index_provenance') IS NOT NULL THEN
        SELECT TRUE, p.index_oid, p.index_def
        INTO v_prov_exists, v_prov_oid, v_prov_def
        FROM m13_internal.migration_index_provenance p
        WHERE p.migration_id = '20261113_2200_m13_rollback_provenance_fix';

        IF FOUND THEN
            SELECT c.oid, pg_get_indexdef(c.oid)
            INTO v_live_oid, v_live_def
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relname = 'idx_order_customizations_session_id'
              AND c.relkind = 'i';

            IF v_live_oid IS NULL OR v_live_oid <> v_prov_oid OR v_live_def <> v_prov_def THEN
                RAISE EXCEPTION 'M13 Provenance Preflight Failed: Existing provenance record does not match live index state (prov_oid=%, live_oid=%). Aborting.',
                    v_prov_oid, v_live_oid;
            END IF;
        END IF;
    END IF;

    -- Verify candidate index state on public.order_customizations(session_id)
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
            RAISE EXCEPTION 'M13 Provenance Preflight Failed: Index idx_order_customizations_session_id exists with incompatible definition: %. Aborting.', v_target_idx_def;
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 2. Conditional Index Creation + Atomic Provenance Recording
-- ==============================================================================
DO $$
DECLARE
    v_table_oid OID := 'public.order_customizations'::regclass;
    v_session_attnum SMALLINT;
    v_existing_idx_name TEXT;
    v_new_idx_oid OID;
    v_new_idx_def TEXT;
BEGIN
    SELECT a.attnum
    INTO v_session_attnum
    FROM pg_attribute a
    WHERE a.attrelid = v_table_oid
      AND a.attname = 'session_id'
      AND NOT a.attisdropped;

    -- Check for ANY valid non-partial, non-expression index with session_id as leading column
    SELECT i.relname
    INTO v_existing_idx_name
    FROM pg_index ix
    JOIN pg_class i ON i.oid = ix.indexrelid
    WHERE ix.indrelid = v_table_oid
      AND ix.indisvalid = TRUE
      AND ix.indisready = TRUE
      AND ix.indpred IS NULL
      AND ix.indexprs IS NULL
      AND (ix.indkey::smallint[])[0] = v_session_attnum
    LIMIT 1;

    IF v_existing_idx_name IS NOT NULL THEN
        -- Pre-existing index (either exact-name or equivalent under another name):
        -- Skip creation and DO NOT record ownership provenance.
        RAISE NOTICE 'Covering index % already exists on public.order_customizations(session_id); skipping creation and recording no ownership.', v_existing_idx_name;
    ELSE
        -- Create private provenance schema/table locked down from application roles
        CREATE SCHEMA IF NOT EXISTS m13_internal;
        REVOKE ALL ON SCHEMA m13_internal FROM PUBLIC, anon, authenticated, service_role;

        CREATE TABLE IF NOT EXISTS m13_internal.migration_index_provenance (
            migration_id TEXT PRIMARY KEY,
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
        REVOKE ALL ON m13_internal.migration_index_provenance FROM PUBLIC, anon, authenticated, service_role;

        -- Create the index
        CREATE INDEX idx_order_customizations_session_id
            ON public.order_customizations (session_id);

        -- Capture exact live OID and definition in the same transaction
        SELECT c.oid, pg_get_indexdef(c.oid)
        INTO v_new_idx_oid, v_new_idx_def
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = 'idx_order_customizations_session_id'
          AND c.relkind = 'i';

        INSERT INTO m13_internal.migration_index_provenance (
            migration_id, schema_name, table_name, table_oid,
            index_name, index_oid, index_def, created_by_migration
        ) VALUES (
            '20261113_2200_m13_rollback_provenance_fix',
            'public',
            'order_customizations',
            v_table_oid,
            'idx_order_customizations_session_id',
            v_new_idx_oid,
            v_new_idx_def,
            TRUE
        );

        RAISE NOTICE 'Created index idx_order_customizations_session_id (OID %) and recorded provenance.', v_new_idx_oid;
    END IF;
END $$;

COMMIT;
