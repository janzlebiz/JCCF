-- ==============================================================================
-- Rollback: 20261113_2200_m13_rollback_provenance_fix_rollback.sql
-- Subsystem: M13 Interactive Personalization Engine (Provenance-Verified Rollback)
-- Target DB: PostgreSQL 17.11 / Supabase
-- Scope:
--   1. Inspects m13_internal.migration_index_provenance for ownership record
--      '20261113_2200_m13_rollback_provenance_fix'.
--   2. If no provenance record exists (migration skipped creation or already
--      rolled back), preserves ALL existing indexes and exits cleanly.
--   3. If a provenance record exists, verifies table OID, index OID, index name,
--      schema, created_by_migration = TRUE, and exact pg_get_indexdef() match.
--      Fails closed on any mismatch (renamed, replaced, altered, or tampered).
--   4. Drops public.idx_order_customizations_session_id ONLY when all ownership
--      checks pass, then removes the provenance record and empty m13_internal
--      metadata objects.
-- Status: NOT AUTHORIZED FOR EXECUTION WITHOUT SEPARATE OWNER RELEASE
-- ==============================================================================

BEGIN;

DO $$
DECLARE
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
        RAISE NOTICE 'Provenance table m13_internal.migration_index_provenance does not exist; preserving all existing indexes.';
        RETURN;
    END IF;

    SELECT *
    INTO v_prov
    FROM m13_internal.migration_index_provenance p
    WHERE p.migration_id = '20261113_2200_m13_rollback_provenance_fix';

    IF NOT FOUND THEN
        RAISE NOTICE 'No provenance ownership record for 20261113_2200_m13_rollback_provenance_fix; preserving all existing indexes.';
        RETURN;
    END IF;

    -- Fail closed if provenance record itself fails structural sanity checks
    IF v_prov.created_by_migration IS DISTINCT FROM TRUE
       OR v_prov.schema_name IS DISTINCT FROM 'public'
       OR v_prov.table_name IS DISTINCT FROM 'order_customizations'
       OR v_prov.index_name IS DISTINCT FROM 'idx_order_customizations_session_id' THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Provenance record failed integrity validation (created_by_migration=%, schema=%, table=%, index=%). Preserving all indexes.',
            v_prov.created_by_migration, v_prov.schema_name, v_prov.table_name, v_prov.index_name;
    END IF;

    v_live_tbl_oid := to_regclass('public.order_customizations');
    IF v_live_tbl_oid IS NULL OR v_live_tbl_oid <> v_prov.table_oid THEN
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Table OID mismatch (recorded=%, live=%). Preserving all indexes.',
            v_prov.table_oid, v_live_tbl_oid;
    END IF;

    -- Look up the exact recorded index OID in pg_class / pg_index
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
        RAISE EXCEPTION 'M13 Provenance Rollback Aborted: Index identity/definition mismatch (live %.% on OID %, def="%"; expected %.% on OID %, def="%"). Preserving index.',
            v_live_idx_schema, v_live_idx_name, v_live_idx_tbl_oid, v_live_idx_def,
            v_prov.schema_name, v_prov.index_name, v_prov.table_oid, v_prov.index_def;
    END IF;

    -- All ownership checks passed: drop the exact verified index
    DROP INDEX public.idx_order_customizations_session_id;

    DELETE FROM m13_internal.migration_index_provenance
    WHERE migration_id = '20261113_2200_m13_rollback_provenance_fix';

    SELECT count(*) INTO v_remaining_rows FROM m13_internal.migration_index_provenance;
    IF v_remaining_rows = 0 THEN
        DROP TABLE m13_internal.migration_index_provenance;
        DROP SCHEMA IF EXISTS m13_internal;
    END IF;

    RAISE NOTICE 'Dropped migration-owned index public.idx_order_customizations_session_id (OID %) and cleaned up provenance.', v_live_idx_oid;
END $$;

COMMIT;
