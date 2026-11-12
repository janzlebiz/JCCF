# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Migration Scope Inventory

**Document ID:** `JCCF-M13-STAGE-4-SCOPE-INV`  
**Date:** 13 November 2026 (2026-11-13T01:35:00+08:00)  
**Status:** REFERENCE INVENTORY — EXECUTION STRICTLY PROHIBITED  
**Migration Artifact:** `migrations/20261112_001_personalization_engine.sql` (SHA-256: `C475ED5C5668179789236F762FC1C04AA9B085F2B7B42E3C08724D0AB62028C9`)  
**Rollback Artifact:** `migrations/20261112_001_personalization_engine_rollback.sql` (SHA-256: `897FDAB8EC808FB989258C361F712A4D522E2C1BCE80A4460BB2A7131A7F37C6`)  

---

## 1. Object-by-Object Migration Inventory

| Object Type | Schema | Object Name | Operation | Existing State Assumption | Dependencies | Security Impact | Rollback Behavior | Source SQL Location |
|---|---|---|---|---|---|---|---|---|
| **Trigger Function** | `public` | `m13_set_updated_at()` | `CREATE FUNCTION` (Conditional via PL/pgSQL) | Assumes zero non-M13 0-arg function exists with same name. If exists, definition must match. | `plpgsql` language, core PostgreSQL | Internal utility; updates timestamp. | Dropped with `RESTRICT` if 0 triggers reference it. | Lines 24–79 |
| **Preflight Guard** | `public` | `personalization_templates` schema check | Validation block (`DO $$`) | If table exists, all 9 columns, types, nullability, and PK must match M13 contract. | `information_schema`, `pg_constraint` | Prevents corrupting non-compliant table. | N/A (read-only validation) | Lines 86–124 |
| **Preflight Guard** | `public` | `customization_sessions` schema check | Validation block (`DO $$`) | If table exists, all 10 columns, types, nullability, and PK must match M13 contract. | `information_schema`, `pg_constraint` | Prevents corrupting non-compliant table. | N/A (read-only validation) | Lines 129–161 |
| **Preflight Guard** | `public` | `order_customizations` schema check | Validation block (`DO $$`) | If table exists, all 14 columns, types, nullability, and PK must match M13 contract. | `information_schema`, `pg_constraint` | Prevents corrupting non-compliant table. | N/A (read-only validation) | Lines 166–201 |
| **Table** | `public` | `personalization_templates` | `CREATE TABLE IF NOT EXISTS` | Fresh table creation or idempotent reuse of compliant table. | `gen_random_uuid()` (PG 13+ native) | Public read active rows; service_role write. | Dropped via `DROP TABLE ... RESTRICT`. | Lines 207–218 |
| **Unique Constraint** | `public` | `uq_personalization_template_version` | `CONSTRAINT UNIQUE` on `(product_id, version)` | Ensures one active schema version per product. | `personalization_templates` | Integrity enforcement. | Dropped with table. | Line 217 |
| **Foreign Key** | `public` | `fk_personalization_templates_product` | `ALTER TABLE ADD CONSTRAINT` (Conditional) | Attached if `public.products` table exists; verifies cols and delete `RESTRICT` / update `CASCADE`. | `public.products(id)` | Enforces referential integrity with platform products. | Severed explicitly via `ALTER TABLE DROP CONSTRAINT`. | Lines 224–273 |
| **Table** | `public` | `customization_sessions` | `CREATE TABLE IF NOT EXISTS` | Fresh table creation or idempotent reuse of compliant table. | `personalization_templates(id)` | High: Transient customer intake data; anonymous guest access. | Dropped via `DROP TABLE ... RESTRICT`. | Lines 278–293 |
| **Check Constraint** | `public` | `chk_customization_session_status` | `CHECK` constraint on `status` | Restricts statuses to `('draft', 'preview_generated', 'checkout_pending', 'converted', 'abandoned', 'expired')`. | `customization_sessions` | State machine integrity. | Dropped with table. | Lines 290–292 |
| **Index** | `public` | `idx_customization_sessions_token_hash` | `CREATE INDEX IF NOT EXISTS` | Hash-based O(1) session lookup. | `customization_sessions(token_hash)` | Fast retrieval for guest intake without logging token. | Dropped with table. | Line 295 |
| **Index** | `public` | `idx_customization_sessions_template_id` | `CREATE INDEX IF NOT EXISTS` | FK performance index. | `customization_sessions(template_id)` | Query performance. | Dropped with table. | Line 296 |
| **Partial Index** | `public` | `idx_customization_sessions_expires_at` | `CREATE INDEX IF NOT EXISTS` (Partial) | Speeds up TTL expiration worker on draft sessions. | `customization_sessions(expires_at)` WHERE `status = 'draft'` | Query performance. | Dropped with table. | Line 297 |
| **Table** | `public` | `order_customizations` | `CREATE TABLE IF NOT EXISTS` | Fresh table creation or idempotent reuse of compliant table. | `customization_sessions(id)` | High: Fulfillment records linking orders to rendered PDFs and download tokens. | Dropped via `DROP TABLE ... RESTRICT`. | Lines 304–324 |
| **Unique Constraint** | `public` | `uq_order_customization_order` | `CONSTRAINT UNIQUE` on `(order_id)` | Enforces exactly 1 customization per order. | `order_customizations(order_id)` | Architectural invariant. | Dropped with table. | Line 320 |
| **Check Constraint** | `public` | `chk_order_customization_status` | `CHECK` constraint on `render_status` | Restricts statuses to `('pending', 'processing', 'completed', 'failed', 'qel_rejected', 'refunded', 'revoked')`. | `order_customizations` | State machine integrity. | Dropped with table. | Lines 321–323 |
| **Index** | `public` | `idx_order_customization_order` | `CREATE INDEX IF NOT EXISTS` | Fast lookup by platform order ID. | `order_customizations(order_id)` | Query performance. | Dropped with table. | Line 326 |
| **Index** | `public` | `idx_order_download_token_hash` | `CREATE INDEX IF NOT EXISTS` | Fast lookup by hashed download token. | `order_customizations(download_token_hash)` | Download gate security. | Dropped with table. | Line 327 |
| **Foreign Key** | `public` | `fk_order_customizations_order` | `ALTER TABLE ADD CONSTRAINT` (Conditional) | Attached if `public.orders` exists; verifies cols and delete `CASCADE`. | `public.orders(id)` | Referential integrity. | Severed explicitly via `ALTER TABLE DROP CONSTRAINT`. | Lines 333–380 |
| **Trigger** | `public` | `trg_personalization_templates_updated_at` | `CREATE TRIGGER` (Protected) | Before update trigger setting `updated_at`. Verifies procedure OID. | `personalization_templates`, `m13_set_updated_at()` | Automatically maintains audit timestamps. | Dropped via `DROP TRIGGER IF EXISTS`. | Lines 386–420 |
| **Trigger** | `public` | `trg_customization_sessions_updated_at` | `CREATE TRIGGER` (Protected) | Before update trigger setting `updated_at`. Verifies procedure OID. | `customization_sessions`, `m13_set_updated_at()` | Automatically maintains audit timestamps. | Dropped via `DROP TRIGGER IF EXISTS`. | Lines 423–446 |
| **Trigger** | `public` | `trg_order_customizations_updated_at` | `CREATE TRIGGER` (Protected) | Before update trigger setting `updated_at`. Verifies procedure OID. | `order_customizations`, `m13_set_updated_at()` | Automatically maintains audit timestamps. | Dropped via `DROP TRIGGER IF EXISTS`. | Lines 449–472 |
| **RLS Enablement** | `public` | `personalization_templates` | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` | Row level security active. | Core PostgreSQL security | Enforces access policies. | Disabled if table dropped. | Line 478 |
| **RLS Enablement** | `public` | `customization_sessions` | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` | Row level security active. | Core PostgreSQL security | Enforces access policies. | Disabled if table dropped. | Line 479 |
| **RLS Enablement** | `public` | `order_customizations` | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` | Row level security active. | Core PostgreSQL security | Enforces access policies. | Disabled if table dropped. | Line 480 |
| **Privileges Revoke/Grant** | `public` | Table privileges for `anon`, `authenticated`, `service_role` | `REVOKE ALL` / `GRANT` (Conditional on role existence) | Revokes direct table privileges on sessions and orders from public roles; grants SELECT on templates. | `pg_roles` | High: Enforces least privilege boundary. | Reverted on drop. | Lines 485–506 |
| **RLS Policy** | `public` | `"Public read active templates"` | `CREATE POLICY` (Protected) | SELECT allowed for `anon` and `authenticated` where `is_active = true`. | `personalization_templates` | Allows public catalog browsing. | Dropped via `DROP POLICY IF EXISTS`. | Lines 519–555 |
| **RLS Policy** | `public` | `"Service role full access on personalization_templates"` | `CREATE POLICY` (Protected) | ALL allowed for `service_role` (`USING (true) WITH CHECK (true)`). | `personalization_templates` | Backend administrative access. | Dropped via `DROP POLICY IF EXISTS`. | Lines 558–588 |
| **RLS Policy** | `public` | `"Service role full access on customization_sessions"` | `CREATE POLICY` (Protected) | ALL allowed for `service_role` (`USING (true) WITH CHECK (true)`). | `customization_sessions` | Backend intake processor access. | Dropped via `DROP POLICY IF EXISTS`. | Lines 591–621 |
| **RLS Policy** | `public` | `"Service role full access on order_customizations"` | `CREATE POLICY` (Protected) | ALL allowed for `service_role` (`USING (true) WITH CHECK (true)`). | `order_customizations` | Backend fulfillment worker access. | Dropped via `DROP POLICY IF EXISTS`. | Lines 624–654 |

---

## 2. Destructive Operations & Shared Object Analysis

1. **Destructive SQL Analysis:**
   - **Zero DROP Operations:** The migration script contains zero `DROP TABLE`, `DROP COLUMN`, `DROP CONSTRAINT`, or `DROP FUNCTION` statements.
   - **Zero CASCADE Operations:** The migration script contains zero `CASCADE` drops.
   - **Explicit Revocations:** Table privileges on `customization_sessions` and `order_customizations` are explicitly revoked from `anon` and `authenticated`. This is intentional and mandatory to guarantee zero guest data exposure.
2. **Shared Object Collision Safeguards:**
   - **Shared Function Protection:** Migration does NOT touch or overwrite `public.set_current_timestamp_updated_at()`. It introduces an M13-namespaced function `public.m13_set_updated_at()`.
   - **Collision-Safe Inspection:** Before creating `public.m13_set_updated_at()`, the migration queries `pg_proc` for exact argument counts and body definitions. If an incompatible function exists, it aborts via `RAISE EXCEPTION`.
   - **Pre-Existing Foreign Key Protection:** Foreign keys to `public.products` and `public.orders` are added only if those tables exist, and their exact constraint properties are verified before reuse.
