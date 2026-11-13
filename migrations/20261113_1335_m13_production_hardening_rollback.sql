-- ==============================================================================
-- Rollback: 20261113_1335_m13_production_hardening_rollback.sql
-- Subsystem: M13 Interactive Personalization Engine (Corrective Hardening Rollback)
-- Target DB: PostgreSQL 17.11 / Supabase Production (ammsjbcpbspisbyynaga)
-- Scope:
--   Reverses ONLY changes introduced by 20261113_1335_m13_production_hardening.sql:
--   1. Resets search_path on public.m13_set_updated_at() if set to pg_catalog
--   2. Restores exact pre-hardening Phase A EXECUTE ACL on public.m13_set_updated_at()
--      ({=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres})
--   3. Drops idx_order_customizations_session_id if present
-- Preserves all M13 tables, triggers, policies, constraints, and rls_auto_enable().
-- Status: NOT AUTHORIZED FOR EXECUTION WITHOUT SEPARATE OWNER RELEASE
-- ==============================================================================

BEGIN;

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

-- Restore exact Phase A baseline EXECUTE ACL
GRANT EXECUTE ON FUNCTION public.m13_set_updated_at() TO PUBLIC, anon, authenticated, service_role;

-- Drop only the index created by the corrective migration
DROP INDEX IF EXISTS public.idx_order_customizations_session_id;

COMMIT;

