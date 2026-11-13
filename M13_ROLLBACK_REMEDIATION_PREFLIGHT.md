# JCCF M13 — Rollback Remediation Preflight
**Document ID:** `JCCF-M13-ROLLBACK-PREFLIGHT`
**Date:** November 13, 2026
**Repository:** `https://github.com/janzlebiz/JCCF` (`main`)
**Baseline Commit:** `bb1221c70cac3db811803a9f167904edc3f84125`
**Working Tree Status (Pre-Edit):** Clean (`## main...origin/main`)
**Production Target (Not Touched):** `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `PostgreSQL 17.11`)

---

## 1. Baseline Artifact Hashes (Unchanged)

| Artifact | SHA-256 |
|---|---|
| `migrations/20261112_001_personalization_engine.sql` | `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E` |
| `migrations/20261112_001_personalization_engine_rollback.sql` | `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4` |
| `migrations/20261113_1335_m13_production_hardening.sql` | `4F74EC3B6660B49367639B0AD1981AA637F1D130F00C8E66163F46B23594A5EA` |
| `migrations/20261113_1335_m13_production_hardening_rollback.sql` | `3D10A9C212250C270FC4E337B1539ED51B78BD0D42C29B09AD9D6F62AE8347C6` |

---

## 2. Defect Description

1. **Current Conditional Index-Creation Behavior (`20261113_1335_m13_production_hardening.sql`):**
   * Checks `pg_index` for any valid non-partial, non-expression index on `public.order_customizations` with `session_id` as `indkey[0]`.
   * Creates `idx_order_customizations_session_id` **only** if no covering index exists; skips creation if an exact-name or equivalent index already exists.
2. **Current Unconditional Rollback Behavior (`20261113_1335_m13_production_hardening_rollback.sql`, line 49):**
   * Executes `DROP INDEX IF EXISTS public.idx_order_customizations_session_id;` unconditionally.
   * **Defect:** If `idx_order_customizations_session_id` pre-existed before the hardening migration (causing the migration to skip creation), running the rollback would erroneously drop the pre-existing index.

---

## 3. Proposed Provenance Mechanism & Authorization Restrictions

* **Mechanism:** Private, privilege-locked schema `m13_internal` + table `m13_internal.migration_index_provenance` (`REVOKE ALL` from `PUBLIC`, `anon`, `authenticated`, `service_role` + `ENABLE ROW LEVEL SECURITY` with zero application policies), recording `migration_id`, `schema_name`, `table_name`, `table_oid`, `index_name`, `index_oid`, `index_def`, `created_by_migration`, and `created_at` in the **same transaction** as index creation—and **only** when the migration actually creates the index.
* **Authorization Restrictions:** Zero production connections, DDL, DML, DCL, or migration-history edits were initiated during this phase.
