# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Staging Migration Preflight, Verification & Rollback Package (v3.0)

**Document ID:** `JCCF-PKG-MIG-001`  
**Version:** 3.0 (Comprehensive Schema Preflight, Reconciled Baseline & Restrictive Rollback)  
**Date:** 13 November 2026  
**Status:** Preflight Specification & Rollback Procedure (Execution NOT AUTHORIZED)  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql`  
**Rollback Script:** `migrations/20261112_001_personalization_engine_rollback.sql`  
**Governing State:** Decision 4 Not Authorized (Held at Phase Boundary)  

---

## 1. Executive Summary & Defect Closures (M13-R1 to M13-R6)

This preflight package specifies the technical preconditions, comprehensive schema compatibility checks, and rollback safety mechanisms for **Decision 4 (Development / Staging Database Migration)**.

Key safety remediations and defect closures in v3.0:
1. **Collision-Safe Function Creation (M13-R1):** Migration inspects `pg_proc` for `public.m13_set_updated_at()`. Verifies exact signature (returns `trigger`, language `plpgsql`, body contains `NEW.updated_at = now()`). Aborts migration if an incompatible function exists, preventing silent replacement of existing procedures.
2. **Complete Schema Preflight Validation (M13-R2):** Replaced 3-column representative checks with comprehensive validation across all 3 M13 tables. Inspects 100% of required columns, exact PostgreSQL data types, nullability, defaults, primary keys, and unique constraints.
3. **Foreign-Key Validation by Definition (M13-R3):** Scopes constraint checks by table and verifies referenced schema, table, columns, and `ON DELETE` / `ON UPDATE` actions (`RESTRICT` / `CASCADE`), aborting if existing constraints differ.
4. **Trigger & Policy Protection (M13-R4):** Replaced blind `DROP TRIGGER / POLICY IF EXISTS` with inspection blocks. Validates procedure OID and policy definition (`cmd`, `qual`), preventing destruction or replacement of unrelated pre-existing objects.
5. **Reconciled Data Model (M13-R5):** Fully restored the approved architecture baseline for `order_customizations`:
   - `rendered_artifact_path TEXT` restored.
   - `render_error_log TEXT` restored.
   - `runtime_qel_results JSONB NOT NULL DEFAULT '{}'::jsonb` restored.
   - `CONSTRAINT uq_order_customization_order UNIQUE (order_id)` restored.
   - `download_token_hash VARCHAR(64) UNIQUE NOT NULL` restored.
   - `download_expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '90 days')` restored (30 days for transient quiz sessions, 90 days for customer download fulfillment).
   - Unapproved `customized_payload` and `max_downloads` removed.
6. **Demonstrably Safe Restrictive Rollback (M13-R6):** All tables dropped with `DROP TABLE ... RESTRICT` (zero `CASCADE`). M13 function dropped with `RESTRICT` only after verifying zero external trigger dependencies. Documents scope of reversibility.

---

## 2. Target Staging Project Identity & Environment Boundaries

Before Decision 4 can be requested or authorized, the platform operator must confirm the target environment variables:
* **Target Host:** Dedicated Supabase Development/Staging Project (e.g., `db.<staging-ref>.supabase.co`).
* **Isolation Rule:** Migration must **NEVER** be applied to a production instance or shared environment.
* **Service Role Key:** Confined exclusively to local backend migration runner (`psql` or Supabase CLI); never exposed to client apps.

---

## 3. Preflight Schema Verification & Compatibility Checks

Execute the following diagnostic read-only queries against the staging database prior to running the migration:

```sql
-- PREFLIGHT CHECK 1: Verify PostgreSQL Version >= 14 (Native gen_random_uuid support)
SELECT version();

-- PREFLIGHT CHECK 2: Verify native gen_random_uuid() function availability
-- Note: PostgreSQL 13+ includes gen_random_uuid() natively in the core distribution.
-- pgcrypto extension is NOT required or created by migration 20261112_001_personalization_engine.sql.
SELECT gen_random_uuid();

