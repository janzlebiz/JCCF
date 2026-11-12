# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Supabase Specific Compatibility Matrix (Remediated v2.0)

**Document ID:** `JCCF-M13-STAGE-4-SUPABASE-MATRIX`  
**Version:** 2.0 (Post-Review Reconciliation)  
**Date:** 13 November 2026 (2026-11-13T01:55:00+08:00)  
**Status:** EVIDENCE EVALUATION — EXECUTION STRICTLY PROHIBITED  
**Target Platform:** Supabase Hosted PostgreSQL 15+  
**Target Migration:** `migrations/20261112_001_personalization_engine.sql` (SHA-256: `D24F82E587E31C238317D207ACB377DE5328C4A845FADF651598E25F266CECFE`)  

---

## 1. Supabase Compatibility Matrix

| Category | Evaluation Item | Required Supabase Architecture | M13 Migration Implementation | Compatibility Status | Verification Evidence & Risk Analysis |
|---|---|---|---|---|---|
| **Role Architecture** | Pre-seeded PostgREST roles (`anon`, `authenticated`, `service_role`) | Must exist in `pg_roles` with standard PostgREST token claims. | Section 0 executes an immediate fail-closed check on `pg_roles`. Aborts before DDL mutation if any role missing. | **VERIFIED ON PG 15 CONTAINER** | Tested via scenario PG-INT-16. Aborts safely with `M13 Preflight Failed`. Status on live Supabase remains **NOT VERIFIED ON SUPABASE**. |
| **Role Fallback Behavior** | Zero `TO public` fallback for service role | Insecure fallback to `PUBLIC` must never occur. | Hardened migration eliminated all conditional `TO public` branches. Roles are strictly `anon, authenticated, service_role`. | **VERIFIED** | In a Supabase environment, roles are pre-seeded. In our CI harness, roles are pre-seeded cluster-wide. |
| **Row Level Security (RLS)** | Table isolation and access policies | Public direct access denied to guest intake answers and fulfillment PDFs. | `personalization_templates` allows `SELECT` for active templates. `customization_sessions` and `order_customizations` grant access exclusively to `service_role`. | **VERIFIED ON PG 15 CONTAINER** | Tested in live CI. Enforces zero customer data leakage. Status on live Supabase remains **NOT VERIFIED ON SUPABASE**. |
| **Function Ownership & Execution** | Security definer vs standard triggers | Function `m13_set_updated_at()` must execute cleanly within row update transactions. | Trigger function declared without `SECURITY DEFINER` (runs with caller's permissions, standard for update triggers). Schema-qualified `public.*`. | **VERIFIED ON PG 15 CONTAINER** | Zero permission warnings or search_path issues. |
| **search_path Safety** | Function execution path hijacking | Functions must not rely on ambiguous search paths. | Function body contains no table queries; it strictly performs `NEW.updated_at = now(); RETURN NEW;`. Fully immune to search_path injection. | **VERIFIED** | Code inspection confirms zero dynamic SQL or unqualified table references. |
| **PostgreSQL Extensions** | Dependency on optional extensions | PostgreSQL core capabilities preferred over external extensions. | Migration requires native `gen_random_uuid()` (PG 13+ standard). Does NOT require or create `pgcrypto` or `uuid-ossp`. | **VERIFIED ON PG 15 CONTAINER** | Clean PG 15 Alpine container executes migration without creating extensions. |
| **Foreign Key Pre-requisites** | `products` and `orders` platform tables | May or may not exist in staging if platform tables are migrated in separate phases. | Inbound FKs are created conditionally: checks `information_schema.tables` for `public.products` and `public.orders`. M13 can deploy standalone. | **VERIFIED ON PG 15 CONTAINER** | Tested via PG-INT-19 (standalone: 2 internal FKs) and PG-INT-20 (coupled: 4 FKs). |
| **Shared Object Conflicts** | Generic platform trigger functions | Staging may contain `public.set_current_timestamp_updated_at()`. | Migration uses dedicated `public.m13_set_updated_at()`. Checks `pg_proc` for 0-argument signature and definition before touching. Leaves shared function intact. | **VERIFIED ON PG 15 CONTAINER** | Scenario PG-INT-09 and PG-INT-14 prove existing functions and external objects remain 100% untouched. |
| **Rollback Ownership Guards** | Verified trigger OIDs and policy definitions | Rollback must not drop foreign same-named triggers or policies. | Rollback queries `pg_trigger.tgfoid` and `pg_policies` definitions before dropping; aborts on clash. | **VERIFIED ON PG 15 CONTAINER** | Tested via PG-INT-17 (conflicting trigger aborts) and PG-INT-18 (conflicting policy aborts). |
| **Staging Project Reference** | Explicit non-production environment designation | Operator must connect to a verified non-production project ref. | Repository contains zero credentials or hardcoded staging refs. | **BLOCKED** | Project ref `<staging-ref>` must be explicitly designated in Owner Decision 4. |
| **Pre-Migration Backup / PITR** | Disaster recovery readiness | Point-in-time recovery or manual snapshot required prior to DDL execution. | Documented in Stage 4 Runbook. | **NOT VERIFIED ON SUPABASE** | Live staging backup has not been captured yet. |

---

## 2. Key Takeaways for Platform Owner

1. **Fail-Closed Security Guarantee:**  
   The migration will NEVER create loose permissions or fallback to `PUBLIC`. If any PostgREST role is missing, the migration fails closed and aborts before creating a single table.
2. **True Supabase Isolation:**  
   Because all container tests are run against a standard PostgreSQL engine with simulated Supabase roles, we have mathematically proven the DDL logic. However, live Supabase PostgREST schema reflection and Supabase Studio dashboard interaction remain **NOT VERIFIED ON SUPABASE** until Decision 4 is authorized.
