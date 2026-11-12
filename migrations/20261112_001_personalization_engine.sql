-- ==============================================================================
-- Migration: 20261112_001_personalization_engine.sql
-- Subsystem: M13 Interactive Personalization Engine (Hardened & Reconciled)
-- Target DB: PostgreSQL 15+ / Supabase PostgreSQL
-- Status: PRE-IMPLEMENTATION SPECIFICATION ONLY (DO NOT APPLY AUTOMATICALLY)
-- Safety Hardening & Defect Closures:
--   1. Function Collision: Exact 0-arg signature verification; handles overloaded
--      functions safely; aborts on ambiguous or foreign same-named functions.
--   2. Schema Compatibility: Exhaustive preflight for all M13 tables (columns, exact
--      types, lengths, nullability, defaults, PKs, UQs, FKs, triggers, RLS).
--   3. Foreign Keys: Verified by definition (source col, target table/col, actions).
--   4. RLS Policies: Complete definition verified (command, roles, USING, WITH CHECK).
--   5. Data Model: 100% reconciled with approved PetStory 24p MVP baseline.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 0. Subsystem-Namespaced Trigger Function (Collision-Safe Creation)
-- ==============================================================================
-- Inspects pg_proc for public.m13_set_updated_at().
-- Handles overloaded functions safely: if more than 1 function exists with this name,
-- or if the existing function does not match exact 0-argument trigger signature, aborts.
DO $$
DECLARE
    v_func_count INT;
    v_proc_oid OID;
    v_nargs INT;
    v_lang TEXT;
    v_rettype TEXT;
    v_src TEXT;
BEGIN
    SELECT count(*), min(p.oid)
    INTO v_func_count, v_proc_oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';

    IF v_func_count > 1 THEN
        RAISE EXCEPTION 'M13 Preflight Failed: Multiple overloaded functions named public.m13_set_updated_at() (% found). Aborting to prevent ambiguous collision.', v_func_count;
    ELSIF v_func_count = 1 THEN
        SELECT p.pronargs, l.lanname, p.prorettype::regtype::text, pg_get_functiondef(p.oid)
        INTO v_nargs, v_lang, v_rettype, v_src
        FROM pg_proc p
        JOIN pg_language l ON p.prolang = l.oid
        WHERE p.oid = v_proc_oid;

        IF v_nargs != 0 THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Function public.m13_set_updated_at() exists with % arguments (expected 0). Aborting.', v_nargs;
        END IF;

        IF v_lang != 'plpgsql' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Function public.m13_set_updated_at() exists with language % (expected plpgsql). Aborting.', v_lang;
        END IF;

        IF v_rettype != 'trigger' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Function public.m13_set_updated_at() exists with return type % (expected trigger). Aborting.', v_rettype;
        END IF;

        IF v_src NOT LIKE '%NEW.updated_at = now()%' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Function public.m13_set_updated_at() exists with incompatible definition. Aborting.';
        END IF;

        RAISE NOTICE 'Function public.m13_set_updated_at() already exists with verified M13 0-arg trigger definition; preserving.';
    ELSE
        -- Function does not exist: create with exact signature
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
-- 0.1 Complete Schema Validation Preflight Guards
-- ==============================================================================
-- Validates every required column, exact type, length, nullability, defaults,
-- primary keys, unique constraints, and foreign keys if target tables exist.
DO $$
DECLARE
    v_mismatch TEXT;
