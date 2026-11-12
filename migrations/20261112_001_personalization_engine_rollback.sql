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
-- 2. Drop M13-Specific Triggers (Verified Procedure OID & Table Scope)
-- ==============================================================================
-- Before dropping any M13 trigger, verify that it references public.m13_set_updated_at().
-- Fail-closed requirement: If trigger exists but function is missing, or OID differs, abort safely.
DO $$
DECLARE
    v_proc_oid OID;
    v_tgfoid OID;
BEGIN
    SELECT p.oid INTO v_proc_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at' AND p.pronargs = 0;

    -- Trigger: trg_order_customizations_updated_at
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = 'public.order_customizations'::regclass
          AND t.tgname = 'trg_order_customizations_updated_at'
          AND NOT t.tgisinternal
    ) THEN
        IF v_proc_oid IS NULL THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Trigger trg_order_customizations_updated_at exists but public.m13_set_updated_at() is missing. Aborting to prevent destroying foreign object.';
        END IF;

        SELECT t.tgfoid INTO v_tgfoid
        FROM pg_trigger t
        WHERE t.tgrelid = 'public.order_customizations'::regclass
          AND t.tgname = 'trg_order_customizations_updated_at'
          AND NOT t.tgisinternal;

        IF v_tgfoid != v_proc_oid THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Trigger trg_order_customizations_updated_at references unrelated procedure OID %. Aborting to prevent destroying foreign object.', v_tgfoid;
        END IF;
        DROP TRIGGER trg_order_customizations_updated_at ON public.order_customizations;
        RAISE NOTICE 'Trigger trg_order_customizations_updated_at verified and dropped.';
    END IF;

    -- Trigger: trg_customization_sessions_updated_at
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = 'public.customization_sessions'::regclass
          AND t.tgname = 'trg_customization_sessions_updated_at'
          AND NOT t.tgisinternal
    ) THEN
        IF v_proc_oid IS NULL THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Trigger trg_customization_sessions_updated_at exists but public.m13_set_updated_at() is missing. Aborting to prevent destroying foreign object.';
        END IF;

        SELECT t.tgfoid INTO v_tgfoid
        FROM pg_trigger t
        WHERE t.tgrelid = 'public.customization_sessions'::regclass
          AND t.tgname = 'trg_customization_sessions_updated_at'
          AND NOT t.tgisinternal;

        IF v_tgfoid != v_proc_oid THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Trigger trg_customization_sessions_updated_at references unrelated procedure OID %. Aborting to prevent destroying foreign object.', v_tgfoid;
        END IF;
        DROP TRIGGER trg_customization_sessions_updated_at ON public.customization_sessions;
        RAISE NOTICE 'Trigger trg_customization_sessions_updated_at verified and dropped.';
    END IF;

    -- Trigger: trg_personalization_templates_updated_at
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = 'public.personalization_templates'::regclass
          AND t.tgname = 'trg_personalization_templates_updated_at'
          AND NOT t.tgisinternal
    ) THEN
        IF v_proc_oid IS NULL THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Trigger trg_personalization_templates_updated_at exists but public.m13_set_updated_at() is missing. Aborting to prevent destroying foreign object.';
        END IF;

        SELECT t.tgfoid INTO v_tgfoid
        FROM pg_trigger t
        WHERE t.tgrelid = 'public.personalization_templates'::regclass
          AND t.tgname = 'trg_personalization_templates_updated_at'
          AND NOT t.tgisinternal;

        IF v_tgfoid != v_proc_oid THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Trigger trg_personalization_templates_updated_at references unrelated procedure OID %. Aborting to prevent destroying foreign object.', v_tgfoid;
        END IF;
        DROP TRIGGER trg_personalization_templates_updated_at ON public.personalization_templates;
        RAISE NOTICE 'Trigger trg_personalization_templates_updated_at verified and dropped.';
    END IF;
END $$;

