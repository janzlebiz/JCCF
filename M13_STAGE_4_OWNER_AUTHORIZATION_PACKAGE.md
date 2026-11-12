# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Owner Authorization Package (Remediated v4.0)
## Decision 4: Authorization for Supabase Staging Database Migration

**Document ID:** `JCCF-M13-STAGE-4-AUTH-PKG`  
**Version:** 4.0 (Final Targeted Refinements Baseline — F6 & F7 Resolved)  
**Date:** 13 November 2026 (2026-11-13T02:18:00+08:00)  
**Status:** OWNER DECISION REQUIRED — EXECUTION STRICTLY PROHIBITED  
**Repository:** `https://github.com/janzlebiz/JCCF`  
**Target Migration Commit SHA:** `e624e95f74932441dfee90cad7a9cb4544f64d6d`  
**Target Rollback Commit SHA:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Verified CI Workflow Run SHA:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Verified GitHub Actions Workflow Run:** [Run 43277854888](https://github.com/janzlebiz/JCCF/actions/runs/43277854888) (`success`)  
**Governing Register:** D1 & D2 Approved; D3 Conditional; D4 & D5 NOT AUTHORIZED  

---

## A1. Executive Summary

1. **What Decision 4 Authorizes:**  
   Decision 4 authorizes exclusively the execution of the specifically identified M13 database migration (`migrations/20261112_001_personalization_engine.sql`) against an explicitly designated Supabase development/staging database project. It authorizes preflight schema inspection, DDL execution within a controlled transaction, and post-migration validation queries. It does NOT authorize production deployment, live payment integration, customer data processing, or Phase 1 application engineering.
2. **Why the Staging Migration is Proposed:**  
   Subsystem M13 (Interactive Personalization Engine) requires persistent schema storage for customer intake sessions, declarative product schemas, and fulfillment artifacts. Applying the migration to an isolated Supabase staging environment allows validating Supabase-specific PostgREST schema reflection, RLS policy enforcement with real Supabase authentication tokens, and storage integration before initiating Phase 1 backend engineering.
3. **What Has Been Verified:**  
   - **PostgreSQL 15+ Integration (Disposable DB Isolation):** **26 scenarios** (PG-INT-01 to PG-INT-26) executed in live CI using disposable PostgreSQL databases (`CREATE DATABASE jccf_<id>_<uuid>`).
   - **Static DDL & AST Structure:** 12 static scenarios verified via `tests/test_migration_scenarios.py`.
   - **Financial Model Consistency:** 16 independent programmatic assertions verified via `tests/audit_eoc_model.py` ($5,644.61 EOC, 86.91% margin).
   - **Hostile Input Sanitization:** 9 XSS/SSTI attack payload checks verified via `tests/test_hostile_input_sanitization.py`.
   - **Artifact Hashing:** Exact SHA-256 hashes generated for migration, rollback, and preflight packages.
4. **What Remains Unverified:**  
   - **Actual Supabase Staging Execution:** The migration has never been applied to any Supabase project (**NOT VERIFIED ON SUPABASE**).
   - **Staging Project Reference Identity:** The repository contains no hardcoded Supabase project ID or credentials; staging project identity must be supplied by the owner.
   - **Pre-Migration Staging Backup/PITR:** No live staging backup has been captured yet.
   - **Supabase Dashboard Migration History:** Integration with `supabase_migrations.schema_migrations` has not occurred.
5. **Explicit Current Operating Reality:**  
   **NO DATABASE MIGRATION HAS BEEN AUTHORIZED OR EXECUTED.** Decisions 4 and 5 remain strictly **NOT AUTHORIZED**.

---

## A2. Current Project Status & Authorization Register

* **Completed Work:**
  - Conceptual architecture and data modeling for PetStory 24p digital MVP (CPL G0–G4).
  - Remediation of all 6 migration safety defects (M13-R1 to M13-R6).
  - Remediation of Review Findings R1–R8 and Final Findings F1–F7:
    - **F1 & F6 (Exact Normalized Role-Set Equality):** Rollback policy checks normalized role sets (`array_agg(r ORDER BY r)` vs exact array literals). Rejects extra roles (F6-A in PG-INT-25), missing roles (F6-B in PG-INT-21), and unexpected PUBLIC (F6-C in PG-INT-26).
    - **F2 (Trigger Fail-Closed):** All 3 rollback trigger checks abort safely if function is missing or procedure OID differs (tested in PG-INT-22).
    - **F3 & F7 (Complete Permission-Denial Matrix):** All 7 role/table access combinations verified in dedicated transaction sessions (PG-INT-23).
    - **F4 (Order Customizations 15 Columns):** Source DDL and preflight checks reconciled for all 15 columns (tested in PG-INT-24).
    - **F5 (Evidence & CI):** All 26 real PostgreSQL integration tests passed in live CI Run 43277854888.
* **Pending Work (Awaiting Decision 4):**
  - Owner review and explicit designation of target Supabase staging project reference.
  - Capture and verification of staging database backup.
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

### Summary of Database Objects Created
1. **Preflight Guard Blocks (Section 0 & 0.1):**
   - Fail-closed role existence check: Aborts with `RAISE EXCEPTION` before any DDL mutation if `anon`, `authenticated`, or `service_role` do not exist in `pg_roles`.
   - Comprehensive schema verification: Inspects existing columns, exact types, lengths, nullability, defaults, PKs, and FKs if M13 tables already exist. Validates all 9 columns of templates, all 11 of sessions, and all 15 of order customizations.
2. **Trigger Function (Section 0):**
   - `public.m13_set_updated_at()`: Created conditionally with exact 0-argument signature and definition verification.
3. **Tables & Columns (Sections 1, 2, 3):**
   - `public.personalization_templates`: **9 columns** (`id`, `product_id`, `version`, `schema_definition`, `layout_template_path`, `default_page_count`, `is_active`, `created_at`, `updated_at`). Primary Key on `id`.
   - `public.customization_sessions`: **11 columns** (`id`, `template_id`, `token_hash`, `current_step`, `answers`, `uploaded_assets`, `preview_artifact_path`, `status`, `expires_at`, `created_at`, `updated_at`). Primary Key on `id`.
   - `public.order_customizations`: **15 columns** (`id`, `order_id`, `session_id`, `rendered_artifact_path`, `render_status`, `render_attempts`, `render_error_log`, `runtime_qel_results`, `download_token_hash`, `download_count`, `download_expires_at`, `revoked_at`, `revocation_reason`, `created_at`, `updated_at`). Primary Key on `id`.
4. **Constraints:**
   - Unique: `uq_personalization_template_version` on `(product_id, version)`.
   - Unique: `customization_sessions.token_hash` (`UNIQUE`).
   - Unique: `uq_order_customization_order` on `order_customizations(order_id)`.
   - Unique: `order_customizations.download_token_hash` (`UNIQUE`).
   - Check: `chk_customization_session_status` on session statuses.
   - Check: `chk_order_customization_status` on render statuses.
5. **Foreign Keys (Conditional vs Inbound):**
   - Inbound (Unconditional):
     - `customization_sessions.template_id` $\rightarrow$ `personalization_templates(id)` (`ON DELETE RESTRICT`).
     - `order_customizations.session_id` $\rightarrow$ `customization_sessions(id)` (`ON DELETE RESTRICT`).
   - Outbound (Conditional — Created ONLY if parent tables exist):
     - `personalization_templates.product_id` $\rightarrow$ `public.products(id)` (`ON DELETE RESTRICT ON UPDATE CASCADE`).
     - `order_customizations.order_id` $\rightarrow$ `public.orders(id)` (`ON DELETE CASCADE`).
6. **Indexes (Explicit vs Constraint-Enforcing):**
   - Explicit Secondary Indexes Created:
     - `idx_customization_sessions_token_hash` on `customization_sessions(token_hash)`.
     - `idx_customization_sessions_template_id` on `customization_sessions(template_id)`.
     - `idx_customization_sessions_expires_at` on `customization_sessions(expires_at)` WHERE `status = 'draft'`.
     - `idx_order_customization_order` on `order_customizations(order_id)`.
     - `idx_order_download_token_hash` on `order_customizations(download_token_hash)`.
   - Constraint-Enforcing Indexes (Automatically created by PostgreSQL):
     - `personalization_templates_pkey`, `customization_sessions_pkey`, `order_customizations_pkey`.
     - `uq_personalization_template_version`, `customization_sessions_token_hash_key`, `uq_order_customization_order`, `order_customizations_download_token_hash_key`.
7. **Triggers:**
   - `trg_personalization_templates_updated_at`, `trg_customization_sessions_updated_at`, `trg_order_customizations_updated_at`.
8. **Row Level Security (RLS) & Table Privileges:**
   - Table RLS enabled on all 3 tables (`ENABLE ROW LEVEL SECURITY`).
   - Explicit Table Privileges:
     - `REVOKE ALL` from `anon, authenticated` on all 3 tables.
     - `GRANT SELECT` on `personalization_templates` to `anon, authenticated`.
     - `GRANT ALL` on all 3 tables to `service_role`.
   - RLS Policies Created (Zero `TO public` fallback):
     - `"Public read active templates"` on `personalization_templates` FOR SELECT TO `anon, authenticated` (`USING (is_active = true)`).
     - `"Service role full access on personalization_templates"` FOR ALL TO `service_role`.
     - `"Service role full access on customization_sessions"` FOR ALL TO `service_role`.
     - `"Service role full access on order_customizations"` FOR ALL TO `service_role`.

---

## A4. Migration Identity & Cryptographic Hashes

Artifact identities and exact file checksums:

* **Repository:** `https://github.com/janzlebiz/JCCF`
* **Target Migration Commit SHA:** `e624e95f74932441dfee90cad7a9cb4544f64d6d`
* **Target Rollback Commit SHA:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`
* **GitHub Actions CI Tested Commit SHA:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`
* **Target Migration File:** `migrations/20261112_001_personalization_engine.sql`
  - **Migration File SHA-256 Checksum:**  
    `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`
* **Target Rollback File:** `migrations/20261112_001_personalization_engine_rollback.sql`
  - **Rollback File SHA-256 Checksum:**  
    `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`
* **Preflight Specification File:** `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md`
  - **Preflight File SHA-256 Checksum:**  
    `CE0A8C1072A49DD328D555CB31E93C9E9DD88538BA08D6696E6F828CF00C6225`
* **Verified CI Workflow:** `.github/workflows/postgres_verification.yml`
  - **Successful CI Run ID:** `43277854888`
  - **CI Run URL:** https://github.com/janzlebiz/JCCF/actions/runs/43277854888
  - **CI Workflow Conclusion:** `success`
* **Evidence Timestamp:** 13 November 2026, 02:18:00 UTC+08:00 (Asia/Manila).

---

## A5. Verification Evidence Matrix

| Requirement Area | Source Artifact / Tool | Verification Type | Result | Scope & Remaining Limitations |
|---|---|---|---|---|
| **SQL Syntax & AST Structure** | `tests/test_migration_scenarios.py` | Static AST & Regex Scan | **PASS** (12/12) | Static code check; does not execute against live PostgreSQL engine. |
| **Real PostgreSQL 15+ Integration** | `tests/test_migration_postgres_integration.py` | Live Container Execution (CI) | **PASS** (26/26) | Executed against `postgres:15-alpine` container service. Does NOT prove execution on Supabase staging. |
| **Disposable DB Isolation** | `test_migration_postgres_integration.py` | Automated DB Isolation (`CREATE DATABASE`) | **PASS** (26/26) | Proves zero cross-test contamination across 26 distinct ephemeral databases. |
| **Fail-Closed Role Preflight** | PG-INT-16 | Live DB Exception Check | **PASS** (1/1) | Verifies that missing required Supabase roles (`service_role`) safely raises `M13 Preflight Failed` and aborts transaction. |
| **Rollback Ownership Guards** | PG-INT-17, PG-INT-18 | Live DB Exception Check | **PASS** (2/2) | Verifies that conflicting same-named triggers or policies abort rollback without dropping foreign objects. |
| **Conditional FK Deployments** | PG-INT-19, PG-INT-20 | Live DB DDL Execution | **PASS** (2/2) | Proves clean standalone deployment (2 internal FKs) and coupled deployment (4 FKs). |
| **Policy Missing Role Abort (F6-B)** | PG-INT-21 | Live DB Exception Check | **PASS** (1/1) | Verifies rollback aborts when policy role is missing; preserves tables. |
| **Trigger Fail-Closed (F2)** | PG-INT-22 | Live DB Exception Check | **PASS** (1/1) | Verifies rollback aborts when trigger exists but M13 function is missing; preserves tables. |
| **Complete 7-Point Permission Matrix (F7)** | PG-INT-23 | Dedicated Session Permission Execution | **PASS** (1/1) | Verifies all 7 permission combinations outside PL/pgSQL: anon/auth read templates only; denied sessions/orders; service_role full access. |
| **15-Column Preflight (F4)** | PG-INT-24 | Live DB Schema Rejection | **PASS** (1/1) | Proves table missing 15th column (`revocation_reason`) is rejected with explicit diagnostic. |
| **Policy Extra Role Abort (F6-A)** | PG-INT-25 | Live DB Exception Check | **PASS** (1/1) | Verifies rollback aborts when policy contains extra unauthorized role; preserves tables. |
| **Policy Unexpected PUBLIC Abort (F6-C)**| PG-INT-26 | Live DB Exception Check | **PASS** (1/1) | Verifies rollback aborts when policy is assigned to PUBLIC; preserves tables. |
| **Sentinel Maintenance DB Isolation** | PG-INT-15 Sentinel Test | Live Catalog Inspection | **PASS** (1/1) | Confirms zero M13 objects leaked into shared `postgres` maintenance DB. |
| **Financial EOC Deductions** | `tests/audit_eoc_model.py` | Programmatic Assertions | **PASS** (16/16) | Mathematical model verification; does not predict real-world customer refund rates. |
| **Jinja2 Hostile Input Sanitization** | `tests/test_hostile_input_sanitization.py` | Automated Template Execution | **PASS** (9/9) | Verifies HTML entity escaping; does not test browser DOM rendering. |
| **Supabase Staging Database Execution** | None (Awaiting D4) | Staging DDL Execution | **NOT EXECUTED** | **Strictly blocked pending Owner Decision 4.** Marked **NOT VERIFIED ON SUPABASE**. |

---

## A6. Complete 7-Point Permission Matrix (F7 Reconciled)

| Role | `personalization_templates` | `customization_sessions` | `order_customizations` | Verification Mode | Result |
|---|---|---|---|---|---|
| **`anon`** | **SELECT Allowed** (active only) | **SELECT Denied** | **SELECT Denied** | Dedicated `SET ROLE anon` transaction | **PASS** (PG-INT-23) |
| **`authenticated`** | **SELECT Allowed** (active only) | **SELECT Denied** | **SELECT Denied** | Dedicated `SET ROLE authenticated` transaction | **PASS** (PG-INT-23) |
| **`service_role`** | **Full Access Allowed** | **Full Access Allowed** | **Full Access Allowed** | Dedicated `SET ROLE service_role` transaction | **PASS** (PG-INT-23) |

---

## A7. Supabase-Specific Compatibility Assessment

| Compatibility Area | Target Requirement | Supabase Assessment | Status | Supporting Evidence & Notes |
|---|---|---|---|---|
| **PostgreSQL Engine Version** | PostgreSQL 15+ | Supported natively by Supabase (standard is PG 15.x / 16.x). | **VERIFIED ON PG 15 CONTAINER** | Migration requires PG 13+ native `gen_random_uuid()`. |
| **PostgREST Standard Roles** | `anon`, `authenticated`, `service_role` exist | Supabase pre-seeds these roles on all projects. | **VERIFIED VIA PREFLIGHT GUARD** | Section 0 preflight check aborts immediately if any required role is absent. |
| **Role Fallback Behavior** | Zero `TO public` fallback for service role | Insecure fallback to `PUBLIC` must never occur. | Hardened migration eliminated all conditional `TO public` branches. Roles are strictly `anon, authenticated, service_role`. | **VERIFIED** | In a Supabase environment, roles are pre-seeded. In our CI harness, roles are pre-seeded cluster-wide. |
| **Row Level Security (RLS)** | Table isolation and access policies | Public direct access denied to guest intake answers and fulfillment PDFs. | `personalization_templates` allows `SELECT` for active templates. `customization_sessions` and `order_customizations` grant access exclusively to `service_role`. | **VERIFIED ON PG 15 CONTAINER** | Tested in live CI (PG-INT-23). Enforces zero customer data leakage. Status on live Supabase remains **NOT VERIFIED ON SUPABASE**. |
| **Function Ownership & search_path** | `public.m13_set_updated_at()` | Executed by `postgres` admin role in Supabase. Explicit schema qualification (`public.*`) used throughout. | **VERIFIED** | Function strictly performs `NEW.updated_at = now(); RETURN NEW;`. Zero search_path vulnerability. |
| **Extensions Required** | Native `gen_random_uuid()` | Native core feature in PostgreSQL 13+. No `pgcrypto` or `uuid-ossp` extensions required. | **VERIFIED** | Clean PG 15 Alpine container executes migration without creating extensions. |
| **Rollback Ownership Safeguards** | Verified trigger OID, function presence, and normalized role-set equality | Rollback inspects procedure OID, function existence, and exact normalized role arrays before dropping; aborts on clash. | **VERIFIED ON PG 15 CONTAINER** | Tested via PG-INT-17, PG-INT-18, PG-INT-21, PG-INT-22, PG-INT-25, PG-INT-26. |
| **Supabase Staging Integration** | Live PostgREST schema cache and JWT validation | Requires live execution on Supabase staging project. | **NOT VERIFIED ON SUPABASE** | Blocked pending Decision 4 approval. |

---

## A8. Staging Environment Identity

* **Target Environment Classification:** Dedicated Development / Staging Project (Non-Production).
* **Project Name:** To be confirmed by Owner upon authorization.
* **Project Reference ID (`<staging-ref>`):** **[BLOCKED — AWAITING OWNER SPECIFICATION]**
* **Database Host:** `db.<staging-ref>.supabase.co`
* **Target Schema:** `public`
* **Production Protection Invariant:** The target project reference MUST NOT match the JCCF production project reference.
* **Current Environment Status:** **BLOCKED**. The repository does not store staging credentials or project references. The platform owner must explicitly designate `<staging-ref>` in the Decision 4 approval instrument.

---

## A9. Backup and Recovery Plan

Before applying the migration to staging, an independently verified backup approach must be completed:

1. **Backup Classification & Hierarchy:**
   - **Logical Schema Dump:** Captures DDL definitions only (`pg_dump -s`). Insufficient for data recovery.
   - **Logical Full Dump:** Captures schema and row data (`supabase db dump --project-ref <staging-ref> -f backup.sql` or `pg_dump -Fc`). Standard for pre-migration safety.
   - **Supabase-Managed PITR / Physical Snapshot:** Point-in-time recovery managed via Supabase Pro/Team tier. Provides full cluster-level restoration.
2. **Mandatory Pre-Migration Requirement:**
   - A non-zero dump file alone does NOT prove recoverability.
   - The operator must verify that the backup file is valid, non-empty, and structurally restorable, or confirm that an active Supabase automated physical snapshot / PITR window is verified in the Supabase Dashboard prior to DDL execution.
3. **Restore Verification Procedure:**
   - In the event of catastrophic failure where transaction rollback fails, execute:
     ```bash
     psql -h db.<staging-ref>.supabase.co -U postgres -d postgres -f staging_pre_m13_backup.sql
     ```
   - Verify restoration of pre-migration table counts and schema state.

---

## A10. Proposed Execution Runbook (Future Operator)

> [!WARNING]
> **PROPOSED PROCEDURE ONLY — DO NOT EXECUTE WITHOUT FORMAL D4 APPROVAL.**

1. **Pre-Execution Gate:** Confirm platform owner has signed Decision 4, citing migration hash `9D6579BC...` and rollback hash `73725DF9...`.
2. **Target Isolation Check:** Confirm active connection string points to staging project `<staging-ref>`, never production.
3. **Pre-Migration Backup:** Capture logical backup and verify recovery readiness.
4. **Preflight Execution:** Execute Preflight Checks 1 through 6 from `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md`.
5. **Migration Execution:** Execute `migrations/20261112_001_personalization_engine.sql` in a single transaction via `psql` or Supabase CLI.
6. **Post-Migration Verification:**
   - Confirm creation of tables `personalization_templates`, `customization_sessions`, and `order_customizations`.
   - Confirm RLS enabled on all 3 tables.
   - Verify `anon` role can SELECT active templates but CANNOT SELECT from `customization_sessions` or `order_customizations` (in isolated testing sessions).
   - Verify `service_role` has full access across all 3 tables.
7. **Handoff & Record:** Log output, record execution timestamp, and report results to platform owner. **STOP.** Do not proceed to Phase 1 engineering.

---

## A11. Rollback and Stop Conditions

* **Exact Rollback Artifact:** `migrations/20261112_001_personalization_engine_rollback.sql`
* **Rollback SHA-256 Checksum:** `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`
* **Immediate Stop & Rollback Conditions:**
  1. Role preflight guard fails (`Required Supabase role(s) do not exist`).
  2. Any schema preflight check raises an exception.
  3. DDL execution returns an unhandled database error.
  4. Post-migration permission validation reveals unauthorized public access to guest intake sessions or order records.
* **Rollback Ownership & Restrictive Safety (F1 & F6 Reconciled):**
  - Before dropping triggers, verifies `m13_set_updated_at()` exists AND procedure OID matches. Aborts on clash or missing function.
  - Before dropping RLS policies, verifies command, exact normalized role sets (`array_agg(r ORDER BY r)`), and qualifiers match M13 contract. Aborts on extra roles, missing roles, or altered qualifiers.
  - All 3 tables dropped using `RESTRICT` (zero `CASCADE`). If an external table or view references M13 tables, PostgreSQL halts the drop.
  - Dedicated trigger function `public.m13_set_updated_at()` dropped with `RESTRICT` only after confirming zero external triggers depend on it.
* **Reversibility Limits:**
  - Rollback drops M13 schema objects and deletes data held in those tables. **Rollback is not a data recovery mechanism.**
  - Rollback does NOT alter external platform tables (`products`, `orders`).

---

## A12. Risks and Mitigations

| Risk Category | Identified Hazard | Inherent Risk | Implemented Mitigation | Residual Risk |
|---|---|---|---|---|
| **Environment Selection** | Accidental execution against production database | Critical | Staging project reference must be explicitly verified; production credentials strictly omitted from repository. | Low |
| **Role Preflight** | Executing in environment without PostgREST roles | High | Fail-closed Section 0 preflight check aborts before schema mutation if `anon`, `authenticated`, or `service_role` missing. | Negligible |
| **Function Collision** | Overwriting shared platform trigger function | High | Subsystem-namespaced function `m13_set_updated_at()` created with exact 0-arg signature inspection; shared platform functions preserved. | Negligible |
| **Security / Data Leak** | Anonymous exposure of guest intake answers or customer orders | High | Strict RLS enabled; table privileges explicitly revoked from `anon` and `authenticated`; service-role only access on sensitive tables. Zero `TO public` fallback. Complete 7-point permission matrix verified. | Low |
| **Unintended Cascades** | Dropping shared or dependent objects during rollback | High | Rollback uses strictly `DROP TABLE ... RESTRICT` (0 `CASCADE`); fails safely if unexpected dependencies exist. Verifies trigger OIDs, function presence, and exact normalized policy role arrays before dropping. | Negligible |
| **Schema Incompatibility** | Incompatible pre-existing table or foreign key definition | Medium | Section 0.1 performs exhaustive preflight checks on 100% of required columns (9 in templates, 11 in sessions, 15 in order customizations), types, nullability, defaults, PKs, and FKs. | Negligible |

---

## A13. Explicit Owner Decision Instrument

```markdown
================================================================================
FORMAL OWNER DECISION INSTRUMENT: DECISION 4
SUBSYSTEM M13 — SUPABASE STAGING DATABASE MIGRATION
================================================================================

Target Repository:              https://github.com/janzlebiz/JCCF
Governing Migration Commit SHA: e624e95f74932441dfee90cad7a9cb4544f64d6d
Governing Rollback Commit SHA:  f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4
Verified CI Run Commit SHA:     f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4
Target Migration File:          migrations/20261112_001_personalization_engine.sql
Target Migration SHA-256:       9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E
Target Rollback File:           migrations/20261112_001_personalization_engine_rollback.sql
Target Rollback SHA-256:        73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4
Target Supabase Staging Ref:    [ Owner to specify: <staging-ref> ]

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

Owner Signature:      ______________________________________
Decision Date:        ______________________________________
Staging Project Ref:  ______________________________________
Owner Conditions:     ______________________________________
================================================================================
```
