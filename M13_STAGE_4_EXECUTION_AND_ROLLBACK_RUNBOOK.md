# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Execution & Rollback Runbook (Staging)

**Document ID:** `JCCF-M13-STAGE-4-RUNBOOK`  
**Date:** 13 November 2026 (2026-11-13T01:35:00+08:00)  
**Status:** PROPOSED OPERATOR RUNBOOK — DO NOT EXECUTE WITHOUT D4 APPROVAL  
**Governing Baseline Commit:** `e2c7e84a3febcadd76cda30991e1448451a80dd5`  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql` (SHA-256: `C475ED5C5668179789236F762FC1C04AA9B085F2B7B42E3C08724D0AB62028C9`)  
**Target Rollback:** `migrations/20261112_001_personalization_engine_rollback.sql` (SHA-256: `897FDAB8EC808FB989258C361F712A4D522E2C1BCE80A4460BB2A7131A7F37C6`)  

---

> [!CAUTION]
> **PROPOSED PROCEDURE ONLY — DO NOT EXECUTE WITHOUT FORMAL D4 OWNER APPROVAL.**  
> Never execute these commands against a production Supabase instance. Staging credentials must remain in local operator session memory and must never be committed to git.

---

## 1. Preconditions & Operator Checklist

Before initiating the migration, the operator must complete the following checklist:

- [ ] **Owner Authorization Confirmed:** Owner has signed Decision 4, explicitly citing commit `e2c7e84` and migration hash `C475ED5C...`.
- [ ] **Target Project Verified:** Target project reference `<staging-ref>` is verified as non-production in Supabase dashboard.
- [ ] **Production Boundary Safe:** Target host is confirmed as `db.<staging-ref>.supabase.co`; confirmed distinct from production project.
- [ ] **Operator Privileges:** Operator has admin/postgres connection credentials for staging.
- [ ] **Artifact Integrity Verified:** Local migration and rollback files match published SHA-256 hashes.
- [ ] **Pre-Migration Backup Captured:** Database backup completed, verified, and stored securely.

---

## 2. Step-by-Step Staging Execution Runbook

### Step 1: Pre-Migration Schema Snapshot & Backup
Capture logical backup of the staging database:
```bash
# PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
supabase db dump --project-ref <staging-ref> -f staging_pre_m13_backup_$(date +%Y%m%d_%H%M%S).sql
```
Verify non-zero file size and record backup file SHA-256 hash in execution log.

---

### Step 2: Staging Preflight Checks
Connect via `psql` to `db.<staging-ref>.supabase.co` and run diagnostic preflight queries:
```sql
-- PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
-- Check 1: PostgreSQL Version >= 14
SELECT version();

-- Check 2: Core gen_random_uuid availability
SELECT gen_random_uuid();

-- Check 3: Inspect existing tables in public schema
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('products', 'orders', 'personalization_templates', 'customization_sessions', 'order_customizations');

-- Check 4: Confirm Supabase PostgREST roles exist
SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role');
```
*Stop condition:* If `anon`, `authenticated`, or `service_role` are missing, stop immediately.

---

### Step 3: Migration Execution
Apply the verified migration file inside a controlled transaction:
```bash
# PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
psql -h db.<staging-ref>.supabase.co -U postgres -d postgres \
     -v ON_ERROR_STOP=1 \
     -f migrations/20261112_001_personalization_engine.sql
```
*Verification requirement:* Output must display `COMMIT` and zero error diagnostics.

---

### Step 4: Post-Migration Validation Queries
Execute verification queries to confirm catalog state:
```sql
-- PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
-- 1. Confirm tables created with RLS enabled
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname IN ('personalization_templates', 'customization_sessions', 'order_customizations');

-- 2. Confirm RLS policies created
SELECT tablename, policyname, cmd, roles 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename IN ('personalization_templates', 'customization_sessions', 'order_customizations');

-- 3. Confirm trigger function and triggers active
SELECT tgname, relname, proname 
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE p.proname = 'm13_set_updated_at';

-- 4. Test PostgREST anonymous permissions (Positive & Negative)
-- Positive: anon can SELECT active templates
SET ROLE anon;
SELECT count(*) FROM public.personalization_templates WHERE is_active = true;

-- Negative: anon CANNOT SELECT customization_sessions or order_customizations
-- (Expected error: permission denied for table ...)
SELECT * FROM public.customization_sessions;
SELECT * FROM public.order_customizations;
RESET ROLE;
```

---

## 3. Rollback Procedure & Stop Conditions

### Stop Conditions:
Trigger immediate rollback if:
1. Preflight script raises an unhandled exception or column mismatch error.
2. Migration execution aborts before `COMMIT`.
3. PostgREST anonymous permissions test allows unauthorized query of `customization_sessions` or `order_customizations`.
4. RLS policies fail to reflect in PostgREST cache.

### Rollback Execution:
Execute the restrictive rollback script:
```bash
# PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
psql -h db.<staging-ref>.supabase.co -U postgres -d postgres \
     -v ON_ERROR_STOP=1 \
     -f migrations/20261112_001_personalization_engine_rollback.sql
```

### Rollback Verification:
```sql
-- PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
-- Confirm all 3 M13 tables removed
SELECT count(*) FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('personalization_templates', 'customization_sessions', 'order_customizations');
-- Must return 0.

-- Confirm external tables and shared functions intact
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN ('products', 'orders');
```

---

## 4. Evidence Capture & Reporting Requirements
Upon completion of the staging migration run, the operator must record:
1. Exact timestamp of execution start and completion.
2. Full standard output and standard error logs.
3. Verification query results.
4. Backup artifact SHA-256 hash.
5. Report results to platform owner and halt operations. **DO NOT PROCEED TO PHASE 1 APPLICATION ENGINEERING.**