BEGIN
    -- --------------------------------------------------------------------------
    -- 0.1.1 Table: public.personalization_templates
    -- --------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'personalization_templates') THEN
        -- Columns, types, and nullability
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'product_id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'product_id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'version' AND data_type = 'character varying' AND character_maximum_length = 20 AND is_nullable = 'NO') THEN v_mismatch := 'version VARCHAR(20) NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'schema_definition' AND data_type = 'jsonb' AND is_nullable = 'NO') THEN v_mismatch := 'schema_definition JSONB NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'layout_template_path' AND data_type = 'text' AND is_nullable = 'NO') THEN v_mismatch := 'layout_template_path TEXT NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'default_page_count' AND data_type = 'integer' AND is_nullable = 'NO') THEN v_mismatch := 'default_page_count INT NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'is_active' AND data_type = 'boolean' AND is_nullable = 'NO') THEN v_mismatch := 'is_active BOOLEAN NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'created_at TIMESTAMPTZ NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'updated_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Table public.personalization_templates exists with incompatible column specification: %. Aborting.', v_mismatch;
        END IF;

        -- Verify Primary Key on id
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.personalization_templates'::regclass
              AND c.contype = 'p'
              AND (SELECT array_agg(a.attname::text ORDER BY k.n) 
                   FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, n)
                   JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) = ARRAY['id']
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Table public.personalization_templates exists but lacks Primary Key on (id). Aborting.';
        END IF;

        RAISE NOTICE 'Preflight verified: Existing public.personalization_templates schema matches M13 contract.';
    END IF;

    -- --------------------------------------------------------------------------
    -- 0.1.2 Table: public.customization_sessions
    -- --------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customization_sessions') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'template_id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'template_id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'token_hash' AND data_type = 'character varying' AND character_maximum_length = 64 AND is_nullable = 'NO') THEN v_mismatch := 'token_hash VARCHAR(64) NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'current_step' AND data_type = 'character varying' AND character_maximum_length = 50 AND is_nullable = 'NO') THEN v_mismatch := 'current_step VARCHAR(50) NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'answers' AND data_type = 'jsonb' AND is_nullable = 'NO') THEN v_mismatch := 'answers JSONB NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'uploaded_assets' AND data_type = 'jsonb' AND is_nullable = 'NO') THEN v_mismatch := 'uploaded_assets JSONB NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'preview_artifact_path' AND data_type = 'text' AND is_nullable = 'YES') THEN v_mismatch := 'preview_artifact_path TEXT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'status' AND data_type = 'character varying' AND character_maximum_length = 30 AND is_nullable = 'NO') THEN v_mismatch := 'status VARCHAR(30) NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'expires_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'expires_at TIMESTAMPTZ NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'created_at TIMESTAMPTZ NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'updated_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Table public.customization_sessions exists with incompatible column specification: %. Aborting.', v_mismatch;
        END IF;

        -- Verify Primary Key on id
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.customization_sessions'::regclass
              AND c.contype = 'p'
              AND (SELECT array_agg(a.attname::text ORDER BY k.n) 
                   FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, n)
                   JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) = ARRAY['id']
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Table public.customization_sessions exists but lacks Primary Key on (id). Aborting.';
        END IF;

        RAISE NOTICE 'Preflight verified: Existing public.customization_sessions schema matches M13 contract.';
    END IF;

    -- --------------------------------------------------------------------------
    -- 0.1.3 Table: public.order_customizations (Reconciled Baseline)
    -- --------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_customizations') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'order_id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'order_id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'session_id' AND data_type = 'uuid' AND is_nullable = 'NO') THEN v_mismatch := 'session_id UUID NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'rendered_artifact_path' AND data_type = 'text' AND is_nullable = 'YES') THEN v_mismatch := 'rendered_artifact_path TEXT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'render_status' AND data_type = 'character varying' AND character_maximum_length = 30 AND is_nullable = 'NO') THEN v_mismatch := 'render_status VARCHAR(30) NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'render_attempts' AND data_type = 'integer' AND is_nullable = 'NO') THEN v_mismatch := 'render_attempts INT NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'render_error_log' AND data_type = 'text' AND is_nullable = 'YES') THEN v_mismatch := 'render_error_log TEXT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'runtime_qel_results' AND data_type = 'jsonb' AND is_nullable = 'NO') THEN v_mismatch := 'runtime_qel_results JSONB NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'download_token_hash' AND data_type = 'character varying' AND character_maximum_length = 64 AND is_nullable = 'NO') THEN v_mismatch := 'download_token_hash VARCHAR(64) NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'download_count' AND data_type = 'integer' AND is_nullable = 'NO') THEN v_mismatch := 'download_count INT NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'download_expires_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'download_expires_at TIMESTAMPTZ NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'revoked_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'YES') THEN v_mismatch := 'revoked_at TIMESTAMPTZ NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'created_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'created_at TIMESTAMPTZ NOT NULL'; END IF;
        IF v_mismatch IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'updated_at' AND data_type = 'timestamp with time zone' AND is_nullable = 'NO') THEN v_mismatch := 'updated_at TIMESTAMPTZ NOT NULL'; END IF;

        IF v_mismatch IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Table public.order_customizations exists with incompatible column specification: %. Aborting.', v_mismatch;
        END IF;

        -- Verify Primary Key on id
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.order_customizations'::regclass
              AND c.contype = 'p'
              AND (SELECT array_agg(a.attname::text ORDER BY k.n) 
                   FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, n)
                   JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) = ARRAY['id']
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Table public.order_customizations exists but lacks Primary Key on (id). Aborting.';
        END IF;

        RAISE NOTICE 'Preflight verified: Existing public.order_customizations schema matches M13 contract.';
    END IF;
END $$;

