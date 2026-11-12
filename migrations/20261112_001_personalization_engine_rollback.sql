-- ==============================================================================
-- Migration Rollback: 20261112_001_personalization_engine_rollback.sql
-- Target Subsystem: Module M13 (Interactive Personalization Engine)
-- Execution Mode: Manual Staging Rollback Plan (NOT RUN - PHASE 1 BLOCKED)
-- Safety Contract: Dependency-Safe Restrictive Rollback.
--                  1. Drops M13 RLS policies explicitly.
--                  2. Drops M13 automated updated_at triggers explicitly.
--                  3. Explicitly drops foreign key constraints from M13 tables.
--                  4. Drops M13 tables using RESTRICT (RESTRICTIVE DROP).
--                     Zero CASCADE statements used on tables. Any unexpected external
--                     database dependency or foreign key will cause PostgreSQL to abort
--                     the transaction cleanly, preventing unintended side-effects.
--                  5. Inspects pg_catalog (pg_proc, pg_trigger) to preserve
--                     public.set_current_timestamp_updated_at() if any non-internal
--                     trigger references its procedure OID.
-- ==============================================================================

BEGIN;

-- 1. Drop Row Level Security Policies Explicitly
DROP POLICY IF EXISTS "Public read active templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on personalization_templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on customization_sessions" ON public.customization_sessions;
DROP POLICY IF EXISTS "Service role full access on order_customizations" ON public.order_customizations;

-- 2. Drop M13 Automated Timestamp Triggers Explicitly
DROP TRIGGER IF EXISTS trg_personalization_templates_updated_at ON public.personalization_templates;
DROP TRIGGER IF EXISTS trg_customization_sessions_updated_at ON public.customization_sessions;
DROP TRIGGER IF EXISTS trg_order_customizations_updated_at ON public.order_customizations;

-- 3. Explicitly Drop Known Inter-Table & Outbound Foreign Key Constraints
ALTER TABLE IF EXISTS public.order_customizations 
    DROP CONSTRAINT IF EXISTS fk_order_customizations_order;

ALTER TABLE IF EXISTS public.order_customizations 
    DROP CONSTRAINT IF EXISTS order_customizations_session_id_fkey;

ALTER TABLE IF EXISTS public.customization_sessions 
    DROP CONSTRAINT IF EXISTS customization_sessions_template_id_fkey;

ALTER TABLE IF EXISTS public.personalization_templates 
    DROP CONSTRAINT IF EXISTS fk_personalization_templates_product;

-- 4. Drop M13 Tables in Strict Reverse Dependency Order (RESTRICTIVE DROPS ONLY)
-- Replaced all DROP TABLE ... CASCADE with RESTRICT.
-- If any unexpected external view, table, or constraint depends on these tables,
-- PostgreSQL will halt and roll back the transaction immediately without data loss.
DROP TABLE IF EXISTS public.order_customizations RESTRICT;
DROP TABLE IF EXISTS public.customization_sessions RESTRICT;
DROP TABLE IF EXISTS public.personalization_templates RESTRICT;

-- 5. Robust Dependency-Safe Function Cleanup via pg_catalog
-- Inspect pg_proc and pg_trigger to guarantee the shared function is NEVER dropped
-- if any active trigger across the database references its procedure OID.
DO $$
DECLARE
    v_proc_oid OID;
    v_active_dep_count INT;
BEGIN
    -- Locate OID of set_current_timestamp_updated_at() in public schema
    SELECT p.oid INTO v_proc_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
      AND p.proname = 'set_current_timestamp_updated_at';

    IF v_proc_oid IS NOT NULL THEN
        -- Count all non-internal triggers in pg_catalog referencing this procedure OID
        SELECT COUNT(*) INTO v_active_dep_count
        FROM pg_trigger t
        WHERE t.tgfoid = v_proc_oid
          AND NOT t.tgisinternal;

        IF v_active_dep_count = 0 THEN
            EXECUTE 'DROP FUNCTION public.set_current_timestamp_updated_at() RESTRICT';
            RAISE NOTICE 'Function public.set_current_timestamp_updated_at() had 0 active trigger dependencies in pg_catalog and was safely dropped.';
        ELSE
            RAISE NOTICE 'Function public.set_current_timestamp_updated_at() is referenced by % active trigger(s) in pg_catalog; preserving function.', v_active_dep_count;
        END IF;
    ELSE
        RAISE NOTICE 'Function public.set_current_timestamp_updated_at() does not exist; no cleanup needed.';
    END IF;
END $$;

COMMIT;
