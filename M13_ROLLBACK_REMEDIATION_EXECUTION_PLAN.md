# M13 Rollback Remediation — Execution Plan

**Target Environment:** JCCF Production Supabase Project `ammsjbcpbspisbyynaga` (`ap-northeast-2`, PostgreSQL 17.11)
**Authorization Status:** **NOT AUTHORIZED** (Preparation & Review Only)
**Execution Method:** Official persistent interactive `psql` session using `\i` against verified SHA-256 SQL artifacts.

---

## 1. Approved Artifacts & SHA-256 Checksums

| Role | File Path | SHA-256 (CRLF) |
| :--- | :--- | :--- |
| Forward Remediation | `migrations/20261113_2200_m13_rollback_provenance_fix.sql` | `561779C187F53EB2EE03FA0D3814DEE1CC8197C2F99A967ABC5C6DE65EED7976` |
| Rollback Remediation | `migrations/20261113_2200_m13_rollback_provenance_fix_rollback.sql` | `7F550EC266E203F8AE9664C376A194DD3719F1A95BA9F7381AA03CA8F5DF01D6` |

*Historical artifacts (`20261112_001_*` and `20261113_1335_*`) remain unmodified.*

---

## 2. Pre-Execution Requirements (Before Any Production Run)

1. Obtain explicit written owner authorization for the remediation forward migration.
2. Verify local file SHA-256 hashes match Section 1 exactly before opening `psql`.
3. Enforce a production schema-change freeze during preflight, execution, and post-execution verification.
4. Confirm zero lingering active or idle-in-transaction DDL sessions on `ammsjbcpbspisbyynaga` (`pg_stat_activity`).
5. Inspect current live state of `public.order_customizations` indexes (`pg_indexes` / `pg_index`) to know whether `idx_order_customizations_session_id` already exists (e.g., created by `20261113_1335_m13_production_hardening.sql`) or is absent.

---

## 3. Forward Execution Procedure (When Explicitly Authorized)

1. Connect via persistent interactive `psql` session to `ammsjbcpbspisbyynaga`.
2. Verify `\echo :AUTOCOMMIT` and session settings; run `\set ON_ERROR_STOP on`.
3. Execute:
   ```sql
   \i migrations/20261113_2200_m13_rollback_provenance_fix.sql
   ```
4. **Expected outcomes:**
   - **Case A (Index absent):** Creates `public.idx_order_customizations_session_id`, creates `m13_internal.migration_index_provenance`, and records `created_by_migration = true` with live `table_oid`, `index_oid`, and `index_def`.
   - **Case B (Exact or equivalent index already exists):** Preserves the existing index and skips creating `m13_internal.migration_index_provenance` (zero ownership claimed over pre-existing indexes).
   - **Case C (Incompatible index or missing M13 prerequisites):** Transaction aborts cleanly with zero mutations.
5. **Transaction Failure Protocol:** If `lock_timeout` (`5s`), `statement_timeout` (`30s`), or preflight error aborts the transaction, confirm `ROLLBACK` / clean session state (`pg_stat_activity`) before any retry or inspection.

---

## 4. Rollback Procedure (Only If Separately Authorized)

1. Execute only upon explicit owner authorization for rollback:
   ```sql
   \i migrations/20261113_2200_m13_rollback_provenance_fix_rollback.sql
   ```
2. **Expected outcomes:**
   - If valid provenance exists and live `index_oid`, `table_oid`, and `index_def` match, drops `public.idx_order_customizations_session_id` and removes `m13_internal`.
   - If provenance is absent (because the index pre-existed) or any OID/definition check fails, aborts fail-closed without dropping any index.
   - *Note:* If `20261113_1335_m13_production_hardening.sql` was previously applied and created `idx_order_customizations_session_id` before `20261113_2200`, `20261113_2200` treats that index as pre-existing and preserves it; `20261113_1335_m13_production_hardening_rollback.sql` remains untouched as a historical artifact.
