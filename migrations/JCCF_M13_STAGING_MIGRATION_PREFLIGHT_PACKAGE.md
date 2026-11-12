# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Staging Migration Preflight, Verification & Rollback Package

**Document ID:** `JCCF-PKG-MIG-001`  
**Date:** 12 November 2026  
**Status:** Preflight Specification & Rollback Procedure (Execution NOT AUTHORIZED)  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql`  
**Rollback Script:** `migrations/20261112_001_personalization_engine_rollback.sql`  
**Governing State:** Decision 4 Not Authorized (Held at Phase Boundary)  

---

## 1. Executive Summary

This preflight package prepares all technical requirements for **Decision 4 (Development / Staging Database Migration)** without executing any database statements. It specifies:
1. Target staging project identity requirements.
2. Preflight schema and dependency checks.
3. Pre-migration backup and snapshot recovery methods.
4. Complete SQL statement diff and privilege audit.
5. Exact automated rollback procedure.

---

## 2. Target Staging Project Identity & Environment Boundaries

Before Decision 4 can be requested or authorized, the platform operator must confirm the target environment variables:
* **Target Host:** Dedicated Supabase Development/Staging Project (e.g., `db.<project-ref>.supabase.co`).
* **Isolation Rule:** Migration must **NEVER** be applied to a production instance or shared environment.
* **Service Role Key:** Confined exclusively to local backend migration runner (`psql` or Supabase CLI); never exposed to client apps.

---

## 3. Preflight Schema Verification & Dependency Checks

Execute the following diagnostic read-only queries against the staging database prior to running the migration:

```sql
-- PREFLIGHT CHECK 1: Verify PostgreSQL Version >= 14 (Native gen_random_uuid support)
SELECT version();

-- PREFLIGHT CHECK 2: Verify gen_random_uuid() function availability
-- Note: PostgreSQL 13+ includes gen_random_uuid() natively in the core distribution.
-- pgcrypto extension is NOT required or created by migration 20261112_001_personalization_engine.sql.
SELECT gen_random_uuid();

-- PREFLIGHT CHECK 3: Verify existing public schema tables (products, orders)
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('products', 'orders', 'personalization_templates', 'customization_sessions', 'order_customizations');

-- PREFLIGHT CHECK 4: Check if standard PostgREST roles exist
SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role');
```

### Preflight Invariants
* **UUID Generation:** `gen_random_uuid()` is natively built into PostgreSQL 13+ (standard in Supabase PostgreSQL 15+). The migration does **not** create or require the `pgcrypto` extension.
* **Conditional Foreign Keys:**
  - If `public.products` does not exist, the conditional block skips `fk_personalization_templates_product` without error.
  - If `public.orders` does not exist, the conditional block skips `fk_order_customizations_order` without error.
* **Role Permissions:** Standard Supabase roles `anon`, `authenticated`, and `service_role` must exist before running privilege grant/revoke blocks.

---

## 4. Pre-Migration Backup & Recovery Procedure

Before applying the migration to staging:
1. **Supabase Snapshot Backup:**
   - Navigate to Supabase Dashboard $\rightarrow$ Database $\rightarrow$ Backups.
   - Trigger a manual logical backup or verify latest PITR snapshot timestamp.
2. **Local Schema Dump:**
   ```bash
   pg_dump -h db.<staging-ref>.supabase.co -U postgres -d postgres --schema-only -f pre_m13_staging_schema.sql
   ```
3. **Recovery SLA:** If migration fails mid-stream, transaction rolls back automatically (`BEGIN ... COMMIT` block). If manual recovery is required, restore from `pre_m13_staging_schema.sql`.

---

## 5. Migration Statement Diff & Privilege Audit

The migration introduces:
1. `public.personalization_templates` (3 active rows expected for templates):
   - Table-level `GRANT SELECT ON public.personalization_templates TO anon, authenticated;`.
   - RLS Policy: `USING (is_active = true)`.
2. `public.customization_sessions`:
   - Table-level `REVOKE ALL ON public.customization_sessions FROM anon, authenticated;`.
   - Table-level `GRANT ALL ON public.customization_sessions TO service_role;`.
   - Public direct PostgREST access is completely blocked (HTTP 401/403).
3. `public.order_customizations`:
   - Table-level `REVOKE ALL ON public.order_customizations FROM anon, authenticated;`.
   - Table-level `GRANT ALL ON public.order_customizations TO service_role;`.
   - Public direct PostgREST access is completely blocked.
4. Triggers:
   - `trg_personalization_templates_updated_at`
   - `trg_customization_sessions_updated_at`
   - `trg_order_customizations_updated_at`

---

## 6. Staging Rollback Plan

If Decision 4 is authorized and subsequent staging tests detect regression or failure:
1. Execute `migrations/20261112_001_personalization_engine_rollback.sql`.
2. The rollback script:
   - Drops all 4 M13 RLS policies.
   - Drops all 3 M13 automated updated_at triggers.
   - Drops tables `order_customizations`, `customization_sessions`, and `personalization_templates` via `CASCADE`.
   - **Dependency-Safe Function Cleanup:** Queries `information_schema.triggers` before dropping `public.set_current_timestamp_updated_at()`. If other database tables depend on the function, it is safely preserved with a diagnostic notice.
3. Verify clean staging state:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
     AND table_name IN ('personalization_templates', 'customization_sessions', 'order_customizations');
   -- Must return 0 rows
   ```

---

## 7. Current Authorization Status

**Decision 4 remains strictly NOT AUTHORIZED.** This preflight package provides the complete technical foundation for operator review.