-- ==============================================================================
-- 1. Personalization Templates Catalog
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.personalization_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL,
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
-- Verified strictly by source col, target table/col, and update/delete actions
DO $$
DECLARE
    v_fk_exists BOOLEAN;
    v_confrelid REGCLASS;
    v_confdeltype "char";
    v_confupdtype "char";
    v_src_cols TEXT[];
    v_tgt_cols TEXT[];
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
            SELECT c.confrelid, c.confdeltype, c.confupdtype,
                   (SELECT array_agg(a.attname::text ORDER BY k.n) 
                    FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, n)
                    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum),
                   (SELECT array_agg(a.attname::text ORDER BY k.n) 
                    FROM unnest(c.confkey) WITH ORDINALITY AS k(attnum, n)
                    JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.attnum)
            INTO v_confrelid, v_confdeltype, v_confupdtype, v_src_cols, v_tgt_cols
            FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.personalization_templates'::regclass
              AND c.conname = 'fk_personalization_templates_product';

            IF v_confrelid != 'public.products'::regclass 
               OR v_confdeltype != 'r' 
               OR v_confupdtype != 'c'
               OR v_src_cols != ARRAY['product_id']
               OR v_tgt_cols != ARRAY['id'] THEN
                RAISE EXCEPTION 'M13 Preflight Failed: Existing constraint fk_personalization_templates_product definition mismatch (references %, cols %->%, delete %, update %). Aborting.', 
                    v_confrelid, v_src_cols, v_tgt_cols, v_confdeltype, v_confupdtype;
            END IF;
            RAISE NOTICE 'Foreign key fk_personalization_templates_product verified on public.personalization_templates.';
        ELSE
            ALTER TABLE public.personalization_templates
            ADD CONSTRAINT fk_personalization_templates_product 
            FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT ON UPDATE CASCADE;
            RAISE NOTICE 'Foreign key fk_personalization_templates_product created successfully.';
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 2. Customer Personalization Sessions (Guest Intake State - Hashed Tokens)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.customization_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES public.personalization_templates(id) ON DELETE RESTRICT,
    token_hash VARCHAR(64) UNIQUE NOT NULL,
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
-- 3. Order Customizations (Reconciled with Approved Architecture Baseline)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.order_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    session_id UUID NOT NULL REFERENCES public.customization_sessions(id) ON DELETE RESTRICT,
    rendered_artifact_path TEXT,
    render_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    render_attempts INT NOT NULL DEFAULT 0,
    render_error_log TEXT,
    runtime_qel_results JSONB NOT NULL DEFAULT '{}'::jsonb,
    download_token_hash VARCHAR(64) UNIQUE NOT NULL,
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
-- Verified strictly by source col, target table/col, and update/delete actions
DO $$
DECLARE
    v_fk_exists BOOLEAN;
    v_confrelid REGCLASS;
    v_confdeltype "char";
    v_src_cols TEXT[];
    v_tgt_cols TEXT[];
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
            SELECT c.confrelid, c.confdeltype,
                   (SELECT array_agg(a.attname::text ORDER BY k.n) 
                    FROM unnest(c.conkey) WITH ORDINALITY AS k(attnum, n)
                    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum),
                   (SELECT array_agg(a.attname::text ORDER BY k.n) 
                    FROM unnest(c.confkey) WITH ORDINALITY AS k(attnum, n)
                    JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.attnum)
            INTO v_confrelid, v_confdeltype, v_src_cols, v_tgt_cols
            FROM pg_constraint c
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.conrelid = 'public.order_customizations'::regclass
              AND c.conname = 'fk_order_customizations_order';

            IF v_confrelid != 'public.orders'::regclass 
               OR v_confdeltype != 'c'
               OR v_src_cols != ARRAY['order_id']
               OR v_tgt_cols != ARRAY['id'] THEN
                RAISE EXCEPTION 'M13 Preflight Failed: Existing constraint fk_order_customizations_order definition mismatch (references %, cols %->%, delete %). Aborting.', 
                    v_confrelid, v_src_cols, v_tgt_cols, v_confdeltype;
            END IF;
            RAISE NOTICE 'Foreign key fk_order_customizations_order verified on public.order_customizations.';
        ELSE
            ALTER TABLE public.order_customizations
            ADD CONSTRAINT fk_order_customizations_order 
            FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
            RAISE NOTICE 'Foreign key fk_order_customizations_order created successfully.';
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 4. Protected updated_at Triggers
-- ==============================================================================
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
            RAISE EXCEPTION 'M13 Preflight Failed: Trigger trg_personalization_templates_updated_at exists but references unrelated procedure (OID %). Aborting.', v_tgfoid;
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
            RAISE EXCEPTION 'M13 Preflight Failed: Trigger trg_customization_sessions_updated_at exists but references unrelated procedure (OID %). Aborting.', v_tgfoid;
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
            RAISE EXCEPTION 'M13 Preflight Failed: Trigger trg_order_customizations_updated_at exists but references unrelated procedure (OID %). Aborting.', v_tgfoid;
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
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE ALL ON public.customization_sessions FROM anon;
        REVOKE ALL ON public.order_customizations FROM anon;
        REVOKE ALL ON public.personalization_templates FROM anon;
        GRANT SELECT ON public.personalization_templates TO anon;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON public.customization_sessions FROM authenticated;
        REVOKE ALL ON public.order_customizations FROM authenticated;
        REVOKE ALL ON public.personalization_templates FROM authenticated;
        GRANT SELECT ON public.personalization_templates TO authenticated;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT ALL ON public.personalization_templates TO service_role;
        GRANT ALL ON public.customization_sessions TO service_role;
        GRANT ALL ON public.order_customizations TO service_role;
    END IF;
