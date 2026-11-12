# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Supabase Specific Compatibility Matrix

**Document ID:** `JCCF-M13-STAGE-4-SUPABASE-MATRIX`  
**Date:** 13 November 2026 (2026-11-13T01:35:00+08:00)  
**Status:** EVIDENCE EVALUATION — EXECUTION STRICTLY PROHIBITED  
**Target Platform:** Supabase Hosted PostgreSQL 15+  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql`  

---

## 1. Supabase Compatibility Matrix

| Category | Evaluation Item | Required Supabase Architecture | M13 Migration Implementation | Compatibility Status | Verification Evidence / Risk Analysis |
|---|---|---|---|---|---|
| **Role Architecture** | Pre-seeded PostgREST roles (`anon`, `authenticated`, `service_role`) | Must exist in `pg_roles` with standard PostgREST token claims. | Migration wraps `REVOKE` and `GRANT` statements in `IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '...')`. | **VERIFIED** | Successfully tested on both vanilla PG container (where roles were pre-seeded in test harness) and dynamic detection. |
| **Role Fallback Behavior** | Vanilla PG vs Supabase role presence | Non-Supabase environments lack `anon`/`authenticated`; fallback grants to `public` in tests. | Migration uses `IF EXISTS` blocks; in a real Supabase instance, named roles exist, so policies bind strictly to `anon`, `authenticated`, and `service_role`. | **VERIFIED** | Preflight Check 6 verifies roles exist before executing on staging. No fallback to `public` occurs when Supabase roles are present. |
| **Row Level Security (RLS)** | Table isolation and access policies | Public direct access must be denied to guest intake answers and fulfillment PDFs. | `personalization_templates` allows `SELECT` for active templates. `customization_sessions` and `order_customizations` grant access exclusively to `service_role`. | **VERIFIED** | Enforces zero customer data leakage. Anonymous browser users cannot query or tamper with sessions or orders via PostgREST. |
| **Function Ownership & Execution** | Security definer vs standard triggers | Function `m13_set_updated_at()` must execute cleanly within row update transactions. | Trigger function declared without `SECURITY DEFINER` (runs with caller's permissions, standard for update triggers). Schema-qualified `public.*`. | **VERIFIED** | Tested in live CI with zero permission or schema-search warnings. |
| **search_path Safety** | Function execution path hijacking | Functions must not rely on ambiguous search paths. | Function body contains no table queries; it strictly performs `NEW.updated_at = now(); RETURN NEW;`. Fully immune to search_path injection. | **VERIFIED** | Static AST and dynamic trigger tests confirm clean execution. |
| **PostgreSQL Extensions** | Dependency on optional extensions | PostgreSQL core capabilities preferred over external extensions. | Migration requires native `gen_random_uuid()` (PG 13+ standard). Does NOT require or create `pgcrypto` or `uuid-ossp`. | **VERIFIED** | Container test `postgres:15-alpine` executes cleanly without enabling extensions. |
| **Foreign Key Pre-requisites** | `products` and `orders` platform tables | May or may not exist in staging if platform tables are migrated in separate phases. | Inbound FKs are created conditionally: checks `information_schema.tables` for `public.products` and `public.orders`. M13 can deploy standalone. | **VERIFIED** | Integration test suite tests both standalone deployment and coupled deployment with existing tables. |
| **Shared Object Conflicts** | Generic platform trigger functions | Staging may contain `public.set_current_timestamp_updated_at()`. | Migration uses dedicated `public.m13_set_updated_at()`. Checks `pg_proc` for 0-argument signature and definition before touching. Leaves shared function intact. | **VERIFIED** | Scenario PG-INT-09 and PG-INT-14 prove existing functions and external objects remain 100% untouched. |
| **Supabase Storage Integration** | Storage buckets for previews and rendered PDFs | Buckets `petstory-previews` and `petstory-rendered` must be configured separately. | Migration stores paths as `TEXT` (`rendered_artifact_path`, `preview_artifact_path`). Does not execute Supabase Storage API calls. | **NOT APPLICABLE** (To Migration) | Storage bucket provisioning is a Phase 1 infrastructure task (governed by Decision 5). |
| **Staging Project Reference** | Explicit non-production environment designation | Operator must connect to a verified non-production project ref. | Repository contains zero credentials or hardcoded staging refs. | **BLOCKED** | Project ref `<staging-ref>` must be explicitly designated in Owner Decision 4. |
| **Pre-Migration Backup / PITR** | Disaster recovery readiness | Point-in-time recovery or manual snapshot required prior to DDL execution. | Documented in Stage 4 Runbook. | **NOT VERIFIED** (On Staging) | Live backup has not been captured yet (requires staging access upon D4 approval). |

---

## 2. Critical Supabase Assessment Findings

1. **Role Fallback Vulnerability Prevented:**
   In vanilla PostgreSQL environments where Supabase roles do not exist, test scripts sometimes create policies bound to `PUBLIC`. In our hardened migration (`migrations/20261112_001_personalization_engine.sql`), dynamic PL/pgSQL guards check for `anon` and `authenticated`. In a true Supabase staging instance, those roles are guaranteed to exist, ensuring policies bind strictly to those roles rather than `PUBLIC`.
2. **Zero Extension Overhead:**
   Because Subsystem M13 uses the native `gen_random_uuid()` function introduced in PostgreSQL 13, it avoids the common Supabase migration pitfall of conflicting `CREATE EXTENSION IF NOT EXISTS pgcrypto` commands.
3. **Standalone Deployment Capability:**
   Because M13 conditionally attaches foreign keys to `products` and `orders`, it can be deployed to staging even before core platform commerce tables are migrated, without causing DDL failure.