-- ==============================================================================
-- 3. Drop M13-Specific Row Level Security Policies (Verified Definition)
-- ==============================================================================
-- Before dropping any policy, verify its command, exact role bindings, and qualifiers.
-- If an unrelated or altered same-named policy exists, abort safely.
DO $$
DECLARE
    v_cmd TEXT;
    v_roles NAME[];
    v_qual TEXT;
    v_with_check TEXT;
BEGIN
    -- Policy: "Public read active templates"
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'personalization_templates' 
          AND policyname = 'Public read active templates'
    ) THEN
        SELECT cmd, roles, qual, with_check INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'personalization_templates' 
          AND policyname = 'Public read active templates';

        IF v_cmd != 'SELECT' 
           OR NOT (v_roles @> ARRAY['anon'::name] AND v_roles @> ARRAY['authenticated'::name])
           OR (v_qual != '(is_active = true)' AND v_qual != 'is_active') 
           OR v_with_check IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Policy "Public read active templates" definition mismatch (cmd %, roles %, qual %, with_check %). Aborting.', 
                v_cmd, v_roles, v_qual, v_with_check;
        END IF;
        DROP POLICY "Public read active templates" ON public.personalization_templates;
        RAISE NOTICE 'Policy "Public read active templates" verified and dropped.';
    END IF;

    -- Policy: "Service role full access on personalization_templates"
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'personalization_templates' 
          AND policyname = 'Service role full access on personalization_templates'
    ) THEN
        SELECT cmd, roles, qual, with_check INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'personalization_templates' 
          AND policyname = 'Service role full access on personalization_templates';

        IF v_cmd != 'ALL' 
           OR NOT (v_roles @> ARRAY['service_role'::name]) 
           OR v_qual != 'true' 
           OR v_with_check != 'true' THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Policy "Service role full access on personalization_templates" definition mismatch (cmd %, roles %, qual %, with_check %). Aborting.',
                v_cmd, v_roles, v_qual, v_with_check;
        END IF;
        DROP POLICY "Service role full access on personalization_templates" ON public.personalization_templates;
        RAISE NOTICE 'Policy "Service role full access on personalization_templates" verified and dropped.';
    END IF;

    -- Policy: "Service role full access on customization_sessions"
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'customization_sessions' 
          AND policyname = 'Service role full access on customization_sessions'
    ) THEN
        SELECT cmd, roles, qual, with_check INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'customization_sessions' 
          AND policyname = 'Service role full access on customization_sessions';

        IF v_cmd != 'ALL' 
           OR NOT (v_roles @> ARRAY['service_role'::name]) 
           OR v_qual != 'true' 
           OR v_with_check != 'true' THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Policy "Service role full access on customization_sessions" definition mismatch (cmd %, roles %, qual %, with_check %). Aborting.',
                v_cmd, v_roles, v_qual, v_with_check;
        END IF;
        DROP POLICY "Service role full access on customization_sessions" ON public.customization_sessions;
        RAISE NOTICE 'Policy "Service role full access on customization_sessions" verified and dropped.';
    END IF;

    -- Policy: "Service role full access on order_customizations"
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'order_customizations' 
          AND policyname = 'Service role full access on order_customizations'
    ) THEN
        SELECT cmd, roles, qual, with_check INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public' 
          AND tablename = 'order_customizations' 
          AND policyname = 'Service role full access on order_customizations';

        IF v_cmd != 'ALL' 
           OR NOT (v_roles @> ARRAY['service_role'::name]) 
           OR v_qual != 'true' 
           OR v_with_check != 'true' THEN
            RAISE EXCEPTION 'M13 Rollback Aborted: Policy "Service role full access on order_customizations" definition mismatch (cmd %, roles %, qual %, with_check %). Aborting.',
                v_cmd, v_roles, v_qual, v_with_check;
        END IF;
        DROP POLICY "Service role full access on order_customizations" ON public.order_customizations;
        RAISE NOTICE 'Policy "Service role full access on order_customizations" verified and dropped.';
    END IF;
END $$;

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
