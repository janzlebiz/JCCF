# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Execution & Rollback Runbook (Staging) (Remediated v2.0)

**Document ID:** `JCCF-M13-STAGE-4-RUNBOOK`  
**Version:** 2.0 (Post-Review Reconciliation)  
**Date:** 13 November 2026 (2026-11-13T01:55:00+08:00)  
**Status:** PROPOSED OPERATOR RUNBOOK — DO NOT EXECUTE WITHOUT D4 APPROVAL  
**Governing Migration Commit SHA:** `cfa4001b37ee8bdeb9030b025fb7e06bc9fab37e`  
**Verified CI Workflow SHA:** `8d02d9b9748ab2c3a47618abc59be509bd6f2420`  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql` (SHA-256: `D24F82E587E31C238317D207ACB377DE5328C4A845FADF651598E25F266CECFE`)  
**Target Rollback:** `migrations/20261112_001_personalization_engine_rollback.sql` (SHA-256: `10721C96BDDDDEBFF2C1D8FAB60FC4D22EFB663B2BDBF191DA9611F3992A7960`)  

---

> [!CAUTION]
> **PROPOSED PROCEDURE ONLY — DO NOT EXECUTE WITHOUT FORMAL D4 OWNER APPROVAL.**  
> Never execute these commands against a production Supabase instance. Staging credentials must remain in local operator session memory and must never be committed to git.

---

## 1. Preconditions & Operator Checklist

Before initiating the migration, the operator must complete the following checklist:

- [ ] **Owner Authorization Confirmed:** Owner has signed Decision 4, explicitly citing migration hash `D24F82E5...` and rollback hash `10721C96...`.
- [ ] **Target Project Verified:** Target project reference `<staging-ref>` is verified as non-production in Supabase dashboard.
- [ ] **Production Boundary Safe:** Target host is confirmed as `db.<staging-ref>.supabase.co`; confirmed distinct from production project.
- [ ] **Operator Privileges:** Operator has admin/postgres connection credentials for staging.
- [ ] **Artifact Integrity Verified:** Local migration and rollback files match published SHA-256 hashes.
- [ ] **Pre-Migration Backup Captured & Verified:** Full logical backup or active PITR snapshot verified.

---

## 2. Step-by-Step Staging Execution Runbook

### Step 1: Pre-Migration Schema Snapshot & Backup (R6 Reconciled)
Capture logical full dump (schema and data) of the staging database:
```bash
# PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
supabase db dump --project-ref <staging-ref> -f staging_pre_m13_backup_$(date +%Y%m%d_%H%M%S).sql
```
*Verification requirement:*  
- Check non-zero file size.
- Compute and log file SHA-256 hash.
- Alternatively, verify that Supabase Point-in-Time Recovery (PITR) or daily automated physical snapshot is healthy in the Supabase Dashboard.

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

-- Check 4: Confirm Supabase PostgREST roles exist (FAIL-CLOSED REQUIREMENT)
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

### Step 4: Post-Migration Validation Queries (R5 Reconciled)
Execute verification queries to confirm catalog state across separate testing blocks:

#### 4.1 Schema & RLS Catalog Verification (Admin Session)
```sql
-- PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
-- 1. Confirm tables created with RLS enabled
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname IN ('personalization_templates', 'customization_sessions', 'order_customizations');

-- 2. Confirm RLS policies created with exact definitions
SELECT tablename, policyname, cmd, roles, qual, with_check 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename IN ('personalization_templates', 'customization_sessions', 'order_customizations');

-- 3. Confirm trigger function and triggers active
SELECT tgname, relname, proname 
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE p.proname = 'm13_set_updated_at';
```

#### 4.2 Role Permission Tests (Isolated Anonymous Session)
Run in a dedicated `psql` session to prevent transaction abort from blocking subsequent checks:
```sql
-- PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
-- Positive Test: anon can read active templates
SET ROLE anon;
SELECT count(*) FROM public.personalization_templates WHERE is_active = true;
RESET ROLE;

-- Negative Test Block (Wrapped in PL/pgSQL to catch expected denial safely):
DO $$
BEGIN
    SET ROLE anon;
    PERFORM * FROM public.customization_sessions;
    RAISE EXCEPTION 'Security Breach: anon was able to query customization_sessions!';
EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'Access safely denied to customization_sessions for anon role.';
END $$;

DO $$
BEGIN
    SET ROLE anon;
    PERFORM * FROM public.order_customizations;
    RAISE EXCEPTION 'Security Breach: anon was able to query order_customizations!';
EXCEPTION WHEN insufficient_privilege THEN
    RESET ROLE;
    RAISE NOTICE 'Access safely denied to order_customizations for anon role.';
END $$;
```

#### 4.3 Service Role Verification (Isolated Backend Session)
```sql
-- PROPOSED - DO NOT EXECUTE WITHOUT D4 APPROVAL
SET ROLE service_role;
SELECT count(*) FROM public.personalization_templates;
SELECT count(*) FROM public.customization_sessions;
SELECT count(*) FROM public.order_customizations;
RESET ROLE;
```

---

## 3. Rollback Procedure & Stop Conditions (R4 Reconciled)

### Stop Conditions:
Trigger immediate rollback if:
1. Role preflight guard fails (`Required Supabase role(s) do not exist`).
2. Migration execution aborts before `COMMIT`.
3. Anonymous role test allows unauthorized query of `customization_sessions` or `order_customizations`.
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
