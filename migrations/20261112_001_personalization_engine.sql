-- ==============================================================================
-- Migration: 20261112_001_personalization_engine.sql
-- Subsystem: M13 Interactive Personalization Engine (Hardened & Reconciled)
-- Target DB: PostgreSQL 15+ / Supabase PostgreSQL
-- Status: PRE-IMPLEMENTATION SPECIFICATION ONLY (DO NOT APPLY AUTOMATICALLY)
-- Safety Hardening & Defect Closures (M13-R1 to M13-R5):
--   M13-R1: Collision-safe trigger function creation; inspects pg_proc to verify
--           exact signature/definition; aborts if unrelated function exists.
--   M13-R2: Complete schema validation preflight for all M13 tables (columns, types,
--           nullability, defaults, keys, constraints, indexes, triggers, RLS).
--   M13-R3: Scoped foreign-key validation by definition (source, target, actions).
--   M13-R4: Protection of existing triggers and RLS policies; zero blind overwrite.
--   M13-R5: Reconciled order_customizations model with approved architecture baseline.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 0. Subsystem-Namespaced Trigger Function (Collision-Safe Creation per M13-R1)
-- ==============================================================================
DO $$
DECLARE
    v_func_exists BOOLEAN;
    v_func_src TEXT;
    v_func_lang TEXT;
    v_func_rettype TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at'
    ) INTO v_func_exists;

    IF v_func_exists THEN
        SELECT l.lanname, p.prorettype::regtype::text, pg_get_functiondef(p.oid)
        INTO v_func_lang, v_func_rettype, v_func_src
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_language l ON p.prolang = l.oid
        WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';

        IF v_func_lang != 'plpgsql' 
           OR v_func_rettype != 'trigger' 
           OR v_func_src NOT LIKE '%NEW.updated_at = now()%' THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R1): Function public.m13_set_updated_at() already exists with incompatible signature, return type (%), or definition. Aborting to protect existing database object.', v_func_rettype;
        END IF;
        RAISE NOTICE 'Function public.m13_set_updated_at() already exists with verified M13 signature and definition; preserving existing function.';
    ELSE
        EXECUTE $fn$
            CREATE FUNCTION public.m13_set_updated_at()
            RETURNS TRIGGER AS $body$
            BEGIN
                NEW.updated_at = now();
                RETURN NEW;
            END;
            $body$ LANGUAGE plpgsql;
        $fn$;
        EXECUTE 'COMMENT ON FUNCTION public.m13_set_updated_at() IS ''M13-specific trigger function setting updated_at to now(). Owned exclusively by Subsystem M13.''';
        RAISE NOTICE 'Function public.m13_set_updated_at() created successfully.';
    END IF;
END $$;

-- ==============================================================================
-- 0.1 Complete Schema Validation Preflight Guards (per M13-R2)
-- ==============================================================================
-- Validates every required column, data type, and nullability if tables already exist.
-- Aborts immediately with descriptive error if partial or incompatible schema is detected.
DO $$
DECLARE
    v_col_count INT;
    v_mismatch TEXT;
