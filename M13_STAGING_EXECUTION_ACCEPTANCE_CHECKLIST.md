# JCCF Subsystem M13 — Staging Execution Acceptance Checklist
**Document Version:** 2.0  
**Status:** Stage B Pre-Execution Operational Gate (LIVE DDL NOT YET EXECUTED)  
**Governing Migration Commit:** `e624e95f74932441dfee90cad7a9cb4544f64d6d` (`migrations/20261112_001_personalization_engine.sql`)  
**Governing Rollback Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4` (`migrations/20261112_001_personalization_engine_rollback.sql`)  
**Integration Test Baseline Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4` (`tests/test_migration_postgres_integration.py`, 26/26 PASS on PG 17.11)  
**Authorization Status:**
* **D4 Stage A:** **CONDITIONAL AUTHORIZATION GRANTED** (historical record preserved).
* **D4 Stage B / Production Transition:** **SUPERSEDED BY PRODUCTION MIGRATION READINESS** (`ammsjbcpbspisbyynaga` confirmed as JCCF Production Supabase Project by owner; staging/production separation `E1.2` no longer applies; governed by `M13_PRODUCTION_MIGRATION_READINESS.md` & `M13_PRODUCTION_CHANGE_PLAN.md`; live D4 migration DDL NOT YET EXECUTED; live D4 rollback SQL NOT EXECUTED).
* **D5 Phase 1 Engineering:** **AUTHORIZED SEPARATELY** within approved scope (D5 live Supabase integration NOT AUTHORIZED until D4 migration is completed and verified; D5 deployment NOT AUTHORIZED).

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
| **E1.1** | Project Identity | Supabase Staging Reference ID matches authorized project | [x] | `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`) |
| **E1.2** | Environment Isolation | Verified NOT targeting production database or client URLs | [ ] **NOT VERIFIED** | `npx supabase projects list` shows `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, created `2026-11-12T15:41:53Z`) is the sole JCCF project in org `fpyqttksvcgqjuuipfei` (other project `jgpigkeekfuawbyilycq` is `Agila-Hub-BEEC`). No `.env*` or deployed app config exists in repo. **Operator must explicitly confirm non-production/staging designation before release.** |
| **E1.3** | Engine Version | Primary target: PostgreSQL `17.11` (PG 15 CI retained as secondary regression baseline) | [x] | `PostgreSQL 17.11 on aarch64-unknown-linux-gnu` |
| **E1.4** | Required Roles | `anon`, `authenticated`, `service_role` exist in `pg_roles` | [x] | Role Query Count: `3` (PF-06) |
| **E1.5** | Operator Role | Migration operator executes as `postgres` or administrative role | [x] | Current User: `postgres` |
| **E1.6** | Schema Isolation | Target schema is strictly `public`; no cross-schema pollution | [x] | Schema: `public` |

---

## 3. E2: Pre-Execution Backup & Recovery Verification

> [!NOTE]
> **Temporary Pre-Revenue Recovery Mitigation:** Supabase Free plan does not provide managed PITR. The owner-approved temporary mitigation is a **local logical database backup** captured over IPv4 Session Pooler and verified via local PostgreSQL 17.11 restoration (`M13_D4_LOCAL_BACKUP_REPORT.md` v1.1).
> **Backup Limitations:** This is a local logical database backup only. Supabase-managed internal schemas and platform configuration are excluded. The source project currently has 0 public application tables, 0 application data rows, and no Auth users, Storage buckets, or Storage objects were present at verification time. Vanilla PostgreSQL restoration cannot reproduce all Supabase-managed platform components (`supabase_vault`, `extensions.pgrst_*`/`grant_pg_*` event triggers). This is a temporary pre-revenue risk mitigation, not an enterprise disaster-recovery solution.

| Check ID | Verification Item | Target Standard | Verified (Y/N) | Evidence Reference / Output |
|---|---|---|---|---|
| **E2.1** | Logical Roles & Schema Dump | `pg_dumpall --roles-only` and `pg_dump --schema-only` stored outside Git | [x] | `D:\JCCF_SECURE_BACKUPS\M13\staging_backup_ammsjbcpbspisbyynaga_20261113_022827_UTC\` (`roles.sql` `6301`B, `schema.sql` `39515`B) |
| **E2.2** | Logical Data Dump | `pg_dump --data-only` executed (`0` app rows; fresh DB) | [x] | `data.sql` (`4750`B, `2026-11-13T02:28:27Z`–`02:29:16Z`) |
| **E2.3** | Local Restore Verification | Restored into disposable local PG 17.11 (`jccf_restore_verify`, destroyed after check) | [x] | `roles=0`, `schema=0`, `data=0`; roles, `public.rls_auto_enable`, `ensure_rls` verified |
| **E2.4** | Backup Checksums | SHA-256 hashes calculated and revalidated in `checksums.sha256` | [x] | `roles.sql`: `A3C83C6A...`, `schema.sql`: `792F534C...`, `data.sql`: `3213414D...` |
| **E2.5** | Recovery Owner | Designee identified with authority to trigger disaster restore | [x] | Project Owner / Migration Operator |

---

## 4. E3: Release Artifact & Integrity Verification

| Check ID | Verification Item | Target Standard | Verified (Y/N) | Evidence Reference / Output |
|---|---|---|---|---|
| **E3.1** | Git Commit Baseline | Migration governing commit `e624e95` (blob `679f5a80`, identical at `f9a4eb3` & HEAD); Rollback & Integration suite governing commit `f9a4eb3` (blobs `e7b1c60f` & `8edb6730`, identical at HEAD); Preflight package `fb40bf5` | [ ] **VERIFY AT EXECUTION** | Operator must verify exact checkout commit, branch `main`, and hashes immediately before execution |
| **E3.2** | Migration SQL Hash | SHA-256 matches `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E` | [x] | Hash Verified |
| **E3.3** | Rollback SQL Hash | SHA-256 matches `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4` | [x] | Hash Verified |
| **E3.4** | Working Tree State | Local working tree is clean with zero uncommitted changes | [x] | `git status` clean |
| **E3.5** | Runbook Version | Operator following `M13_STAGE_4_EXECUTION_AND_ROLLBACK_RUNBOOK.md` | [x] | Confirmed |

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

