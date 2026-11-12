# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Migration Scope Inventory (Remediated v3.0)

**Document ID:** `JCCF-M13-STAGE-4-SCOPE-INV`  
**Version:** 3.0 (Post-Review Reconciliation)  
**Date:** 13 November 2026 (2026-11-13T02:06:00+08:00)  
**Status:** REFERENCE INVENTORY — EXECUTION STRICTLY PROHIBITED  
**Migration Artifact:** `migrations/20261112_001_personalization_engine.sql` (SHA-256: `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`)  
**Rollback Artifact:** `migrations/20261112_001_personalization_engine_rollback.sql` (SHA-256: `33911582CB3FCD893A4286D71AB28CAEECEE1B56696EA840DE59A184BD5B4BD4`)  

---

## 1. Table & Column Definitions (Exact Column Counts)

### Table 1: `public.personalization_templates` (**9 Columns**)
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` (NOT NULL)
- `product_id UUID NOT NULL`
- `version VARCHAR(20) NOT NULL`
- `schema_definition JSONB NOT NULL`
- `layout_template_path TEXT NOT NULL`
- `default_page_count INT NOT NULL DEFAULT 24`
- `is_active BOOLEAN NOT NULL DEFAULT true`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- *Constraints:*
  - Primary Key: `personalization_templates_pkey` on `(id)` (Constraint-enforcing index automatically created).
  - Unique Constraint: `uq_personalization_template_version` on `(product_id, version)` (Constraint-enforcing index automatically created).
  - Outbound Foreign Key (Conditional): `fk_personalization_templates_product` on `product_id` references `public.products(id)` ON DELETE RESTRICT ON UPDATE CASCADE (Created only if `public.products` exists).

### Table 2: `public.customization_sessions` (**11 Columns**)
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` (NOT NULL)
- `template_id UUID NOT NULL REFERENCES public.personalization_templates(id) ON DELETE RESTRICT`
- `token_hash VARCHAR(64) UNIQUE NOT NULL`
- `current_step VARCHAR(50) NOT NULL DEFAULT 'pet_type'`
- `answers JSONB NOT NULL DEFAULT '{}'::jsonb`
- `uploaded_assets JSONB NOT NULL DEFAULT '[]'::jsonb`
- `preview_artifact_path TEXT NULL`
- `status VARCHAR(30) NOT NULL DEFAULT 'draft'`
- `expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days')`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- *Constraints:*
  - Primary Key: `customization_sessions_pkey` on `(id)` (Constraint-enforcing index automatically created).
  - Unique Constraint: `customization_sessions_token_hash_key` on `(token_hash)` (Constraint-enforcing index automatically created).
  - Inbound Foreign Key: `customization_sessions_template_id_fkey` references `public.personalization_templates(id)` ON DELETE RESTRICT.
  - Check Constraint: `chk_customization_session_status` CHECK `(status IN ('draft', 'preview_generated', 'checkout_pending', 'converted', 'abandoned', 'expired'))`.