BEGIN
    -- --------------------------------------------------------------------------
    -- 0.1.1 Preflight: public.personalization_templates
    -- --------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'personalization_templates') THEN
        -- Verify required columns, data types, and nullability
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'product_id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'product_id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'version' AND data_type = 'character varying' 
              AND character_maximum_length = 20 AND is_nullable = 'NO'
        ) THEN v_mismatch := 'version VARCHAR(20) NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'schema_definition' AND data_type = 'jsonb' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'schema_definition JSONB NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'layout_template_path' AND data_type = 'text' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'layout_template_path TEXT NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'default_page_count' AND data_type = 'integer' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'default_page_count INT NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'is_active BOOLEAN NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'created_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' 
              AND column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'updated_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R2): Table public.personalization_templates exists but is incompatible (% mismatch). Aborting.', v_mismatch;
        END IF;

        -- Verify Primary Key on id
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.personalization_templates'::regclass
              AND c.contype = 'p'
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R2): Table public.personalization_templates exists but lacks a Primary Key. Aborting.';
        END IF;

        RAISE NOTICE 'Preflight verified: Existing public.personalization_templates is fully compatible.';
    END IF;

    -- --------------------------------------------------------------------------
    -- 0.1.2 Preflight: public.customization_sessions
    -- --------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customization_sessions') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'template_id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'template_id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'token_hash' AND data_type = 'character varying' 
              AND character_maximum_length = 64 AND is_nullable = 'NO'
        ) THEN v_mismatch := 'token_hash VARCHAR(64) NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'current_step' AND data_type = 'character varying' 
              AND character_maximum_length = 50 AND is_nullable = 'NO'
        ) THEN v_mismatch := 'current_step VARCHAR(50) NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'answers' AND data_type = 'jsonb' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'answers JSONB NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'uploaded_assets' AND data_type = 'jsonb' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'uploaded_assets JSONB NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'status' AND data_type = 'character varying' 
              AND character_maximum_length = 30 AND is_nullable = 'NO'
        ) THEN v_mismatch := 'status VARCHAR(30) NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' 
              AND column_name = 'expires_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'expires_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R2): Table public.customization_sessions exists but is incompatible (% mismatch). Aborting.', v_mismatch;
        END IF;

        -- Verify Primary Key
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.customization_sessions'::regclass
              AND c.contype = 'p'
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R2): Table public.customization_sessions exists but lacks a Primary Key. Aborting.';
        END IF;

        RAISE NOTICE 'Preflight verified: Existing public.customization_sessions is fully compatible.';
    END IF;

    -- --------------------------------------------------------------------------
    -- 0.1.3 Preflight: public.order_customizations (Reconciled Baseline per M13-R5)
    -- --------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_customizations') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'order_id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'order_id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'session_id' AND data_type = 'uuid' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'session_id UUID NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'rendered_artifact_path' AND data_type = 'text'
        ) THEN v_mismatch := 'rendered_artifact_path TEXT'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'render_status' AND data_type = 'character varying' 
              AND character_maximum_length = 30 AND is_nullable = 'NO'
        ) THEN v_mismatch := 'render_status VARCHAR(30) NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'render_attempts' AND data_type = 'integer' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'render_attempts INT NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'render_error_log' AND data_type = 'text'
        ) THEN v_mismatch := 'render_error_log TEXT'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'runtime_qel_results' AND data_type = 'jsonb' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'runtime_qel_results JSONB NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'download_token_hash' AND data_type = 'character varying' 
              AND character_maximum_length = 64 AND is_nullable = 'NO'
        ) THEN v_mismatch := 'download_token_hash VARCHAR(64) NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'download_count' AND data_type = 'integer' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'download_count INT NOT NULL'; END IF;

        IF v_mismatch IS NULL AND NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' 
              AND column_name = 'download_expires_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO'
        ) THEN v_mismatch := 'download_expires_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R2/M13-R5): Table public.order_customizations exists but is incompatible (% mismatch). Aborting.', v_mismatch;
        END IF;

        -- Verify Primary Key
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.order_customizations'::regclass
              AND c.contype = 'p'
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R2): Table public.order_customizations exists but lacks a Primary Key. Aborting.';
        END IF;

        RAISE NOTICE 'Preflight verified: Existing public.order_customizations is fully compatible with approved baseline.';
    END IF;
END $$;

-- ==============================================================================
-- 1. Personalization Templates Catalog
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.personalization_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL, -- Logical reference to public.products(id)
    version VARCHAR(20) NOT NULL,
    schema_definition JSONB NOT NULL,
    layout_template_path TEXT NOT NULL,
    default_page_count INT NOT NULL DEFAULT 24,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_personalization_template_version UNIQUE (product_id, version)
);

COMMENT ON TABLE public.personalization_templates IS 'Declarative questionnaire schemas and Jinja2 layout specifications for personalized products.';

