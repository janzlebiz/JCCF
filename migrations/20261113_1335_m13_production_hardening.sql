-- ==============================================================================
-- Migration: 20261113_1335_m13_production_hardening.sql
-- Subsystem: M13 Interactive Personalization Engine (Corrective Hardening)
-- Target DB: PostgreSQL 17.11 / Supabase Production (ammsjbcpbspisbyynaga)
-- Scope:
--   1. Fix search_path on public.m13_set_updated_at() -> pg_catalog
--   2. Revoke direct EXECUTE on public.m13_set_updated_at() from PUBLIC, anon,
--      authenticated, and service_role (retaining owner postgres only)
--   3. Create B-tree index idx_order_customizations_session_id on
--      public.order_customizations(session_id) if no equivalent valid index exists
-- Status: PRE-AUTHORIZATION SPECIFICATION (DO NOT APPLY WITHOUT OWNER RELEASE)
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 0. Fail-Closed Precondition & Drift Verification
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
    v_existing_idx_name TEXT;
    v_target_idx_def TEXT;
    v_session_attnum SMALLINT;
BEGIN
    -- 0.1 Verify all 3 M13 tables exist
    IF to_regclass('public.personalization_templates') IS NULL
       OR to_regclass('public.customization_sessions') IS NULL
       OR to_regclass('public.order_customizations') IS NULL THEN
        RAISE EXCEPTION 'M13 Hardening Preflight Failed: One or more M13 tables are missing. Aborting.';
    END IF;

    -- 0.2 Verify public.m13_set_updated_at() exists with exact signature & SECURITY INVOKER
    SELECT count(*), min(p.oid)
    INTO v_func_count, v_func_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';

    IF v_func_count <> 1 THEN
        RAISE EXCEPTION 'M13 Hardening Preflight Failed: Expected 1 public.m13_set_updated_at() function, found %. Aborting.', v_func_count;
    END IF;

    SELECT p.pronargs, l.lanname, p.prorettype::regtype::text, p.prosecdef, p.prosrc
    INTO v_nargs, v_lang, v_rettype, v_secdef, v_src
    FROM pg_proc p
    JOIN pg_language l ON p.prolang = l.oid
    WHERE p.oid = v_func_oid;

    IF v_nargs <> 0 OR v_lang <> 'plpgsql' OR v_rettype <> 'trigger' OR v_secdef IS DISTINCT FROM FALSE THEN
        RAISE EXCEPTION 'M13 Hardening Preflight Failed: Function signature/mode mismatch (nargs=%, lang=%, ret=%, secdef=%). Aborting.',
            v_nargs, v_lang, v_rettype, v_secdef;
    END IF;

    IF v_src NOT LIKE '%NEW.updated_at = now()%' THEN
        RAISE EXCEPTION 'M13 Hardening Preflight Failed: Function body mismatch on public.m13_set_updated_at(). Aborting.';
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
        RAISE EXCEPTION 'M13 Hardening Preflight Failed: Expected 3 M13 triggers referencing public.m13_set_updated_at(), found %. Aborting.', v_trg_count;
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
        RAISE EXCEPTION 'M13 Hardening Preflight Failed: Expected validated FK order_customizations_session_id_fkey on (session_id) -> customization_sessions(id) ON DELETE RESTRICT. Aborting.';
    END IF;

    -- 0.5 Verify index state on public.order_customizations(session_id)
    SELECT a.attnum
    INTO v_session_attnum
    FROM pg_attribute a
    WHERE a.attrelid = 'public.order_customizations'::regclass
      AND a.attname = 'session_id'
      AND NOT a.attisdropped;

    -- Check if target index name already exists; if so, verify exact definition
    SELECT pg_get_indexdef(i.oid)
    INTO v_target_idx_def
    FROM pg_index ix
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_namespace n ON n.oid = i.relnamespace
    WHERE n.nspname = 'public'
      AND i.relname = 'idx_order_customizations_session_id';

    IF v_target_idx_def IS NOT NULL THEN
        IF v_target_idx_def NOT LIKE 'CREATE INDEX idx_order_customizations_session_id ON public.order_customizations USING btree (session_id)%' THEN
            RAISE EXCEPTION 'M13 Hardening Preflight Failed: Index idx_order_customizations_session_id exists with incompatible definition: %. Aborting.', v_target_idx_def;
        END IF;
        RAISE NOTICE 'Index idx_order_customizations_session_id already exists with expected definition.';
    ELSE
        -- Check for any other valid non-partial, non-expression index with session_id as leading column
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

    RAISE NOTICE 'M13 Hardening Preflight verified: all preconditions passed.';
END $$;

-- ==============================================================================
-- 1. Fix Function search_path (B1)
-- ==============================================================================
ALTER FUNCTION public.m13_set_updated_at() SET search_path = pg_catalog;

-- ==============================================================================
-- 2. Revoke Unnecessary Direct EXECUTE Privileges (B2)
-- ==============================================================================
-- Trigger functions are invoked internally by PostgreSQL without requiring the
-- DML-executing role to hold direct EXECUTE privilege. Only owner (postgres)
-- retains EXECUTE.
REVOKE ALL ON FUNCTION public.m13_set_updated_at() FROM PUBLIC, anon, authenticated, service_role;

-- ==============================================================================
-- 3. Add Missing FK Index on order_customizations(session_id) if Absent (B3)
-- ==============================================================================
DO $$
DECLARE
    v_session_attnum SMALLINT;
    v_has_covering_idx BOOLEAN;
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
        RAISE NOTICE 'Created index idx_order_customizations_session_id on public.order_customizations(session_id).';
    ELSE
        RAISE NOTICE 'Covering index on public.order_customizations(session_id) already present; skipping creation.';
    END IF;
END $$;

COMMIT;

