-- ==============================================================================
-- Rollback: 20261113_2345_m13_hardening_and_provenance_rollback.sql
-- Subsystem: M13 Interactive Personalization Engine (Hardening + Provenance Rollback)
-- Supersedes:
--   - 20261113_1335_m13_production_hardening_rollback.sql
--   - 20261113_2200_m13_rollback_provenance_fix_rollback.sql
-- Target DB: PostgreSQL 17.11 / Supabase
-- Scope:
--   1. Enforces transaction-local lock_timeout (5s) and statement_timeout (30s).
--   2. Reverses public.m13_set_updated_at() search_path and EXECUTE ACL hardening.
--   3. Inspects m13_internal.migration_index_provenance for ownership record
--      '20261113_2345_m13_hardening_and_provenance'.
--   4. If provenance is absent (pre-existing index, historical 1335 index, or
--      already rolled back), preserves ALL existing indexes and reports
--      any residual index for manual review.
--   5. If provenance exists, validates structure, conflicting ownership,
--      owning_migration, created_by_migration = TRUE, live table_oid,
--      live index_oid, schema/table/index names, and exact pg_get_indexdef().
--      Fails closed on any mismatch without dropping any index.
--   6. Drops public.idx_order_customizations_session_id (without CASCADE) ONLY
--      when all ownership checks pass, then deletes only this migration's
--      provenance row and drops empty metadata objects.
-- Status: NOT AUTHORIZED FOR EXECUTION WITHOUT SEPARATE OWNER RELEASE
-- ==============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ==============================================================================
-- 1. Reverse public.m13_set_updated_at() Hardening
-- ==============================================================================
DO $$
DECLARE
    v_func_count INT;
    v_func_oid OID;
    v_proconfig TEXT[];
BEGIN
    SELECT count(*), min(p.oid)
    INTO v_func_count, v_func_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';

    IF v_func_count <> 1 THEN
        RAISE EXCEPTION 'M13 Hardening Rollback Failed: Expected 1 public.m13_set_updated_at() function, found %. Aborting.', v_func_count;
    END IF;

    SELECT p.proconfig INTO v_proconfig
    FROM pg_proc p
    WHERE p.oid = v_func_oid;

    IF v_proconfig IS NOT NULL AND 'search_path=pg_catalog' = ANY(v_proconfig) THEN
        ALTER FUNCTION public.m13_set_updated_at() RESET search_path;
        RAISE NOTICE 'Reset search_path on public.m13_set_updated_at().';
    ELSE
        RAISE NOTICE 'search_path=pg_catalog not set on public.m13_set_updated_at(); skipping RESET.';
    END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.m13_set_updated_at() TO PUBLIC, anon, authenticated, service_role;

-- ==============================================================================
-- 2. Provenance-Verified Index Rollback (Fail-Closed)
-- ==============================================================================
DO $$
DECLARE
    v_col_count INT;
    v_conflict_count INT;
    v_prov RECORD;
    v_live_tbl_oid OID;
    v_live_idx_oid OID;
    v_live_idx_name TEXT;
    v_live_idx_schema TEXT;
    v_live_idx_tbl_oid OID;
    v_live_idx_def TEXT;
    v_remaining_rows INT;