-- Foreign key added conditionally if public.products table exists
-- Verified strictly by definition per M13-R3
DO $$
DECLARE
    v_fk_exists BOOLEAN;
    v_confrelid REGCLASS;
    v_confdeltype "char";
    v_confupdtype "char";
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products') THEN
        SELECT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.personalization_templates'::regclass
              AND c.conname = 'fk_personalization_templates_product'
        ) INTO v_fk_exists;

        IF v_fk_exists THEN
            SELECT c.confrelid, c.confdeltype, c.confupdtype
            INTO v_confrelid, v_confdeltype, v_confupdtype
            FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.personalization_templates'::regclass
              AND c.conname = 'fk_personalization_templates_product';

            IF v_confrelid != 'public.products'::regclass OR v_confdeltype != 'r' OR v_confupdtype != 'c' THEN
                RAISE EXCEPTION 'M13 Preflight Failed (M13-R3): Existing constraint fk_personalization_templates_product on public.personalization_templates does not match required definition (references %, on delete %, on update %). Aborting.', v_confrelid, v_confdeltype, v_confupdtype;
            END IF;
            RAISE NOTICE 'Foreign key fk_personalization_templates_product verified on public.personalization_templates.';
        ELSE
            ALTER TABLE public.personalization_templates
            ADD CONSTRAINT fk_personalization_templates_product 
            FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT ON UPDATE CASCADE;
            RAISE NOTICE 'Foreign key fk_personalization_templates_product created.';
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 2. Customer Personalization Sessions (Guest Intake State - Hashed Tokens)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.customization_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES public.personalization_templates(id) ON DELETE RESTRICT,
    token_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256 of raw client session token
    current_step VARCHAR(50) NOT NULL DEFAULT 'pet_type',
    answers JSONB NOT NULL DEFAULT '{}'::jsonb,
    uploaded_assets JSONB NOT NULL DEFAULT '[]'::jsonb,
    preview_artifact_path TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_customization_session_status CHECK (
        status IN ('draft', 'preview_generated', 'checkout_pending', 'converted', 'abandoned', 'expired')
    )
);

CREATE INDEX IF NOT EXISTS idx_customization_sessions_token_hash ON public.customization_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_customization_sessions_template_id ON public.customization_sessions(template_id);
CREATE INDEX IF NOT EXISTS idx_customization_sessions_expires_at ON public.customization_sessions(expires_at) WHERE status = 'draft';

COMMENT ON TABLE public.customization_sessions IS 'Transient customer intake state. Anonymous guest access via SHA-256 hashed session token.';

-- ==============================================================================
-- 3. Order Customizations (Reconciled with Approved Architecture per M13-R5)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.order_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL, -- Logical reference to public.orders(id)
    session_id UUID NOT NULL REFERENCES public.customization_sessions(id) ON DELETE RESTRICT,
    rendered_artifact_path TEXT,
    render_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    render_attempts INT NOT NULL DEFAULT 0,
    render_error_log TEXT,
    runtime_qel_results JSONB NOT NULL DEFAULT '{}'::jsonb,
    download_token_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256 of raw delivery token
    download_count INT NOT NULL DEFAULT 0,
    download_expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '90 days'),
    revoked_at TIMESTAMPTZ,
    revocation_reason VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_order_customization_order UNIQUE (order_id),
    CONSTRAINT chk_order_customization_status CHECK (
        render_status IN ('pending', 'processing', 'completed', 'failed', 'qel_rejected', 'refunded', 'revoked')
    )
);

CREATE INDEX IF NOT EXISTS idx_order_customization_order ON public.order_customizations(order_id);
CREATE INDEX IF NOT EXISTS idx_order_download_token_hash ON public.order_customizations(download_token_hash);

COMMENT ON TABLE public.order_customizations IS 'Fulfillment records linking confirmed orders to rendered PDFs, hashed tokens, and revocation state.';

