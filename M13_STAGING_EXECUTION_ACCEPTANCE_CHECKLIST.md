# JCCF Subsystem M13 — Staging Execution Acceptance Checklist
**Document Version:** 1.0  
**Status:** Future Staging Operational Gate (NOT TO BE EXECUTED PRIOR TO D4 AUTHORIZATION)  
**Governing Migration Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Governing Rollback Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Authorization Status:** Decision 4 (D4) and Decision 5 (D5) remain **NOT AUTHORIZED**.

---

## 1. Operating Instructions & Gate Enforcement

This checklist is an authoritative operational gate designed to enforce the **Two-Stage Decision Model (Finding TC-06)**:
* **Stage A (Owner Decision):** Project Owner grants *Conditional Authorization* for a controlled staging migration window.
* **Stage B (Pre-Execution Release):** The authorized database administrator or migration operator independently verifies all mandatory preflight conditions immediately prior to running DDL.

> [!IMPORTANT]
> **Conditional authorization of D4 is permission to proceed toward a controlled staging migration, subject to the defined pre-execution release conditions. It is not automatic permission to execute SQL. The operator must separately confirm that all mandatory execution conditions are satisfied before any DDL is run.**

**Strict Stop Condition:** If any check in Sections E1 through E5 receives a "NO" or fails to produce verifiable evidence, migration execution must be **immediately aborted**.

---

## 2. E1: Staging Target & Environment Verification

| Check ID | Verification Item | Target Standard | Verified (Y/N) | Evidence Reference / Output |
|---|---|---|---|---|
| **E1.1** | Project Identity | Supabase Staging Reference ID matches authorized project | [ ] | Staging Project Ref: `________________` |
| **E1.2** | Environment Isolation | Verified NOT targeting production database or client URLs | [ ] | Confirmed Staging URL |
| **E1.3** | Engine Version | PostgreSQL version is 15.x or 16.x (`SELECT version();`) | [ ] | PostgreSQL Version: `________________` |
| **E1.4** | Required Roles | `anon`, `authenticated`, `service_role` exist in `pg_roles` | [ ] | Role Query Count: `3` |
| **E1.5** | Operator Role | Migration operator executes as `postgres` or administrative role | [ ] | Current User: `postgres` |
| **E1.6** | Schema Isolation | Target schema is strictly `public`; no cross-schema pollution | [ ] | Schema: `public` |

---

## 3. E2: Pre-Execution Backup & Recovery Verification

| Check ID | Verification Item | Target Standard | Verified (Y/N) | Evidence Reference / Output |
|---|---|---|---|---|
| **E2.1** | Logical Schema Dump | `pg_dump --schema-only` executed and stored securely | [ ] | File: `staging_pre_m13_schema.sql` |
| **E2.2** | Logical Data Dump | `pg_dump --data-only` executed for pre-existing tables | [ ] | File: `staging_pre_m13_data.dump` |
| **E2.3** | PITR Point Captured | Exact UTC timestamp recorded for Point-in-Time Recovery | [ ] | UTC Timestamp: `____________________` |
| **E2.4** | Backup Checksum | SHA-256 hash calculated and logged for backup archives | [ ] | Backup Hash: `______________________` |
| **E2.5** | Recovery Owner | Designee identified with authority to trigger disaster restore | [ ] | Recovery Lead: `____________________` |

---

## 4. E3: Release Artifact & Integrity Verification

| Check ID | Verification Item | Target Standard | Verified (Y/N) | Evidence Reference / Output |
|---|---|---|---|---|
| **E3.1** | Git Commit Baseline | Working repository checked out to commit `f9a4eb3` | [ ] | `git rev-parse HEAD` = `f9a4eb3` |
| **E3.2** | Migration SQL Hash | SHA-256 matches `9D6579BC93842C57E3EA03C93F3802CF...` | [ ] | Hash Verified: [ ] |
| **E3.3** | Rollback SQL Hash | SHA-256 matches `73725DF9716772A355EC159117F2DD68...` | [ ] | Hash Verified: [ ] |
| **E3.4** | Working Tree State | Local working tree is clean with zero uncommitted changes | [ ] | `git status` clean |
| **E3.5** | Runbook Version | Operator following `M13_STAGE_4_EXECUTION_AND_ROLLBACK_RUNBOOK.md` | [ ] | Version 4.0 confirmed |