BEGIN
    IF to_regclass('m13_internal.migration_index_provenance') IS NULL THEN
        RAISE NOTICE 'Provenance table m13_internal.migration_index_provenance does not exist; preserving all existing indexes (residual index, if any, retained for manual review).';
        RETURN;
    END IF;

    -- Validate provenance table schema structure before querying
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
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Provenance table structure unexpectedly modified (expected 10 columns, found %). Preserving all indexes.', v_col_count;
    END IF;

    -- Detect conflicting ownership records
    SELECT count(*)
    INTO v_conflict_count
    FROM m13_internal.migration_index_provenance p
    WHERE p.migration_id <> '20261113_2345_m13_hardening_and_provenance'
      AND (
          (p.schema_name = 'public' AND p.table_name = 'order_customizations' AND p.index_name = 'idx_order_customizations_session_id')
          OR p.owning_migration = '20261113_2345_m13_hardening_and_provenance'
      );

    IF v_conflict_count > 0 THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Conflicting ownership records detected (% rows). Preserving all indexes.', v_conflict_count;
    END IF;

    SELECT *
    INTO v_prov
    FROM m13_internal.migration_index_provenance p
    WHERE p.migration_id = '20261113_2345_m13_hardening_and_provenance';

    IF NOT FOUND THEN
        RAISE NOTICE 'No provenance ownership record for 20261113_2345_m13_hardening_and_provenance; preserving all existing indexes.';
        RETURN;
    END IF;

    -- Fail closed if provenance record fails integrity validation
    IF v_prov.owning_migration IS DISTINCT FROM '20261113_2345_m13_hardening_and_provenance'
       OR v_prov.created_by_migration IS DISTINCT FROM TRUE
       OR v_prov.schema_name IS DISTINCT FROM 'public'
       OR v_prov.table_name IS DISTINCT FROM 'order_customizations'
       OR v_prov.index_name IS DISTINCT FROM 'idx_order_customizations_session_id' THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Provenance record failed integrity validation (owning_migration=%, created_by_migration=%, schema=%, table=%, index=%). Preserving all indexes.',
            v_prov.owning_migration, v_prov.created_by_migration, v_prov.schema_name, v_prov.table_name, v_prov.index_name;
    END IF;

    -- Verify live table OID
    v_live_tbl_oid := to_regclass('public.order_customizations');
    IF v_live_tbl_oid IS NULL OR v_live_tbl_oid <> v_prov.table_oid THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Table OID mismatch (recorded=%, live=%). Preserving all indexes.',
            v_prov.table_oid, v_live_tbl_oid;
    END IF;

    -- Verify live index OID, relation attachment, identity, and exact definition
    SELECT c.oid, c.relname, n.nspname, ix.indrelid, pg_get_indexdef(c.oid)
    INTO v_live_idx_oid, v_live_idx_name, v_live_idx_schema, v_live_idx_tbl_oid, v_live_idx_def
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_index ix ON ix.indexrelid = c.oid
    WHERE c.oid = v_prov.index_oid
      AND c.relkind = 'i';

    IF v_live_idx_oid IS NULL THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Recorded index OID % no longer exists (may have been dropped/replaced). Preserving any same-named index.',
            v_prov.index_oid;
    END IF;

    IF v_live_idx_schema <> v_prov.schema_name
       OR v_live_idx_name <> v_prov.index_name
       OR v_live_idx_tbl_oid <> v_prov.table_oid
       OR v_live_idx_def <> v_prov.index_def THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Index identity/definition mismatch (live %.% on table OID %, def="%"; expected %.% on table OID %, def="%"). Preserving index.',
            v_live_idx_schema, v_live_idx_name, v_live_idx_tbl_oid, v_live_idx_def,
            v_prov.schema_name, v_prov.index_name, v_prov.table_oid, v_prov.index_def;
    END IF;

    -- All ownership checks passed: drop only the verified owned index (never CASCADE)
    DROP INDEX public.idx_order_customizations_session_id;

    DELETE FROM m13_internal.migration_index_provenance
    WHERE migration_id = '20261113_2345_m13_hardening_and_provenance';

    SELECT count(*) INTO v_remaining_rows FROM m13_internal.migration_index_provenance;
    IF v_remaining_rows = 0 THEN
        DROP TABLE m13_internal.migration_index_provenance;
        DROP SCHEMA IF EXISTS m13_internal;
    END IF;

    RAISE NOTICE 'Dropped migration-owned index public.idx_order_customizations_session_id (OID %) and cleaned up provenance.', v_live_idx_oid;
END $$;

COMMIT;
