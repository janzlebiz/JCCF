-- ==============================================================================
-- Migration: 20261112_001_personalization_engine.sql
-- Subsystem: M13 Interactive Personalization Engine (Remediated & Hardened)
-- Target DB: PostgreSQL 15+ / Supabase PostgreSQL
-- Status: PRE-IMPLEMENTATION SPECIFICATION ONLY (DO NOT APPLY AUTOMATICALLY)
-- Safety Hardening:
--   1. Subsystem-namespaced trigger function: m13_set_updated_at()
--      Prevents collisions or silent overwrites of platform-shared functions.
--   2. In-migration preflight checks: Safely aborts if pre-existing M13 tables
--      exist with incompatible columns or types.
--   3. Fully-scoped foreign key detection: Table constraints scoped strictly
--      by table_schema, table_name, AND constraint_name.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- 0. Subsystem-Namespaced Trigger Function
-- ==============================================================================
-- Uses dedicated M13 prefix to guarantee zero collision or silent overwrite
-- of existing shared platform functions.
CREATE OR REPLACE FUNCTION public.m13_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.m13_set_updated_at() IS 'M13-specific trigger function setting updated_at to now(). Owned exclusively by Subsystem M13.';

-- ==============================================================================
-- 0.1 In-Migration Preflight Compatibility Guards
-- ==============================================================================
-- Verify that if any target table already exists, its column definition matches
-- M13 requirements. Aborts immediately if incompatible schema drift is detected.
DO $$
BEGIN
    -- Check personalization_templates columns if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'personalization_templates') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'personalization_templates' AND column_name = 'schema_definition' AND data_type = 'jsonb'
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Existing public.personalization_templates has incompatible schema (missing jsonb schema_definition). Aborting migration.';
        END IF;
    END IF;

    -- Check customization_sessions columns if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customization_sessions') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'customization_sessions' AND column_name = 'token_hash' AND data_type = 'character varying'
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Existing public.customization_sessions has incompatible schema (missing varchar token_hash). Aborting migration.';
        END IF;
    END IF;

    -- Check order_customizations columns if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'order_customizations') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'order_customizations' AND column_name = 'download_token_hash' AND data_type = 'character varying'
        ) THEN
            RAISE EXCEPTION 'M13 Preflight Failed: Existing public.order_customizations has incompatible schema (missing varchar download_token_hash). Aborting migration.';
        END IF;
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
-- Scoped strictly to table_schema, table_name, AND constraint_name
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE table_schema = 'public' 
              AND table_name = 'personalization_templates'
              AND constraint_name = 'fk_personalization_templates_product'
        ) THEN
            ALTER TABLE public.personalization_templates
            ADD CONSTRAINT fk_personalization_templates_product 
            FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT ON UPDATE CASCADE;
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
-- 3. Order Customizations (Fulfillment & Delivery State Machine)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.order_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL, -- Logical reference to public.orders(id)
    session_id UUID NOT NULL REFERENCES public.customization_sessions(id) ON DELETE RESTRICT,
    customized_payload JSONB NOT NULL,
    render_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    render_attempts INT NOT NULL DEFAULT 0,
    artifact_pdf_path TEXT,
    artifact_checksum VARCHAR(64),
    download_token_hash VARCHAR(64) UNIQUE, -- SHA-256 of delivery token
    download_count INT NOT NULL DEFAULT 0,
    max_downloads INT NOT NULL DEFAULT 10,
    download_expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_order_customization_status CHECK (
        render_status IN ('pending', 'processing', 'completed', 'failed', 'qel_rejected', 'revoked', 'refunded')
    )
);

CREATE INDEX IF NOT EXISTS idx_order_customization_order ON public.order_customizations(order_id);
CREATE INDEX IF NOT EXISTS idx_order_download_token_hash ON public.order_customizations(download_token_hash);

COMMENT ON TABLE public.order_customizations IS 'Fulfillment records linking confirmed orders to rendered PDFs, hashed tokens, and revocation state.';

-- Foreign key added conditionally if public.orders table exists
-- Scoped strictly to table_schema, table_name, AND constraint_name
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'orders') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE table_schema = 'public' 
              AND table_name = 'order_customizations'
              AND constraint_name = 'fk_order_customizations_order'
        ) THEN
            ALTER TABLE public.order_customizations
            ADD CONSTRAINT fk_order_customizations_order 
            FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- ==============================================================================
-- 4. Automatic updated_at Triggers (Using M13-Namespaced Function)
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_personalization_templates_updated_at ON public.personalization_templates;
CREATE TRIGGER trg_personalization_templates_updated_at
BEFORE UPDATE ON public.personalization_templates
FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at();

DROP TRIGGER IF EXISTS trg_customization_sessions_updated_at ON public.customization_sessions;
CREATE TRIGGER trg_customization_sessions_updated_at
BEFORE UPDATE ON public.customization_sessions
FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at();

DROP TRIGGER IF EXISTS trg_order_customizations_updated_at ON public.order_customizations;
CREATE TRIGGER trg_order_customizations_updated_at
BEFORE UPDATE ON public.order_customizations
FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at();

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
-- 7. Row Level Security Policies
-- ==============================================================================
-- Public can read only active templates
DROP POLICY IF EXISTS "Public read active templates" ON public.personalization_templates;
CREATE POLICY "Public read active templates"
    ON public.personalization_templates FOR SELECT
    TO anon, authenticated
    USING (is_active = true);

-- Service role bypasses RLS for backend execution
DROP POLICY IF EXISTS "Service role full access on personalization_templates" ON public.personalization_templates;
CREATE POLICY "Service role full access on personalization_templates"
    ON public.personalization_templates FOR ALL
    TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Service role full access on customization_sessions" ON public.customization_sessions;
CREATE POLICY "Service role full access on customization_sessions"
    ON public.customization_sessions FOR ALL
    TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Service role full access on order_customizations" ON public.order_customizations;
CREATE POLICY "Service role full access on order_customizations"
    ON public.order_customizations FOR ALL
    TO service_role USING (true) WITH CHECK (true);

COMMIT;