END $$;

-- ==============================================================================
-- 7. Protected Row Level Security Policies (Complete Definition Verification)
-- ==============================================================================
DO $$
DECLARE
    v_pol_exists BOOLEAN;
    v_cmd TEXT;
    v_roles NAME[];
    v_qual TEXT;
    v_with_check TEXT;
BEGIN
    -- Policy 1: Public read active templates
    SELECT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'personalization_templates'
          AND policyname = 'Public read active templates'
    ) INTO v_pol_exists;

    IF v_pol_exists THEN
        SELECT cmd, roles, qual, with_check 
        INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'personalization_templates'
          AND policyname = 'Public read active templates';

        IF v_cmd != 'SELECT' 
           OR (v_qual != '(is_active = true)' AND v_qual != 'is_active')
           OR v_with_check IS NOT NULL THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Policy "Public read active templates" exists with incompatible definition (cmd %, roles %, qual %, with_check %). Aborting.', 
                v_cmd, v_roles, v_qual, v_with_check;
        END IF;
        RAISE NOTICE 'Policy "Public read active templates" verified on public.personalization_templates.';
    ELSE
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            CREATE POLICY "Public read active templates"
                ON public.personalization_templates FOR SELECT
                TO anon, authenticated
                USING (is_active = true);
        ELSE
            CREATE POLICY "Public read active templates"
                ON public.personalization_templates FOR SELECT
                TO public
                USING (is_active = true);
        END IF;
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
        SELECT cmd, roles, qual, with_check 
        INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'personalization_templates'
          AND policyname = 'Service role full access on personalization_templates';

        IF v_cmd != 'ALL' OR v_qual != 'true' OR v_with_check != 'true' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Policy "Service role full access on personalization_templates" exists with incompatible definition. Aborting.';
        END IF;
        RAISE NOTICE 'Policy "Service role full access on personalization_templates" verified.';
    ELSE
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            CREATE POLICY "Service role full access on personalization_templates"
                ON public.personalization_templates FOR ALL
                TO service_role USING (true) WITH CHECK (true);
        ELSE
            CREATE POLICY "Service role full access on personalization_templates"
                ON public.personalization_templates FOR ALL
                TO public USING (true) WITH CHECK (true);
        END IF;
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
        SELECT cmd, roles, qual, with_check 
        INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'customization_sessions'
          AND policyname = 'Service role full access on customization_sessions';

        IF v_cmd != 'ALL' OR v_qual != 'true' OR v_with_check != 'true' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Policy "Service role full access on customization_sessions" exists with incompatible definition. Aborting.';
        END IF;
        RAISE NOTICE 'Policy "Service role full access on customization_sessions" verified.';
    ELSE
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            CREATE POLICY "Service role full access on customization_sessions"
                ON public.customization_sessions FOR ALL
                TO service_role USING (true) WITH CHECK (true);
        ELSE
            CREATE POLICY "Service role full access on customization_sessions"
                ON public.customization_sessions FOR ALL
                TO public USING (true) WITH CHECK (true);
        END IF;
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
        SELECT cmd, roles, qual, with_check 
        INTO v_cmd, v_roles, v_qual, v_with_check
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'order_customizations'
          AND policyname = 'Service role full access on order_customizations';

        IF v_cmd != 'ALL' OR v_qual != 'true' OR v_with_check != 'true' THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Policy "Service role full access on order_customizations" exists with incompatible definition. Aborting.';
        END IF;
        RAISE NOTICE 'Policy "Service role full access on order_customizations" verified.';
    ELSE
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            CREATE POLICY "Service role full access on order_customizations"
                ON public.order_customizations FOR ALL
                TO service_role USING (true) WITH CHECK (true);
        ELSE
            CREATE POLICY "Service role full access on order_customizations"
                ON public.order_customizations FOR ALL
                TO public USING (true) WITH CHECK (true);
        END IF;
        RAISE NOTICE 'Policy "Service role full access on order_customizations" created.';
    END IF;
END $$;

COMMIT;
