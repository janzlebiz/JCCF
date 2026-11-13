# M13 Rollback Provenance Remediation — Test Report

**Repository:** `https://github.com/janzlebiz/JCCF`
**Branch:** `main`
**Baseline Commit:** `bb1221c70cac3db811803a9f167904edc3f84125`
**Target Engine:** PostgreSQL 17.11 (`x86_64-windows`, `msvc-19.44.35228`, 64-bit, disposable ephemeral cluster on `127.0.0.1:5439`)
**Production Target:** `ammsjbcpbspisbyynaga` (`ap-northeast-2`) — **NOT TOUCHED** (zero production connections, DDL, DML, DCL, or migration-history edits)

---

## 1. Artifact SHA-256 Inventory Verified Under Test

| Artifact | SHA-256 (On-Disk CRLF) | Status |
| :--- | :--- | :--- |
| `migrations/20261112_001_personalization_engine.sql` | `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E` | Unchanged |
| `migrations/20261112_001_personalization_engine_rollback.sql` | `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4` | Unchanged |
| `migrations/20261113_1335_m13_production_hardening.sql` | `4F74EC3B6660B49367639B0AD1981AA637F1D130F00C8E66163F46B23594A5EA` | Unchanged |
| `migrations/20261113_1335_m13_production_hardening_rollback.sql` | `3D10A9C212250C270FC4E337B1539ED51B78BD0D42C29B09AD9D6F62AE8347C6` | Unchanged |
| `migrations/20261113_2200_m13_rollback_provenance_fix.sql` | `561779C187F53EB2EE03FA0D3814DEE1CC8197C2F99A967ABC5C6DE65EED7976` | New (Remediation Forward) |
| `migrations/20261113_2200_m13_rollback_provenance_fix_rollback.sql` | `7F550EC266E203F8AE9664C376A194DD3719F1A95BA9F7381AA03CA8F5DF01D6` | New (Remediation Rollback) |

---

## 2. Test Suite Execution Summary

All four test suites were executed sequentially against a fresh, disposable PostgreSQL 17.11 cluster (`127.0.0.1:5439`, isolated database per scenario) and cleaned up immediately upon completion.

| Suite | Tests | Passed | Failed | Exit Code |
| :--- | :---: | :---: | :---: | :---: |
| `tests/test_m13_rollback_provenance_postgres.py` | 20 | 20 | 0 | `0` |
| `tests/test_m13_production_hardening_postgres.py` | 20 | 20 | 0 | `0` |
| `tests/test_migration_postgres_integration.py` | 26 | 26 | 0 | `0` |
| `tests/test_migration_scenarios.py` | 12 | 12 | 0 | `0` |
| **Total** | **78** | **78** | **0** | **`0`** |

---

## 3. Provenance & Sequence Test Breakdown (`tests/test_m13_rollback_provenance_postgres.py`)

| Test ID | Scenario | Observed Result |
| :--- | :--- | :--- |
| `RP-01` | Forward migration creates missing `idx_order_customizations_session_id` and records provenance (`created_by_migration = true`, `index_oid`, `table_oid`, `index_def`). | PASS |
| `RP-ACL-ANON` | `anon` role is denied access to `m13_internal` schema and `m13_internal.migration_index_provenance`. | PASS |
| `RP-ACL-AUTHENTICATED` | `authenticated` role is denied access to `m13_internal` schema and `m13_internal.migration_index_provenance`. | PASS |
| `RP-12` | Idempotent rerun of `20261113_2200_m13_rollback_provenance_fix.sql` preserves single provenance row and single index. | PASS |
| `RP-14` | Clean rollback drops migration-owned index, removes provenance table, and drops `m13_internal` schema. | PASS |
| `RP-13` | Rollback when `idx_order_customizations_session_id` was created by migration drops only that index while preserving all 5 original M13 indexes. | PASS |
| `RP-02` | Pre-existing exact-named index before forward migration skips creation and records no provenance table. | PASS |
| `RP-15` | Rollback after pre-existing exact-named index preserves the pre-existing index untouched. | PASS |
| `RP-03` | Pre-existing equivalent index under another name preserves it, skips creation, and rollback preserves it. | PASS |
| `RP-04` | Incompatible same-named index aborts forward preflight cleanly with zero mutations. | PASS |
| `RP-05` | Rollback when `m13_internal.migration_index_provenance` is missing preserves existing index (`idx_present=True`). | PASS |
| `RP-06` | Rollback with stale/nonexistent `index_oid` (`999999`) aborts fail-closed and preserves same-named index. | PASS |
| `RP-07` | Rollback after index drop and recreation (same name, different OID) aborts fail-closed and preserves recreated index. | PASS |
| `RP-08` | Rollback after table recreation (`table_oid` mismatch) aborts fail-closed and preserves index. | PASS |
| `RP-09` | Rollback after index rename / `index_def` mismatch aborts fail-closed and preserves index. | PASS |
| `RP-10` | Rollback when `created_by_migration = false` or metadata fails integrity check aborts fail-closed and preserves all indexes. | PASS |
| `RP-11` | Mid-transaction failure rolls back atomically with zero partial provenance or index state. | PASS |
| `RP-16` | `lock_timeout` contention cancels statement cleanly without leaving partial provenance or index changes. | PASS |
| `PHASE-F1-FULL-SEQ` | Full forward sequence (`20261112_001` -> `20261113_1335` -> `20261113_2200`) and reverse rollback sequence (`20261113_2200_rollback` -> `20261113_1335_rollback` -> `20261112_001_rollback`) leaves zero M13/provenance objects. | PASS |
| `PHASE-F2-EQUIV-SEQ` | Full sequence with pre-existing equivalent index preserves the pre-existing equivalent index across both hardening and provenance rollbacks. | PASS |

---

## 4. Regression Suite Summaries

- **`tests/test_m13_production_hardening_postgres.py`:** All 20 tests passed (`D1-FUNC-SEC`, `D2-TRG-TPL`, `D2-TRG-SESS`, `D2-TRG-ORD`, `D3-INDEX`, `D4-IDEMPOTENT`, `D6-ROLLBACK`, `D4-EQUIV-SKIP`, `D5-01` through `D5-12`), confirming `20261113_1335_m13_production_hardening.sql` and its rollback remain intact.
- **`tests/test_migration_postgres_integration.py`:** All 26 tests (`PG-INT-01` through `PG-INT-26`) passed on PostgreSQL 17.11, confirming `20261112_001_personalization_engine.sql` and its rollback remain intact.
- **`tests/test_migration_scenarios.py`:** All 12 static AST/SQL scenario scans (`M13-SCENARIO-01` through `M13-SCENARIO-12`) passed.

---

## 5. Verification Verdict

**TEST VERDICT: PASS (78/78 tests passed, 0 failed, exit code 0 across all 4 suites).**