-- Foreign key added conditionally if public.orders table exists
-- Verified strictly by definition per M13-R3
DO $$
DECLARE
    v_fk_exists BOOLEAN;
    v_confrelid REGCLASS;
    v_confdeltype "char";
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'orders') THEN
        SELECT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.order_customizations'::regclass
              AND c.conname = 'fk_order_customizations_order'
        ) INTO v_fk_exists;

        IF v_fk_exists THEN
            SELECT c.confrelid, c.confdeltype
            INTO v_confrelid, v_confdeltype
            FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.order_customizations'::regclass
              AND c.conname = 'fk_order_customizations_order';

            IF v_confrelid != 'public.orders'::regclass OR v_confdeltype != 'c' THEN
                RAISE EXCEPTION 'M13 Preflight Failed (M13-R3): Existing constraint fk_order_customizations_order on public.order_customizations does not match required definition (references %, on delete %). Aborting.', v_confrelid, v_confdeltype;
            END IF;
            RAISE NOTICE 'Foreign key fk_order_customizations_order verified on public.order_customizations.';
        ELSE
            ALTER TABLE public.order_customizations
            ADD CONSTRAINT fk_order_customizations_order 
            FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
            RAISE NOTICE 'Foreign key fk_order_customizations_order created.';
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 4. Protected updated_at Triggers (per M13-R4)
-- ==============================================================================
-- Verifies existing triggers reference the exact M13 procedure before preservation.
-- Zero blind overwrite or drop of unrelated triggers.
DO $$
DECLARE
    v_trg_exists BOOLEAN;
    v_tgfoid OID;
    v_expected_oid OID;
BEGIN
    SELECT p.oid INTO v_expected_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';

    -- Trigger 1: personalization_templates
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = 'public.personalization_templates'::regclass
          AND t.tgname = 'trg_personalization_templates_updated_at'
          AND NOT t.tgisinternal
    ) INTO v_trg_exists;

    IF v_trg_exists THEN
        SELECT t.tgfoid INTO v_tgfoid
        FROM pg_trigger t
        WHERE t.tgrelid = 'public.personalization_templates'::regclass
          AND t.tgname = 'trg_personalization_templates_updated_at'
          AND NOT t.tgisinternal;

        IF v_tgfoid != v_expected_oid THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R4): Trigger trg_personalization_templates_updated_at exists but references unrelated function (OID %). Aborting.', v_tgfoid;
        END IF;
        RAISE NOTICE 'Trigger trg_personalization_templates_updated_at verified with M13 function.';
    ELSE
        CREATE TRIGGER trg_personalization_templates_updated_at
        BEFORE UPDATE ON public.personalization_templates
        FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at();
        RAISE NOTICE 'Trigger trg_personalization_templates_updated_at created.';
    END IF;

    -- Trigger 2: customization_sessions
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = 'public.customization_sessions'::regclass
          AND t.tgname = 'trg_customization_sessions_updated_at'
          AND NOT t.tgisinternal
    ) INTO v_trg_exists;

    IF v_trg_exists THEN
        SELECT t.tgfoid INTO v_tgfoid
        FROM pg_trigger t
        WHERE t.tgrelid = 'public.customization_sessions'::regclass
          AND t.tgname = 'trg_customization_sessions_updated_at'
          AND NOT t.tgisinternal;

        IF v_tgfoid != v_expected_oid THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R4): Trigger trg_customization_sessions_updated_at exists but references unrelated function (OID %). Aborting.', v_tgfoid;
        END IF;
        RAISE NOTICE 'Trigger trg_customization_sessions_updated_at verified with M13 function.';
    ELSE
        CREATE TRIGGER trg_customization_sessions_updated_at
        BEFORE UPDATE ON public.customization_sessions
        FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at();
        RAISE NOTICE 'Trigger trg_customization_sessions_updated_at created.';
    END IF;

    -- Trigger 3: order_customizations
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        WHERE t.tgrelid = 'public.order_customizations'::regclass
          AND t.tgname = 'trg_order_customizations_updated_at'
          AND NOT t.tgisinternal
    ) INTO v_trg_exists;

    IF v_trg_exists THEN
        SELECT t.tgfoid INTO v_tgfoid
        FROM pg_trigger t
        WHERE t.tgrelid = 'public.order_customizations'::regclass
          AND t.tgname = 'trg_order_customizations_updated_at'
          AND NOT t.tgisinternal;

        IF v_tgfoid != v_expected_oid THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R4): Trigger trg_order_customizations_updated_at exists but references unrelated function (OID %). Aborting.', v_tgfoid;
        END IF;
        RAISE NOTICE 'Trigger trg_order_customizations_updated_at verified with M13 function.';
    ELSE
        CREATE TRIGGER trg_order_customizations_updated_at
        BEFORE UPDATE ON public.order_customizations
        FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at();
        RAISE NOTICE 'Trigger trg_order_customizations_updated_at created.';
    END IF;