---

## 5. E4: Live Staging Preflight Package Execution

Execute all 11 diagnostic queries in `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md`:

| Query ID | Target Inspection | Pass Condition | Result |
|---|---|---|---|
| **Q1** | Role Availability | Returns all 3 roles: `anon`, `authenticated`, `service_role` | [ ] PASS / [ ] FAIL |
| **Q2** | Table Collision | `personalization_templates` does not exist or has 100% matching schema | [ ] PASS / [ ] FAIL |
| **Q3** | Table Collision | `customization_sessions` does not exist or has 100% matching schema | [ ] PASS / [ ] FAIL |
| **Q4** | Table Collision | `order_customizations` does not exist or has **all 15 columns** matching | [ ] PASS / [ ] FAIL |
| **Q5** | Function Collision | `m13_set_updated_at` does not exist or has exact compatible definition | [ ] PASS / [ ] FAIL |
| **Q6** | Trigger Collision | Triggers do not collide with unrelated procedures | [ ] PASS / [ ] FAIL |
| **Q7** | RLS Policy Collision | Policies do not collide with conflicting definitions | [ ] PASS / [ ] FAIL |
| **Q8** | Extension Readiness | `gen_random_uuid()` executes cleanly in SQL | [ ] PASS / [ ] FAIL |
| **Q9** | Foreign Key Target | `public.products` existence assessed (optional reference) | [ ] PASS / [ ] FAIL |
| **Q10**| Search Path Check | Current `search_path` resolves to `public` cleanly | [ ] PASS / [ ] FAIL |
| **Q11**| Overall Assessment | All 10 preflight gates evaluated with ZERO errors | [ ] PASS / [ ] FAIL |

---

## 6. E5: Formal Execution Authorization Sign-Off

```
[ ] Explicit Owner Approval: Project Owner signed Decision 4 instrument in M13_DECISION_4_FINAL_PACKAGE.md
[ ] Approved Execution Window: Date/Time: ____________________________________
[ ] Migration Operator Name: _________________________________________________
[ ] Emergency Rollback Authority: ____________________________________________
[ ] Operator Signature / Authorization Acknowledgment: _______________________
```

---

## 7. E6: Post-Migration Acceptance & Health Verification

Immediately upon applying `20261112_001_personalization_engine.sql` in staging, execute these verification checks:

| Check ID | Verification Item | Target SQL / Command | Acceptance Criteria |
|---|---|---|---|
| **E6.1** | Table Creation | `SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('personalization_templates', 'customization_sessions', 'order_customizations');` | Returns exactly `3` |
| **E6.2** | Column Count (Orders) | `SELECT count(*) FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_customizations';` | Returns exactly `15` |
| **E6.3** | Function Existence | `SELECT proname, pronargs, prorettype::regtype FROM pg_proc WHERE proname = 'm13_set_updated_at';` | Returns `m13_set_updated_at`, `0`, `trigger` |
| **E6.4** | Trigger Attachments | `SELECT count(*) FROM information_schema.triggers WHERE trigger_name IN ('trg_templates_updated_at', 'trg_sessions_updated_at', 'trg_orders_updated_at');` | Returns exactly `3` |
| **E6.5** | Forced RLS Active | `SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname IN ('personalization_templates', 'customization_sessions', 'order_customizations');` | All 3 rows show `relrowsecurity = true` AND `relforcerowsecurity = true` |
| **E6.6** | Policy Count & Roles | `SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename LIKE '%customization%' OR tablename = 'personalization_templates';` | Returns exactly `4` policies matching approved names |
| **E6.7** | Anonymous Access Check | `SET ROLE anon; SELECT count(*) FROM public.personalization_templates WHERE is_active = true; RESET ROLE;` | Executes successfully without permission error |
| **E6.8** | Anon Denial Check | `SET ROLE anon; SELECT * FROM public.customization_sessions; RESET ROLE;` | Fails with permission denied or returns 0 rows |
| **E6.9** | PostgREST Cache Reload| `NOTIFY pgrst, 'reload schema';` | Executes without error |
| **E6.10**| Final Sign-Off | Document post-migration evidence in `M13_STAGE_4_EVIDENCE_REGISTER.md` | Staging Verification: PASSED |

