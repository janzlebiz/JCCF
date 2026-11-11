-- ==============================================================================
-- Migration: 20261112_001_personalization_engine.sql
-- Subsystem: M13 Interactive Personalization Engine (Remediated & Hardened)
-- Target DB: PostgreSQL 15+ / Supabase PostgreSQL
-- Status: PRE-IMPLEMENTATION SPECIFICATION ONLY (DO NOT APPLY AUTOMATICALLY)
-- ==============================================================================

BEGIN;

-- 0. Standard updated_at Trigger Function
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Personalization Templates Catalog
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
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_personalization_templates_product'
        ) THEN
            ALTER TABLE public.personalization_templates
            ADD CONSTRAINT fk_personalization_templates_product 
            FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT ON UPDATE CASCADE;
        END IF;
    END IF;
END $$;

-- 2. Customer Personalization Sessions (Guest Intake State - Hashed Tokens)
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
    CONSTRAINT ck_session_status CHECK (status IN ('draft', 'preview_generated', 'checkout_pending', 'converted', 'expired'))
);

CREATE INDEX IF NOT EXISTS idx_customization_token_hash ON public.customization_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_customization_cleanup ON public.customization_sessions(status, expires_at);

COMMENT ON TABLE public.customization_sessions IS 'Transient state of buyer quiz sessions indexed by SHA-256 hashed tokens.';

-- 3. Order Customizations (Paid Instance Linkage - Hashed Download Tokens)
CREATE TABLE IF NOT EXISTS public.order_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL, -- Logical reference to public.orders(id)
    session_id UUID NOT NULL REFERENCES public.customization_sessions(id) ON DELETE RESTRICT,
    rendered_artifact_path TEXT,
    render_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    render_attempts INT NOT NULL DEFAULT 0,
    render_error_log TEXT,
    runtime_qel_results JSONB NOT NULL DEFAULT '{}'::jsonb,
    download_token_hash VARCHAR(64) UNIQUE NOT NULL, -- SHA-256 of raw client download token
    download_count INT NOT NULL DEFAULT 0,
    download_expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '90 days'),
    revoked_at TIMESTAMPTZ,
    revocation_reason VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_order_customization_order UNIQUE (order_id),
    CONSTRAINT ck_render_status CHECK (render_status IN ('pending', 'processing', 'completed', 'failed', 'qel_rejected', 'refunded', 'revoked'))
);

CREATE INDEX IF NOT EXISTS idx_order_customization_order ON public.order_customizations(order_id);
CREATE INDEX IF NOT EXISTS idx_order_download_token_hash ON public.order_customizations(download_token_hash);

COMMENT ON TABLE public.order_customizations IS 'Fulfillment records linking confirmed orders to rendered PDFs, hashed tokens, and revocation state.';

-- Foreign key added conditionally if public.orders table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'orders') THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'fk_order_customizations_order'
        ) THEN
            ALTER TABLE public.order_customizations
            ADD CONSTRAINT fk_order_customizations_order 
            FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- 4. Automatic updated_at Triggers
DROP TRIGGER IF EXISTS trg_personalization_templates_updated_at ON public.personalization_templates;
CREATE TRIGGER trg_personalization_templates_updated_at
BEFORE UPDATE ON public.personalization_templates
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS trg_customization_sessions_updated_at ON public.customization_sessions;
CREATE TRIGGER trg_customization_sessions_updated_at
BEFORE UPDATE ON public.customization_sessions
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS trg_order_customizations_updated_at ON public.order_customizations;
CREATE TRIGGER trg_order_customizations_updated_at
BEFORE UPDATE ON public.order_customizations
FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.personalization_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customization_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_customizations ENABLE ROW LEVEL SECURITY;

-- 6. Explicit Table Privileges
REVOKE ALL ON public.customization_sessions FROM anon, authenticated;
REVOKE ALL ON public.order_customizations FROM anon, authenticated;
REVOKE ALL ON public.personalization_templates FROM anon, authenticated;

-- Explicitly grant SELECT on personalization_templates to public roles
GRANT SELECT ON public.personalization_templates TO anon, authenticated;

-- Grant full table access to service_role (backend worker / FastAPI service role)
GRANT ALL ON public.personalization_templates TO service_role;
GRANT ALL ON public.customization_sessions TO service_role;
GRANT ALL ON public.order_customizations TO service_role;

-- 7. Row Level Security Policies
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
