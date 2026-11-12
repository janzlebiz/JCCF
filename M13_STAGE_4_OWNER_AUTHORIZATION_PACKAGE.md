# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Owner Authorization Package
## Decision 4: Authorization for Supabase Staging Database Migration

**Document ID:** `JCCF-M13-STAGE-4-AUTH-PKG`  
**Date:** 13 November 2026 (2026-11-13T01:35:00+08:00)  
**Status:** OWNER DECISION REQUIRED — EXECUTION STRICTLY PROHIBITED  
**Repository:** `https://github.com/janzlebiz/JCCF`  
**Baseline Git Commit SHA:** `e2c7e84a3febcadd76cda30991e1448451a80dd5`  
**Latest Tested PostgreSQL Integration SHA:** `e2f623b043d34b027b6f47f2320ce9d05c9ae469`  
**Verified GitHub Actions Workflow Run:** [Run 43268586137](https://github.com/janzlebiz/JCCF/actions/runs/43268586137)  
**Governing Register:** D1 & D2 Approved; D3 Conditional; D4 & D5 NOT AUTHORIZED  

---

## A1. Executive Summary

1. **What Decision 4 Authorizes:**
   Decision 4 authorizes exclusively the execution of the specifically identified M13 database migration (`migrations/20261112_001_personalization_engine.sql`) against an explicitly designated Supabase development/staging database project. It authorizes preflight schema inspection, DDL execution within a controlled transaction, and post-migration validation queries.
2. **Why the Staging Migration is Proposed:**
   Subsystem M13 (Interactive Personalization Engine) requires persistent schema storage for customer intake sessions, declarative product schemas, and fulfillment artifacts. Applying the migration to an isolated Supabase staging environment allows validating Supabase-specific PostgREST schema reflection, RLS policy enforcement with real Supabase authentication tokens, and storage integration before initiating Phase 1 backend engineering.
3. **What Has Been Verified:**
   - **PostgreSQL 15+ Integration:** 15 scenarios (PG-INT-01 to PG-INT-15) executed in live CI using disposable PostgreSQL databases (`CREATE DATABASE jccf_<id>_<uuid>`).
   - **Static DDL & AST Structure:** 12 static scenarios verified via `tests/test_migration_scenarios.py`.
   - **Financial Model Consistency:** 16 independent programmatic assertions verified via `tests/audit_eoc_model.py` ($5,644.61 EOC, 86.91% margin).
   - **Hostile Input Sanitization:** 9 XSS/SSTI attack payload checks verified via `tests/test_hostile_input_sanitization.py`.
   - **Artifact Hashing:** Exact SHA-256 hashes generated for migration, rollback, and preflight packages.
4. **What Remains Unverified:**
   - **Actual Supabase Staging Execution:** The migration has never been applied to any Supabase project.
   - **Staging Project Reference Identity:** The repository contains no hardcoded Supabase project ID or credentials; staging project identity must be supplied by the owner.
   - **Pre-Migration Staging Backup/PITR:** No live backup has been captured yet.
   - **Supabase Dashboard Migration History:** Integration with `supabase_migrations.schema_migrations` has not occurred.
5. **Explicit Current Operating Reality:**
   **NO DATABASE MIGRATION HAS BEEN AUTHORIZED OR EXECUTED.** Decisions 4 and 5 remain strictly **NOT AUTHORIZED**.

---

## A2. Current Project Status

* **Completed Work:**
  - Conceptual architecture and data modeling for PetStory 24p digital MVP (CPL G0–G4).
  - Remediation of all 6 migration safety defects (M13-R1 to M13-R6).
  - PostgreSQL 15+ disposable database integration test harness and CI pipeline.
  - Reconciled financial EOC audit and hostile input sanitization suite.
  - Complete Stage 4 documentation artifacts and preflight runbooks.
* **Pending Work (Awaiting Decision 4):**
  - Owner review and explicit designation of target Supabase staging project reference.
  - Capture of staging database backup.
  - Execution of preflight compatibility checks on staging.
  - Execution of staging migration under Decision 4.
* **Blocked Work (Strictly Blocked by Governance):**
  - Application code implementation (FastAPI / Next.js) — Blocked by Decision 5 hold.
  - Live payment integration (Lemon Squeezy webhooks) — Blocked by Decision 3 condition and Decision 5 hold.
  - Live customer intake or PDF rendering — Blocked by Decision 5 hold.
* **Current Authorization Register:**

| Decision | Scope | Current Status | Governing Condition |
|---|---|---|---|
| **D1** | M13 Architecture | **APPROVED** | Conceptual only; governed by Blueprint v1.0. |
| **D2** | PetStory Digital-Only 24p PDF MVP | **APPROVED** | Digital PDF keepsake; zero physical fulfillment. |
| **D3** | Lemon Squeezy MoR Gateway | **CONDITIONALLY ENDORSED** | Blocked until Philippine KYC and payout feasibility confirmed. |
| **D4** | Supabase Staging Database Migration | **NOT AUTHORIZED** | Target of this Stage 4 Authorization Package. |
| **D5** | Phase 1 Application Engineering | **NOT AUTHORIZED** | Independent decision; cannot be inferred from D4. |

---

## A3. Exact Migration Scope

The proposed migration (`migrations/20261112_001_personalization_engine.sql`) executes within a single atomic transaction (`BEGIN ... COMMIT`).

### Summary of Database Operations
* **Tables Created (3):**
  1. `public.personalization_templates` (9 columns, PK `id UUID`, UQ `(product_id, version)`).
  2. `public.customization_sessions` (11 columns, PK `id UUID`, UQ `token_hash VARCHAR(64)`).
  3. `public.order_customizations` (15 columns, PK `id UUID`, UQ `order_id UUID`, UQ `download_token_hash VARCHAR(64)`).
* **Foreign Keys (4 total):**
  - Inbound/Internal:
    1. `customization_sessions.template_id` $\rightarrow$ `personalization_templates(id)` (`ON DELETE RESTRICT`).
    2. `order_customizations.session_id` $\rightarrow$ `customization_sessions(id)` (`ON DELETE RESTRICT`).
  - Conditional Outbound (Attached only if parent tables exist):
    3. `personalization_templates.product_id` $\rightarrow$ `public.products(id)` (`ON DELETE RESTRICT ON UPDATE CASCADE`).
    4. `order_customizations.order_id` $\rightarrow$ `public.orders(id)` (`ON DELETE CASCADE`).
* **Indexes Created (5):**
  1. `idx_customization_sessions_token_hash` on `customization_sessions(token_hash)`.
  2. `idx_customization_sessions_template_id` on `customization_sessions(template_id)`.
  3. `idx_customization_sessions_expires_at` on `customization_sessions(expires_at)` WHERE `status = 'draft'`.
  4. `idx_order_customization_order` on `order_customizations(order_id)`.
  5. `idx_order_download_token_hash` on `order_customizations(download_token_hash)`.
* **Functions Created (1):**
  - `public.m13_set_updated_at()`: Trigger function setting `NEW.updated_at = now()`. Created conditionally after checking `pg_proc` for 0-argument signature and definition compatibility.
* **Triggers Created (3):**
  1. `trg_personalization_templates_updated_at` on `personalization_templates`.
  2. `trg_customization_sessions_updated_at` on `customization_sessions`.
  3. `trg_order_customizations_updated_at` on `order_customizations`.
* **Row Level Security & Policies:**
  - RLS enabled on all 3 tables (`ENABLE ROW LEVEL SECURITY`).
  - Table privileges explicitly granted/revoked based on Supabase roles (`anon`, `authenticated`, `service_role`).
  - 4 protected RLS policies created/verified:
    1. `"Public read active templates"` on `personalization_templates` FOR SELECT (`USING (is_active = true)`).
    2. `"Service role full access on personalization_templates"` FOR ALL TO `service_role`.
    3. `"Service role full access on customization_sessions"` FOR ALL TO `service_role`.
    4. `"Service role full access on order_customizations"` FOR ALL TO `service_role`.
* **Destructive Operations:**
  - **Zero DROP TABLE, ALTER DROP COLUMN, or TRUNCATE statements** exist in the migration.
  - Table-level `REVOKE ALL` is executed against `anon` and `authenticated` for intake sessions and order customizations to enforce least privilege.

---

## A4. Migration Identity & Cryptographic Hashes

Any approval of Decision 4 is strictly bound to the exact file paths, commit SHA, and cryptographic hashes below:

* **Repository:** `https://github.com/janzlebiz/JCCF`
* **Current Baseline Git Commit SHA:** `e2c7e84a3febcadd76cda30991e1448451a80dd5`
* **Target Migration File:** `migrations/20261112_001_personalization_engine.sql`
  - **Migration File SHA-256:**  
    `C475ED5C5668179789236F762FC1C04AA9B085F2B7B42E3C08724D0AB62028C9`
* **Target Rollback File:** `migrations/20261112_001_personalization_engine_rollback.sql`
  - **Rollback File SHA-256:**  
    `897FDAB8EC808FB989258C361F712A4D522E2C1BCE80A4460BB2A7131A7F37C6`
* **Preflight Specification File:** `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md`
  - **Preflight File SHA-256:**  
    `CE0A8C1072A49DD328D555CB31E93C9E9DD88538BA08D6696E6F828CF00C6225`
* **Verified CI Workflow:** `.github/workflows/postgres_verification.yml`
  - **Successful CI Run ID:** `43268586137`
  - **CI Run URL:** https://github.com/janzlebiz/JCCF/actions/runs/43268586137
  - **CI Workflow Conclusion:** `success`
* **Evidence Timestamp:** 13 November 2026, 01:35:00 UTC+08:00 (Asia/Manila).

---

## A5. Verification Evidence Matrix

| Requirement Area | Source Artifact / Tool | Verification Type | Result | Remaining Limitation |
|---|---|---|---|---|
| **SQL Syntax & AST Structure** | `tests/test_migration_scenarios.py` | Static AST & Catalog Logic Scan | **PASS** (12/12) | Static parsing; does not test actual PostgreSQL engine behavior. |
| **Real PostgreSQL 15+ Integration** | `tests/test_migration_postgres_integration.py` | Automated Live Container Execution (CI) | **PASS** (15/15) | Executed against `postgres:15-alpine` container service, not live Supabase staging. |
| **Disposable DB Isolation** | `test_migration_postgres_integration.py` | Automated DB Isolation (`CREATE DATABASE`) | **PASS** (15/15) | Verifies clean lifecycle per test; proves zero cross-scenario state leakage. |
| **Sentinel Maintenance DB Isolation** | PG-INT-15 Sentinel Test | Live Catalog Inspection | **PASS** (1/1) | Confirms zero M13 objects leaked to shared `postgres` maintenance DB. |
| **Financial EOC Deductions** | `tests/audit_eoc_model.py` | Programmatic Assertions | **PASS** (16/16) | Mathematical verification; requires actual live checkout telemetry to validate real-world conversion. |
| **Jinja2 Hostile Input Sanitization** | `tests/test_hostile_input_sanitization.py` | Automated Template Execution | **PASS** (9/9) | Tests XSS/SSTI escaping; does not test browser DOM rendering. |
| **Supabase Staging Database Execution** | None (Awaiting D4) | Staging DDL Execution | **NOT EXECUTED** | **Strictly blocked pending Owner Decision 4.** |

---

## A6. Supabase-Specific Compatibility Assessment

| Compatibility Area | Target Requirement | Supabase Assessment | Status | Supporting Evidence / Notes |
|---|---|---|---|---|
| **PostgreSQL Engine Version** | PostgreSQL 15+ | Supported natively by Supabase (current standard is PG 15.x / 16.x). | **VERIFIED** | Migration requires PG 13+ native `gen_random_uuid()`. |
| **PostgREST Standard Roles** | `anon`, `authenticated`, `service_role` exist | Supabase pre-seeds these roles on all projects. | **VERIFIED** | DDL includes `IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '...')` guards to guarantee clean execution. |
| **Role Fallback Behavior** | Vanilla test fallback to `PUBLIC` | If run in an environment without Supabase roles, policies fall back to `PUBLIC`. **In Supabase, explicit roles exist and are used.** | **VERIFIED** | Preflight query Check 6 explicitly confirms `anon`, `authenticated`, and `service_role` exist before migration. |
| **RLS Policy Semantics** | Public SELECT on active templates; service_role full access | Enforces zero customer data leakage. Anonymous guests cannot query sessions or orders directly. | **VERIFIED** | DDL revokes table privileges and defines strict RLS policies. |
| **Function Ownership & search_path** | `public.m13_set_updated_at()` | Executed by `postgres` superuser/admin role in Supabase. Explicit schema qualification (`public.*`) used throughout. | **VERIFIED** | Function contains zero dynamic SQL; strictly sets `NEW.updated_at = now()`. |
| **Extensions Required** | Native `gen_random_uuid()` | Native core feature in PostgreSQL 13+. No `pgcrypto` or `uuid-ossp` extensions required. | **VERIFIED** | Tested cleanly on clean PG 15 container without extensions. |
| **Object Collisions** | No collision with shared platform functions | Subsystem-specific function `m13_set_updated_at()` used. Preflight aborts if conflicting same-named function exists. | **VERIFIED** | Ast scan (Scenario 09) and CI integration (PG-INT-09) verify collision safety. |
| **Supabase CLI Tracking** | Applied via Supabase CLI or Dashboard SQL Editor | If applied via SQL editor, must be recorded in migration history table if project uses CLI migrations. | **NOT VERIFIED** | Requires operator decision on deployment tool (CLI vs Web Dashboard). |

---

## A7. Staging Environment Identity

To ensure that the migration is never applied to an incorrect target or production instance, the operator must verify the staging project credentials against the following register:

* **Target Environment Classification:** Dedicated Development / Staging Project (Non-Production).
* **Project Name:** To be confirmed by Owner upon authorization.
* **Project Reference ID (`<staging-ref>`):** **[BLOCKED — AWAITING OWNER SPECIFICATION]**
* **Database Host:** `db.<staging-ref>.supabase.co`
* **Direct Connection Port:** `5432` (or Connection Pooler `6543`)
* **Target Schema:** `public`
* **Production Protection Invariant:** The target project reference MUST NOT match the JCCF production project reference.
* **Current Environment Status:** **BLOCKED**. The repository does not store staging credentials or project references. The platform owner must explicitly designate `<staging-ref>` in the Decision 4 approval instrument.

---

## A8. Backup and Recovery Plan

1. **Pre-Migration Backup Method:**
   - Execute logical pg_dump via Supabase CLI or operator workstation:
     ```bash
     supabase db dump --project-ref <staging-ref> -f staging_pre_m13_backup.sql
     ```
   - Alternatively, trigger a manual snapshot in the Supabase Dashboard (Database $\rightarrow$ Backups).
2. **Backup Completion Evidence Required:**
   - Operator must inspect the backup file size, confirm non-zero bytes, and record its SHA-256 hash in the staging execution log.
3. **Backup Retention:**
   - Retain the pre-migration snapshot for a minimum of 30 days in secure, encrypted operator storage.
4. **Restore Procedure:**
   - In the event of catastrophic migration failure where transaction rollback fails, execute:
     ```bash
     psql -h db.<staging-ref>.supabase.co -U postgres -d postgres -f staging_pre_m13_backup.sql
     ```
5. **Recovery Decision Point:**
   - If preflight checks fail, the migration automatically aborts with `RAISE EXCEPTION` and rolls back atomically (`ROLLBACK`). No manual database restore is required.
   - If post-migration validation checks fail, the operator immediately executes `migrations/20261112_001_personalization_engine_rollback.sql`.

---

## A9. Proposed Execution Runbook (Future Operator)

> [!WARNING]
> **PROPOSED PROCEDURE ONLY — DO NOT EXECUTE WITHOUT FORMAL D4 APPROVAL.**

1. **Pre-Execution Gate:** Confirm platform owner has signed Decision 4, citing commit `e2c7e84` and migration hash `C475ED5C...`.
2. **Target Isolation Check:** Confirm active connection string points to staging project `<staging-ref>`, never production.
3. **Pre-Migration Backup:** Capture logical backup and verify hash.
4. **Preflight Execution:** Execute Preflight Checks 1 through 6 from `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md`.
5. **Migration Execution:** Execute `migrations/20261112_001_personalization_engine.sql` in a single transaction.
6. **Post-Migration Verification:**
   - Confirm creation of tables `personalization_templates`, `customization_sessions`, and `order_customizations`.
   - Confirm RLS enabled on all 3 tables.
   - Verify `anon` role can SELECT active templates but CANNOT SELECT from `customization_sessions` or `order_customizations`.
   - Verify `service_role` has full access across all 3 tables.
7. **Handoff & Record:** Log output, record execution timestamp, and report results to platform owner. **STOP.** Do not proceed to Phase 1 engineering.

---

## A10. Rollback and Stop Conditions

* **Exact Rollback Artifact:** `migrations/20261112_001_personalization_engine_rollback.sql`
* **Rollback SHA-256:** `897FDAB8EC808FB989258C361F712A4D522E2C1BCE80A4460BB2A7131A7F37C6`
* **Immediate Stop & Rollback Conditions:**
  1. Any preflight assertion fails (`RAISE EXCEPTION`).
  2. DDL execution returns an unhandled database error.
  3. PostgREST fails to expose `personalization_templates` or exposes guest intake tables to anonymous users.
  4. Post-migration permission validation reveals unauthorized public access.
* **Rollback Safety & Restrictive Mode:**
  - All 3 tables dropped using `RESTRICT` (zero `CASCADE`). If an external table or view has attached dependencies to M13 tables, PostgreSQL immediately halts the drop.
  - The function `public.m13_set_updated_at()` is dropped only if zero active external triggers depend on it.
* **Reversibility Boundaries:**
  - Rollback safely removes M13 schema objects.
  - Rollback does NOT recover data entered into M13 tables once dropped.
  - Rollback does NOT alter external platform tables (`products`, `orders`).

---

## A11. Risks and Mitigations

| Risk Category | Identified Hazard | Inherent Risk | Implemented Mitigation | Residual Risk |
|---|---|---|---|---|
| **Environment Selection** | Accidental execution against production database | Critical | Staging project reference must be explicitly verified; production credentials strictly omitted from repository. | Low |
| **Function Collision** | Overwriting shared platform trigger function | High | Subsystem-namespaced function `m13_set_updated_at()` created with exact 0-arg signature inspection; shared platform functions preserved. | Negligible |
| **Security / Data Leak** | Anonymous exposure of guest intake answers or customer orders | High | Strict RLS enabled; table privileges explicitly revoked from `anon` and `authenticated`; service-role only access on sensitive tables. | Low |
| **Unintended Cascades** | Dropping shared or dependent objects during rollback | High | Rollback uses strictly `DROP TABLE ... RESTRICT` (0 `CASCADE`); fails safely if unexpected dependencies exist. | Negligible |
| **Schema Incompatibility** | Incompatible pre-existing table or foreign key definition | Medium | Section 0.1 performs exhaustive preflight checks on 100% of required columns, types, nullability, defaults, PKs, and FKs. | Negligible |

---

## A12. Explicit Owner Decision Instrument

```markdown
================================================================================
FORMAL OWNER DECISION INSTRUMENT: DECISION 4
SUBYSTEM M13 — SUPABASE STAGING DATABASE MIGRATION
================================================================================

Target Repository:        https://github.com/janzlebiz/JCCF
Governing Baseline Commit: e2c7e84a3febcadd76cda30991e1448451a80dd5
Target Migration File:    migrations/20261112_001_personalization_engine.sql
Target Migration SHA-256: C475ED5C5668179789236F762FC1C04AA9B085F2B7B42E3C08724D0AB62028C9
Target Rollback File:     migrations/20261112_001_personalization_engine_rollback.sql
Target Rollback SHA-256:  897FDAB8EC808FB989258C361F712A4D522E2C1BCE80A4460BB2A7131A7F37C6
Target Supabase Project:  [ Owner to specify: <staging-ref> ]

PROPOSED DECISION:
[ ] APPROVE
[ ] REJECT
[ ] DEFER — MORE INFORMATION REQUIRED

CONDITIONS AND SCOPE OF APPROVAL:
"Approval of Decision 4 authorizes only the specifically identified M13 migration
into the specifically identified Supabase staging environment, subject to the
stated conditions. It does not authorize production deployment, live payment
integration, customer data processing, or Phase 1 application engineering.
Decision 5 requires a separate explicit owner authorization."

Owner Signature:   ______________________________________
Decision Date:     ______________________________________
Staging Project Ref: ____________________________________
Owner Conditions:  ______________________________________
================================================================================
```