-- PREFLIGHT CHECK 3: Verify existing public schema tables (products, orders)
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('products', 'orders', 'personalization_templates', 'customization_sessions', 'order_customizations');

-- PREFLIGHT CHECK 4: Complete Column & Data Type Compatibility Inspection
SELECT table_name, column_name, data_type, is_nullable, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('personalization_templates', 'customization_sessions', 'order_customizations')
ORDER BY table_name, ordinal_position;

-- PREFLIGHT CHECK 5: Verify foreign key constraint definitions
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.update_rule,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ('personalization_templates', 'order_customizations')
  AND tc.constraint_type = 'FOREIGN KEY';

-- PREFLIGHT CHECK 6: Check standard PostgREST roles exist
SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role');
```

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
1. Trigger Function:
   - `public.m13_set_updated_at()`: Dedicated M13 trigger function verified against `pg_proc`.
2. `public.personalization_templates`:
   - Table-level `GRANT SELECT ON public.personalization_templates TO anon, authenticated;`.
   - RLS Policy: `USING (is_active = true)`.
3. `public.customization_sessions`:
   - Table-level `REVOKE ALL ON public.customization_sessions FROM anon, authenticated;`.
   - Table-level `GRANT ALL ON public.customization_sessions TO service_role;`.
   - Public direct PostgREST access is completely blocked (HTTP 401/403).
4. `public.order_customizations` (Reconciled):
   - Columns: `id`, `order_id`, `session_id`, `rendered_artifact_path`, `render_status`, `render_attempts`, `render_error_log`, `runtime_qel_results`, `download_token_hash`, `download_count`, `download_expires_at` (90 days), `revoked_at`, `revocation_reason`, `created_at`, `updated_at`.
   - Table-level `REVOKE ALL ON public.order_customizations FROM anon, authenticated;`.
   - Table-level `GRANT ALL ON public.order_customizations TO service_role;`.
   - Public direct PostgREST access is completely blocked.
5. Automated Triggers:
   - `trg_personalization_templates_updated_at` $\rightarrow$ `m13_set_updated_at()`
   - `trg_customization_sessions_updated_at` $\rightarrow$ `m13_set_updated_at()`
   - `trg_order_customizations_updated_at` $\rightarrow$ `m13_set_updated_at()`

---

## 6. Staging Rollback Plan & Restrictive Drop Safety

If Decision 4 is authorized and subsequent staging tests detect regression or failure:
1. Execute `migrations/20261112_001_personalization_engine_rollback.sql`.
2. The rollback script implements a multi-tier restrictive safety sequence:
   - Drops all 4 M13 RLS policies explicitly.
   - Drops all 3 M13 automated `updated_at` triggers explicitly.
   - **Explicit Known Foreign Key Severing:** Drops foreign key constraints (`fk_order_customizations_order`, `order_customizations_session_id_fkey`, `customization_sessions_template_id_fkey`, `fk_personalization_templates_product`) explicitly before dropping tables.
   - **Restrictive Table Drops (`DROP TABLE ... RESTRICT`):** All `CASCADE` table drops are completely removed. If any unexpected external view, table, foreign key, or extension depends on M13 tables, PostgreSQL immediately aborts the transaction with an error, preventing unintended schema corruption or data loss.
   - **M13-Owned Function Cleanup:** Drops exclusively `public.m13_set_updated_at() RESTRICT` after verifying 0 external triggers reference it in `pg_catalog`. Shared platform functions remain completely untouched.
3. **Reversibility Scope & Limitations:**
   - Rollback drops the M13 schema objects and deletes data held in those tables.
   - Rollback cannot recover table row data once dropped.
   - Rollback does not alter external tables (`products`, `orders`) or platform functions.
4. Verify clean staging state:
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
     AND table_name IN ('personalization_templates', 'customization_sessions', 'order_customizations');
   -- Must return 0 rows
   ```

---

## 7. Current Authorization Status

**Decision 4 remains strictly NOT AUTHORIZED.** This preflight package provides the complete technical foundation for operator review.