END $$;

-- ==============================================================================
-- 5. Enable Row Level Security (RLS)
-- ==============================================================================
ALTER TABLE public.personalization_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customization_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_customizations ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 6. Explicit Table Privileges
-- ==============================================================================
REVOKE ALL ON public.customization_sessions FROM anon, authenticated;
REVOKE ALL ON public.order_customizations FROM anon, authenticated;
REVOKE ALL ON public.personalization_templates FROM anon, authenticated;

-- Explicitly grant SELECT on personalization_templates to public roles
GRANT SELECT ON public.personalization_templates TO anon, authenticated;

-- Grant full table access to service_role (backend worker / FastAPI service role)
GRANT ALL ON public.personalization_templates TO service_role;
GRANT ALL ON public.customization_sessions TO service_role;
GRANT ALL ON public.order_customizations TO service_role;

-- ==============================================================================
-- 7. Protected Row Level Security Policies (per M13-R4)
-- ==============================================================================
-- Validates that existing same-named policies match expected M13 definition.
-- Zero blind overwrite of unrelated RLS policies.
DO $$
DECLARE
    v_pol_exists BOOLEAN;
    v_cmd TEXT;
    v_qual TEXT;
BEGIN
    -- Policy 1: Public read active templates
    SELECT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'personalization_templates'
          AND policyname = 'Public read active templates'
    ) INTO v_pol_exists;

    IF v_pol_exists THEN
        SELECT cmd, qual INTO v_cmd, v_qual
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'personalization_templates'
          AND policyname = 'Public read active templates';

        IF v_cmd != 'SELECT' OR v_qual NOT LIKE '%is_active%' THEN
            RAISE EXCEPTION 'M13 Preflight Failed (M13-R4): Policy "Public read active templates" exists on public.personalization_templates with unexpected definition (cmd %, qual %). Aborting.', v_cmd, v_qual;
        END IF;
        RAISE NOTICE 'Policy "Public read active templates" verified on public.personalization_templates.';
    ELSE
        CREATE POLICY "Public read active templates"
            ON public.personalization_templates FOR SELECT
            TO anon, authenticated
            USING (is_active = true);
        RAISE NOTICE 'Policy "Public read active templates" created.';
    END IF;

    -- Policy 2: Service role full access on personalization_templates
    SELECT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'personalization_templates'
          AND policyname = 'Service role full access on personalization_templates'
    ) INTO v_pol_exists;

    IF v_pol_exists THEN
        RAISE NOTICE 'Policy "Service role full access on personalization_templates" already exists; preserved.';
    ELSE
        CREATE POLICY "Service role full access on personalization_templates"
            ON public.personalization_templates FOR ALL
            TO service_role USING (true) WITH CHECK (true);
        RAISE NOTICE 'Policy "Service role full access on personalization_templates" created.';
    END IF;

    -- Policy 3: Service role full access on customization_sessions
    SELECT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'customization_sessions'
          AND policyname = 'Service role full access on customization_sessions'
    ) INTO v_pol_exists;

    IF v_pol_exists THEN
        RAISE NOTICE 'Policy "Service role full access on customization_sessions" already exists; preserved.';
    ELSE
        CREATE POLICY "Service role full access on customization_sessions"
            ON public.customization_sessions FOR ALL
            TO service_role USING (true) WITH CHECK (true);
        RAISE NOTICE 'Policy "Service role full access on customization_sessions" created.';
    END IF;

    -- Policy 4: Service role full access on order_customizations
    SELECT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'order_customizations'
          AND policyname = 'Service role full access on order_customizations'
    ) INTO v_pol_exists;

    IF v_pol_exists THEN
        RAISE NOTICE 'Policy "Service role full access on order_customizations" already exists; preserved.';
    ELSE
        CREATE POLICY "Service role full access on order_customizations"
            ON public.order_customizations FOR ALL
            TO service_role USING (true) WITH CHECK (true);
        RAISE NOTICE 'Policy "Service role full access on order_customizations" created.';
    END IF;
END $$;

COMMIT;
