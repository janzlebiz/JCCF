# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Staging Migration Preflight, Verification & Rollback Package (v2.0)

**Document ID:** `JCCF-PKG-MIG-001`  
**Version:** 2.0 (Namespaced Function, Preflight Compatibility Guards, & Restrictive Rollback)  
**Date:** 13 November 2026  
**Status:** Preflight Specification & Rollback Procedure (Execution NOT AUTHORIZED)  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql`  
**Rollback Script:** `migrations/20261112_001_personalization_engine_rollback.sql`  
**Governing State:** Decision 4 Not Authorized (Held at Phase Boundary)  

---

## 1. Executive Summary

This preflight package specifies the technical preconditions, schema compatibility checks, and rollback safety mechanisms for **Decision 4 (Development / Staging Database Migration)**.

Key safety remediations in this version:
1. **Namespaced Trigger Function:** Migration uses `public.m13_set_updated_at()`, eliminating silent collisions or overwrites of existing shared platform functions.
2. **Existing-Table Compatibility Preflight:** Explicitly verifies column existence and data types for pre-existing tables before proceeding, rather than blindly relying on `CREATE TABLE IF NOT EXISTS`.
3. **Fully-Scoped Foreign Key Detection:** Scopes constraint-existence checks to `table_schema`, `table_name`, AND `constraint_name`.
4. **Restrictive Rollback Drops:** Rollback applies `DROP TABLE ... RESTRICT` (zero `CASCADE`), aborting cleanly if unexpected external dependencies exist.

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

-- PREFLIGHT CHECK 4: Existing Table Compatibility Guard (if M13 tables already exist)
-- Detect incompatible columns, types, or missing critical fields before applying DDL
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('personalization_templates', 'customization_sessions', 'order_customizations')
ORDER BY table_name, ordinal_position;

-- PREFLIGHT CHECK 5: Verify foreign key constraint scope on target tables
SELECT constraint_name, table_schema, table_name
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name IN ('personalization_templates', 'order_customizations')
  AND constraint_type = 'FOREIGN KEY';

-- PREFLIGHT CHECK 6: Check standard PostgREST roles exist
SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role');
```

### Preflight Compatibility Invariants
* **UUID Generation:** Native `gen_random_uuid()` is confirmed operational. `pgcrypto` is not required.
* **Compatibility Guard:** If `personalization_templates`, `customization_sessions`, or `order_customizations` already exist on the staging database, the migration runs inline PL/pgSQL guards checking required column types (e.g., `schema_definition JSONB`, `token_hash VARCHAR`, `download_token_hash VARCHAR`) and aborts with `RAISE EXCEPTION` if schema drift is detected.
* **Strict Foreign Key Scoping:** Checks for `fk_personalization_templates_product` and `fk_order_customizations_order` filter strictly by `table_name` to prevent collisions with unrelated constraints on other tables.
* **Trigger Isolation:** Triggers execute `public.m13_set_updated_at()`, preserving shared functions untouched.

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
   - `public.m13_set_updated_at()`: Dedicated M13 trigger function.
2. `public.personalization_templates`:
   - Table-level `GRANT SELECT ON public.personalization_templates TO anon, authenticated;`.
   - RLS Policy: `USING (is_active = true)`.
3. `public.customization_sessions`:
   - Table-level `REVOKE ALL ON public.customization_sessions FROM anon, authenticated;`.
   - Table-level `GRANT ALL ON public.customization_sessions TO service_role;`.
   - Public direct PostgREST access is completely blocked (HTTP 401/403).
4. `public.order_customizations`:
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
   - **M13-Owned Function Cleanup:** Drops exclusively `public.m13_set_updated_at() RESTRICT`. Shared platform functions remain completely untouched.
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
