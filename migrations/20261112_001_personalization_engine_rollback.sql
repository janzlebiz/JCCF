-- ==============================================================================
-- Migration Rollback: 20261112_001_personalization_engine_rollback.sql
-- Target Subsystem: Module M13 (Interactive Personalization Engine)
-- Execution Mode: Manual Staging Rollback Plan (NOT RUN - PHASE 1 BLOCKED)
-- ==============================================================================

BEGIN;

-- 1. Drop Row Level Security Policies
DROP POLICY IF EXISTS "Public read active templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on personalization_templates" ON public.personalization_templates;
DROP POLICY IF EXISTS "Service role full access on customization_sessions" ON public.customization_sessions;
DROP POLICY IF EXISTS "Service role full access on order_customizations" ON public.order_customizations;

-- 2. Drop Automated Timestamp Triggers
DROP TRIGGER IF EXISTS trg_personalization_templates_updated_at ON public.personalization_templates;
DROP TRIGGER IF EXISTS trg_customization_sessions_updated_at ON public.customization_sessions;
DROP TRIGGER IF EXISTS trg_order_customizations_updated_at ON public.order_customizations;

-- Drop function if not utilized by other tables
-- (Safe to drop if exclusively created for M13)
DROP FUNCTION IF EXISTS public.set_current_timestamp_updated_at();

-- 3. Drop Tables in Reverse Dependency Order
DROP TABLE IF EXISTS public.order_customizations CASCADE;
DROP TABLE IF EXISTS public.customization_sessions CASCADE;
DROP TABLE IF EXISTS public.personalization_templates CASCADE;

COMMIT;
