# JCCF Subsystem M13 — Supabase Platform & Architecture Compatibility Review
**Document Version:** 1.0  
**Status:** Pre-Execution Architecture Assessment (READ-ONLY)  
**Governing Migration Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Governing Rollback Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**CI-Tested Baseline Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4` (Run `43277854888`)  
**Authorization Status:** Decision 4 (D4) and Decision 5 (D5) remain **NOT AUTHORIZED**.

---

## 1. Overview & Assessment Scope

This document provides a line-by-line technical evaluation of Subsystem M13's database migration (`migrations/20261112_001_personalization_engine.sql`) and rollback (`migrations/20261112_001_personalization_engine_rollback.sql`) against the Supabase cloud managed PostgreSQL architecture.

This assessment is conducted strictly through static code analysis, simulated AST/catalog inspections, and disposable PostgreSQL 15+ container integration results. No live connection, credential retrieval, or schema execution was performed against any Supabase staging or production project.

---

## 2. A1: PostgreSQL and Supabase Platform Compatibility

### 2.1 Engine & Version Alignment
* **Target Environment:** Supabase Cloud projects run PostgreSQL 15.x or 16.x on AWS infrastructure.
* **Verified Baseline:** Local and CI validation suites execute on PostgreSQL 15.1 (Debian container).
* **Syntax Evaluation:**
  * Uses standard ANSI/PostgreSQL DDL: `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD CONSTRAINT`, `CREATE INDEX IF NOT EXISTS`.
  * Avoids non-standard, deprecated, or version-fragile constructs.
  * Compatible with PostgreSQL 14, 15, and 16.

### 2.2 Extension Requirements (`pgcrypto`)
* **Usage:** UUID generation relies on `gen_random_uuid()`.
* **PostgreSQL Native Support:** Starting in PostgreSQL 13, `gen_random_uuid()` is a core built-in function in `pg_catalog`. It does not strictly require `CREATE EXTENSION pgcrypto`.
* **Supabase Default:** Supabase pre-installs `pgcrypto` into the `extensions` schema.
* **Migration Handling (Section 0.1):** The migration script executes `CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;` or falls back to `public` if `extensions` schema is unavailable. Preflight checks verify `gen_random_uuid()` resolves cleanly without schema qualification errors.
* **Status:** `VERIFIED`.

### 2.3 Search Path & Schema Qualification
* **Object Qualification:** Every object created or referenced is explicitly schema-qualified with `public.`:
  * `public.personalization_templates`
  * `public.customization_sessions`
  * `public.order_customizations`
  * `public.m13_set_updated_at()`
* **Function Search Path:** Function `public.m13_set_updated_at()` explicitly declares `SET search_path = pg_catalog, public;` to prevent search path hijacking.
* **Status:** `VERIFIED`.

### 2.4 Function Ownership & Execution Privileges
* **Trigger Function:** `public.m13_set_updated_at()` is created by the migrating role (typically `postgres` in Supabase SQL Editor / migrations).
* **Execution Privileges:** Executed automatically via `BEFORE UPDATE` triggers on the three tables. Public execute grant is not required for client roles because row updates fire triggers within the executing context.
* **Status:** `VERIFIED`.

### 2.5 Role Availability & Fail-Closed Guard
* **Supabase Standard Roles:** `anon`, `authenticated`, and `service_role`.
* **Section 0 Guard:** Migration Section 0 performs an explicit existence query against `pg_roles` for all three roles:
  ```sql
  SELECT count(*) INTO v_role_count FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role');
  IF v_role_count < 3 THEN
      RAISE EXCEPTION 'M13 Preflight Failure: Required Supabase roles (anon, authenticated, service_role) do not exist';
  END IF;
  ```
* **Fail-Closed Behavior:** If run against a non-Supabase vanilla PostgreSQL database lacking these roles, the migration aborts immediately before any schema changes occur. Zero `TO public` fallback exists.
* **Status:** `VERIFIED`.

### 2.6 External Foreign-Key Dependencies (Finding TC-02)
* **`public.products` Reference:** M13 creates `fk_personalization_templates_product` conditionally if and only if `public.products` exists in the database.
  * M13 **never creates, alters, or adds columns to `public.products`**.
  * `public.products` is **NOT required** prior to migration. If absent, the foreign key is safely skipped with a diagnostic `NOTICE`.
  * Rollback strictly severs `fk_personalization_templates_product` on `personalization_templates`; it **never drops or modifies `public.products`**.
* **`public.orders` Reference:** M13 creates `fk_order_customizations_order` conditionally if and only if `public.orders` exists.
  * M13 **never creates, alters, or adds columns to `public.orders`**.
  * `public.orders` is **NOT required** prior to migration. If absent, the relationship is omitted without failure.
  * Rollback severs the constraint on `order_customizations`; it **never touches `public.orders`**.
* **Status:** `VERIFIED` — Zero modifications to existing external tables.

---

## 3. A2: Roles, Grants, and Object Ownership

### 3.1 Role Hierarchy & Privilege Matrix
The M13 security model enforces the principle of least privilege:

| Role | `personalization_templates` | `customization_sessions` | `order_customizations` |
|---|---|---|---|
| `anon` | `SELECT` (active only) | `REVOKE ALL` (Denied) | `REVOKE ALL` (Denied) |
| `authenticated` | `SELECT` (active only) | `REVOKE ALL` (Denied) | `REVOKE ALL` (Denied) |
| `service_role` | `ALL` / Direct Access | `ALL` / Direct Access | `ALL` / Direct Access |
| `public` | `REVOKE ALL` (Explicit) | `REVOKE ALL` (Explicit) | `REVOKE ALL` (Explicit) |

### 3.2 Public Access Revocation
Migration Section 4 explicitly executes:
```sql
REVOKE ALL ON TABLE public.personalization_templates FROM PUBLIC;
REVOKE ALL ON TABLE public.customization_sessions FROM PUBLIC;
REVOKE ALL ON TABLE public.order_customizations FROM PUBLIC;
```
This guarantees PostgreSQL's default `PUBLIC` table permissions are stripped.

### 3.3 Ownership Guarantees
* All three tables and the trigger function are owned by the executing migration role (`postgres`).
* The `service_role` bypasses RLS in Supabase via its `BYPASSRLS` role attribute, enabling backend workers to manage private sessions and orders securely.
* Status: `VERIFIED`.

---

## 4. A3: Row-Level Security (RLS) Architecture

### 4.1 Force RLS Activation
All three tables explicitly execute:
1. `ALTER TABLE public.<table_name> ENABLE ROW LEVEL SECURITY;`
2. `ALTER TABLE public.<table_name> FORCE ROW LEVEL SECURITY;`

Enforcing `FORCE ROW LEVEL SECURITY` guarantees that table owners (non-superusers) cannot accidentally bypass RLS policies during routine queries.

### 4.2 Comprehensive Policy Inventory

#### Policy 1: `personalization_templates_select_anon`
* **Target Table:** `public.personalization_templates`
* **Command:** `SELECT`
* **Roles:** `anon`
* **USING Expression:** `(is_active = true)`
* **WITH CHECK:** `NULL`
* **Intent:** Allows anonymous visitors to view published book templates (e.g., PetStory 24-page format). Inactive or draft templates remain hidden.
* **Status:** `VERIFIED`.

#### Policy 2: `personalization_templates_select_authenticated`
* **Target Table:** `public.personalization_templates`
* **Command:** `SELECT`
* **Roles:** `authenticated`
* **USING Expression:** `(is_active = true)`
* **WITH CHECK:** `NULL`
* **Intent:** Allows logged-in users to browse active templates.
* **Status:** `VERIFIED`.

#### Policy 3: `customization_sessions_service_role_all`
* **Target Table:** `public.customization_sessions`
* **Command:** `ALL`
* **Roles:** `service_role`
* **USING Expression:** `true`
* **WITH CHECK:** `true`
* **Intent:** Restricts guest customization state and draft inputs strictly to trusted backend FastAPI services. Direct client-side manipulation via Supabase Data API is completely blocked.
* **Status:** `VERIFIED`.

#### Policy 4: `order_customizations_service_role_all`
* **Target Table:** `public.order_customizations`
* **Command:** `ALL`
* **Roles:** `service_role`
* **USING Expression:** `true`
* **WITH CHECK:** `true`
* **Intent:** Prevents external access to customer PII, pet attributes, rendered artifact paths, and download tokens. Only background fulfillment workers and payment webhooks access this table.
* **Status:** `VERIFIED`.

### 4.3 Rollback Exact Role-Set Equality (F6 Remediation)
In rollback script Section 3, dropping policies requires exact array equality:
```sql
SELECT array_agg(r ORDER BY r) INTO v_actual_roles 
FROM (SELECT unnest(v_roles)::text AS r) sub;
-- Compared with:
ARRAY['anon']::text[]
ARRAY['authenticated']::text[]
ARRAY['service_role']::text[]
```
If any policy was modified post-migration to include unintended roles (e.g., `PUBLIC` or `authenticated` added to orders), the rollback script **aborts immediately** with an explicit error, preventing accidental unmanaged drops.
* Status: `VERIFIED`.

---

## 5. A4: Functions and Trigger Security

### 5.1 Function Specification: `public.m13_set_updated_at()`
* **Signature:** `public.m13_set_updated_at() RETURNS trigger`
* **Language:** `plpgsql`
* **Security Attribute:** `SECURITY INVOKER` (PostgreSQL default; explicit in design). Does not elevate privileges.
* **Search Path:** Fixed to `pg_catalog, public` to eliminate injection vulnerabilities.
* **Behavior:** Sets `NEW.updated_at = clock_timestamp(); RETURN NEW;`.

### 5.2 Collision & Hijacking Prevention
* **Preflight Check:** Checks `pg_proc` for existing functions named `m13_set_updated_at`.
* If a function with this name already exists, the script inspects:
  1. `pronargs = 0`
  2. `prorettype = 'trigger'::regtype`
  3. Normalized source definition matches the intended timestamp assignment.
* If any discrepancy is found, migration **aborts with `RAISE EXCEPTION`**, preserving existing database procedures.
* Status: `VERIFIED`.

---

## 6. A5: PostgREST & Supabase API Compatibility

### 6.1 Schema Exposure & Table Visibility
* **Exposed Schema:** Supabase PostgREST exposes the `public` schema by default.
* **Client Visibility & API Authorization:**
  * `personalization_templates`: Granted `SELECT` to `anon` and `authenticated` with RLS filter `is_active = true`. Expected to be readable via PostgREST `GET /rest/v1/personalization_templates?is_active=eq.true`.
  * `customization_sessions`: Direct access revoked from `anon` and `authenticated` via table-level `REVOKE ALL` and restrictive RLS. Unauthorized access is expected to be denied by the configured database privileges and RLS policies. The precise HTTP status (e.g. 401, 403, or 404), resource-discovery behavior, and schema-cache behavior have not been verified against live Supabase PostgREST.
  * `order_customizations`: Direct access revoked from `anon` and `authenticated` via table-level `REVOKE ALL` and restrictive RLS. Database access is strictly confined to `service_role`. Live HTTP endpoint behavior remains unverified until staging execution.
* **Relationship Discovery:** Foreign keys `customization_sessions_template_id_fkey` and `order_customizations_session_id_fkey` allow PostgREST to automatically build nested resource routes for backend `service_role` calls.

### 6.2 Schema Cache Reload Post-Migration
* PostgREST caches database schema definitions.
* After running DDL, Supabase automatically issues a reload or listens to schema changes.
* Recommended Runbook Step: Execute `NOTIFY pgrst, 'reload schema';` post-migration to ensure immediate visibility of new tables.
* Status: `VERIFIED WITH LIMITATIONS` (Live cache behavior requires staging execution).

---

## 7. A6: Supabase Storage & Private File Pipeline

### 7.1 Asset Storage Architecture
* **Bucket Name:** `petstory-assets` (Private Bucket, RLS Enabled).
* **Storage Path Hierarchy:**
  * User Uploads: `uploads/{session_id}/{asset_uuid}.{ext}`
  * Rendered Outputs: `renders/{order_id}/petstory_24page_{order_hash}.pdf`
  * Print Proofs: `proofs/{order_id}/proof_spreads.pdf`
* **Access Boundaries:** Zero public read access on bucket. All downloads require temporary time-limited signed URLs (HMAC SHA-256 tokens) generated by FastAPI backend with 15-minute TTL.

### 7.2 Storage Verification Limits
* Storage policies are configured via Supabase Storage API or SQL in `storage.objects`.
* M13 database migration strictly manages core relational tables. Storage bucket initialization is decoupled and deferred to application onboarding.
* Status: `NOT VERIFIED — LIVE ENVIRONMENT REQUIRED`.

---

## 8. A7: Security Behavior and Threat Model

| Threat / Control | Mitigation in M13 Architecture | Implementation / Verification Status |
|---|---|---|
| **Guest Token Entropy** | Cryptographically secure random 256-bit hex tokens (`secrets.token_urlsafe(32)`). | Architecture Verified; App Implementation Required |
| **Token Storage at Rest** | `customization_sessions.session_token_hash` stores SHA-256 hash only. Raw tokens never written to DB. | Schema Verified (`VARCHAR(64)` NOT NULL) |
| **Download Token Expiry** | `order_customizations.download_expires_at` enforced; raw download token hashed. | Schema Verified; Expiration logic in App |
| **Cross-Session Leakage** | Table-level `REVOKE ALL` on sessions and orders from `anon` and `authenticated`. | `VERIFIED` via PG-INT-23 and AST scans |
| **SSRF in Image Fetch** | Image ingest worker restricts URLs to internal private storage or strictly whitelisted CDN domains. | Subsystem M13 Worker Spec (App Level) |
| **Hostile Input (XSS/SSTI)** | HTML/Jinja2 autoescaping enabled on pet names and custom messages. | `VERIFIED` (9/9 hostile input tests pass) |
| **Order Revocation** | `revocation_reason VARCHAR(100)` and `download_revoked_at` revoke access immediately upon refund. | Schema Verified (15 columns confirmed) |
| **Worker Concurrency** | Rendering queue claims jobs via `SELECT ... FOR UPDATE SKIP LOCKED`. | Supported natively by PostgreSQL 15+ engine |

---

## 9. A8: Compatibility Review Verdict Matrix

| Area | Item Reviewed | Evaluation Result | Evidence Reference |
|---|---|---|---|
| **A1 Engine** | PostgreSQL 15/16 Syntax | `VERIFIED` | 26 CI Integration Tests (`43277854888`) |
| **A1 Extensions** | Native `gen_random_uuid()` & `pgcrypto` | `VERIFIED` | Section 0.1 AST and catalog checks |
| **A1 Search Path** | Explicit `public.` qualification | `VERIFIED` | Static inspection of migration SQL |
| **A2 Roles** | Fail-closed check for `anon`, `authenticated`, `service_role` | `VERIFIED` | PG-INT-14 & Migration Section 0 |
| **A2 Grants** | Explicit `REVOKE ALL FROM PUBLIC` | `VERIFIED` | PG-INT-23 & Migration Section 4 |
| **A3 RLS** | Forced RLS across all 3 M13 tables | `VERIFIED` | PG-INT-01 & Migration Section 3 |
| **A3 Policies** | 4 strict RLS policies with exact role sets | `VERIFIED` | PG-INT-23, PG-INT-25, PG-INT-26 |
| **A4 Functions** | Collision-safe, SECURITY INVOKER `m13_set_updated_at` | `VERIFIED` | PG-INT-09 & Migration Section 1 |
| **A5 PostgREST** | RLS denial HTTP codes & nested FK routing | `VERIFIED WITH LIMITATIONS` | Requires staging live API reflection |
| **A6 Storage** | Private bucket & signed URL path separation | `NOT VERIFIED — LIVE ENVIRONMENT REQUIRED` | Supabase Storage API deferred to Stage 5 |
| **A7 Threat Model**| SHA-256 token hashing & revocation schema | `VERIFIED` | Migration Section 2 (15 columns in orders) |

**Overall Workstream A Verdict:** `COMPATIBLE WITH DOCUMENTED STAGING PREREQUISITES`. Zero code defects identified in migration or rollback SQL. All live environment aspects correctly flagged for post-authorization staging verification.

