-- ==============================================================================
-- Migration Rollback: 20261112_001_personalization_engine_rollback.sql
-- Target Subsystem: Module M13 (Interactive Personalization Engine)
-- Execution Mode: Manual Staging Rollback Plan (NOT RUN - PHASE 1 BLOCKED)
-- Safety Contract: Dependency-Safe. Drops M13 tables, policies, and triggers.
--                  Preserves set_current_timestamp_updated_at() if other tables depend on it.
-- ==============================================================================

BEGIN;

-- 1. Drop Row Level Security Policies
DROP POLICY IF EXISTS "Public read active templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on personalization_templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on customization_sessions" ON public.customization_sessions;
DROP POLICY IF EXISTS "Service role full access on order_customizations" ON public.order_customizations;

-- 2. Drop M13 Automated Timestamp Triggers
DROP TRIGGER IF EXISTS trg_personalization_templates_updated_at ON public.personalization_templates;
DROP TRIGGER IF EXISTS trg_customization_sessions_updated_at ON public.customization_sessions;
DROP TRIGGER IF EXISTS trg_order_customizations_updated_at ON public.order_customizations;

-- 3. Drop M13 Tables in Reverse Dependency Order (with CASCADE for child constraints)
DROP TABLE IF EXISTS public.order_customizations CASCADE;
DROP TABLE IF EXISTS public.customization_sessions CASCADE;
DROP TABLE IF EXISTS public.personalization_templates CASCADE;

-- 4. Dependency-Safe Trigger Function Cleanup
-- Do NOT blindly DROP FUNCTION public.set_current_timestamp_updated_at()!
-- Other platform tables (e.g., products, orders, niches) may rely on this utility function.
-- Only drop if zero triggers across the entire database remain attached to it.
DO $$
DECLARE
    v_dependency_count INT;
BEGIN
    SELECT COUNT(*) INTO v_dependency_count
    FROM information_schema.triggers
    WHERE action_statement LIKE '%set_current_timestamp_updated_at%';

    IF v_dependency_count = 0 THEN
        DROP FUNCTION IF EXISTS public.set_current_timestamp_updated_at();
        RAISE NOTICE 'Function public.set_current_timestamp_updated_at() had 0 active dependencies and was dropped.';
    ELSE
        RAISE NOTICE 'Function public.set_current_timestamp_updated_at() is referenced by % other trigger(s); preserving function.', v_dependency_count;
    END IF;
END $$;

COMMIT;
