-- ==============================================================================
-- Rollback Migration: 20261112_001_personalization_engine_rollback.sql
-- Subsystem: M13 Interactive Personalization Engine (Hardened & Reconciled)
-- Target DB: PostgreSQL 15+ / Supabase PostgreSQL
-- Status: PRE-IMPLEMENTATION SPECIFICATION ONLY (DO NOT APPLY AUTOMATICALLY)
-- Safety Hardening & Defect Closures:
--   1. Restrictive dependency handling: All tables dropped with DROP TABLE ... RESTRICT.
--      Zero CASCADE statements. If any unexpected external object or foreign key depends
--      on M13 tables, PostgreSQL immediately aborts the transaction.
--   2. Explicit constraint and trigger cleanup: Known M13 foreign keys, triggers, and
--      policies are removed cleanly before table deletion.
--   3. M13-owned function cleanup: Drops exclusively 0-argument public.m13_set_updated_at()
--      using RESTRICT mode after confirming zero external triggers depend on its procedure OID.
--      Leaves all shared platform functions completely untouched.
--   4. Scope of reversibility limitation: Rollback removes M13-owned schema objects and
--      associated table data. It cannot restore pre-existing data or external objects.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 1. Explicit Outbound Foreign Key Severing (M13 Tables Only)
-- ==============================================================================
ALTER TABLE IF EXISTS public.order_customizations 
    DROP CONSTRAINT IF EXISTS fk_order_customizations_order;

ALTER TABLE IF EXISTS public.order_customizations 
    DROP CONSTRAINT IF EXISTS order_customizations_session_id_fkey;

ALTER TABLE IF EXISTS public.customization_sessions 
    DROP CONSTRAINT IF EXISTS customization_sessions_template_id_fkey;

ALTER TABLE IF EXISTS public.personalization_templates 
    DROP CONSTRAINT IF EXISTS fk_personalization_templates_product;

-- ==============================================================================
-- 2. Drop M13-Specific Triggers
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_order_customizations_updated_at ON public.order_customizations;
DROP TRIGGER IF EXISTS trg_customization_sessions_updated_at ON public.customization_sessions;
DROP TRIGGER IF EXISTS trg_personalization_templates_updated_at ON public.personalization_templates;

-- ==============================================================================
-- 3. Drop M13-Specific Row Level Security Policies
-- ==============================================================================
DROP POLICY IF EXISTS "Public read active templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on personalization_templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on customization_sessions" ON public.customization_sessions;
DROP POLICY IF EXISTS "Service role full access on order_customizations" ON public.order_customizations;

-- ==============================================================================
-- 4. Restrictive Table Drops (Zero CASCADE)
-- ==============================================================================
DROP TABLE IF EXISTS public.order_customizations RESTRICT;
DROP TABLE IF EXISTS public.customization_sessions RESTRICT;
DROP TABLE IF EXISTS public.personalization_templates RESTRICT;

-- ==============================================================================
-- 5. Safe M13-Owned Trigger Function Cleanup (Catalog Verification)
-- ==============================================================================
DO $$
DECLARE
    v_proc_oid OID;
    v_active_dep_count INT;
BEGIN
    SELECT p.oid INTO v_proc_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' 
      AND p.proname = 'm13_set_updated_at'
      AND p.pronargs = 0;

    IF v_proc_oid IS NOT NULL THEN
        -- Check if any remaining non-internal triggers reference this procedure OID
        SELECT COUNT(*) INTO v_active_dep_count
        FROM pg_trigger t
        WHERE t.tgfoid = v_proc_oid
          AND NOT t.tgisinternal;

        IF v_active_dep_count = 0 THEN
            EXECUTE 'DROP FUNCTION public.m13_set_updated_at() RESTRICT';
            RAISE NOTICE 'Function public.m13_set_updated_at() had 0 active trigger dependencies and was safely dropped.';
        ELSE
            RAISE NOTICE 'Function public.m13_set_updated_at() is referenced by % active trigger(s) outside M13; preserving function.', v_active_dep_count;
        END IF;
    ELSE
        RAISE NOTICE 'Function public.m13_set_updated_at() does not exist; no cleanup needed.';
    END IF;
END $$;

COMMIT;