### Table 3: `public.order_customizations` (**15 Columns**)
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` (NOT NULL)
- `order_id UUID NOT NULL`
- `session_id UUID NOT NULL REFERENCES public.customization_sessions(id) ON DELETE RESTRICT`
- `rendered_artifact_path TEXT NULL`
- `render_status VARCHAR(30) NOT NULL DEFAULT 'pending'`
- `render_attempts INT NOT NULL DEFAULT 0`
- `render_error_log TEXT NULL`
- `runtime_qel_results JSONB NOT NULL DEFAULT '{}'::jsonb`
- `download_token_hash VARCHAR(64) UNIQUE NOT NULL`
- `download_count INT NOT NULL DEFAULT 0`
- `download_expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '90 days')`
- `revoked_at TIMESTAMPTZ NULL`
- `revocation_reason VARCHAR(100) NULL`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- *Constraints:*
  - Primary Key: `order_customizations_pkey` on `(id)` (Constraint-enforcing index automatically created).
  - Unique Constraint: `uq_order_customization_order` on `(order_id)` (Constraint-enforcing index automatically created).
  - Unique Constraint: `order_customizations_download_token_hash_key` on `(download_token_hash)` (Constraint-enforcing index automatically created).
  - Inbound Foreign Key: `order_customizations_session_id_fkey` references `public.customization_sessions(id)` ON DELETE RESTRICT.
  - Outbound Foreign Key (Conditional): `fk_order_customizations_order` on `order_id` references `public.orders(id)` ON DELETE CASCADE (Created only if `public.orders` exists).
  - Check Constraint: `chk_order_customization_status` CHECK `(render_status IN ('pending', 'processing', 'completed', 'failed', 'qel_rejected', 'refunded', 'revoked'))`.

---

## 2. Index Classification & Inventory

| Index Name | Table | Columns / Expressions | Classification | Creation Mode |
|---|---|---|---|---|
| `personalization_templates_pkey` | `personalization_templates` | `(id)` | Primary Key Index | Automatic (PostgreSQL constraint engine) |
| `uq_personalization_template_version` | `personalization_templates` | `(product_id, version)` | Unique Constraint Index | Automatic (PostgreSQL constraint engine) |
| `customization_sessions_pkey` | `customization_sessions` | `(id)` | Primary Key Index | Automatic (PostgreSQL constraint engine) |
| `customization_sessions_token_hash_key`| `customization_sessions` | `(token_hash)` | Unique Constraint Index | Automatic (PostgreSQL constraint engine) |
| `order_customizations_pkey` | `order_customizations` | `(id)` | Primary Key Index | Automatic (PostgreSQL constraint engine) |
| `uq_order_customization_order` | `order_customizations` | `(order_id)` | Unique Constraint Index | Automatic (PostgreSQL constraint engine) |
| `order_customizations_download_token_hash_key` | `order_customizations` | `(download_token_hash)` | Unique Constraint Index | Automatic (PostgreSQL constraint engine) |
| `idx_customization_sessions_token_hash`| `customization_sessions` | `(token_hash)` | Secondary Performance Index | Explicit `CREATE INDEX IF NOT EXISTS` (Line 316) |
| `idx_customization_sessions_template_id` | `customization_sessions` | `(template_id)` | Secondary FK Index | Explicit `CREATE INDEX IF NOT EXISTS` (Line 317) |
| `idx_customization_sessions_expires_at` | `customization_sessions` | `(expires_at)` WHERE `status = 'draft'` | Partial Performance Index | Explicit `CREATE INDEX IF NOT EXISTS` (Line 318) |
| `idx_order_customization_order` | `order_customizations` | `(order_id)` | Secondary Query Index | Explicit `CREATE INDEX IF NOT EXISTS` (Line 347) |
| `idx_order_download_token_hash` | `order_customizations` | `(download_token_hash)` | Secondary Security Index | Explicit `CREATE INDEX IF NOT EXISTS` (Line 348) |

---

## 3. Trigger Function, Triggers & Policies

* **Trigger Function:** `public.m13_set_updated_at()` (Lines 68–75)
  - Dedicated 0-argument PL/pgSQL function setting `NEW.updated_at = now()`.
* **Triggers (3):**
  - `trg_personalization_templates_updated_at` on `personalization_templates` (Lines 438–441).
  - `trg_customization_sessions_updated_at` on `customization_sessions` (Lines 465–468).
  - `trg_order_customizations_updated_at` on `order_customizations` (Lines 491–494).
* **Row Level Security Policies (4) (Zero `TO public` fallback):**
  - `"Public read active templates"` on `personalization_templates` FOR SELECT TO `anon, authenticated` (`USING (is_active = true)`) (Lines 558–562).
  - `"Service role full access on personalization_templates"` FOR ALL TO `service_role` (`USING (true) WITH CHECK (true)`) (Lines 586–589).
  - `"Service role full access on customization_sessions"` FOR ALL TO `service_role` (`USING (true) WITH CHECK (true)`) (Lines 612–615).
  - `"Service role full access on order_customizations"` FOR ALL TO `service_role` (`USING (true) WITH CHECK (true)`) (Lines 638–641).

---

## 4. Destructive Operations & Shared Object Analysis

1. **Destructive Operations in Migration:**
   - Zero `DROP` or `TRUNCATE` statements exist in forward migration.
   - Privileges explicitly revoked from `anon` and `authenticated` on `customization_sessions` and `order_customizations` to enforce security boundary.
2. **Rollback Ownership Safety (F1 & F2 Reconciled):**
   - Triggers verified against procedure OID of `m13_set_updated_at()` AND function existence before dropping; aborts safely on clash or missing function.
   - Policies verified against M13 command, exact role arrays, and qualifiers before dropping; aborts safely on clash or altered roles.
   - All tables dropped via `DROP TABLE ... RESTRICT` (0 `CASCADE`).
   - Function `public.m13_set_updated_at()` dropped via `RESTRICT` only after confirming zero external trigger dependencies.
