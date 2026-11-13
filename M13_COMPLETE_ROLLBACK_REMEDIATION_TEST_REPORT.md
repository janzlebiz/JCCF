# M13 Complete Rollback Remediation — Test Report

**Repository:** `https://github.com/janzlebiz/JCCF`
**Branch:** `main`
**Engine:** PostgreSQL 17.11 (`x86_64-windows`, `msvc-19.44.35228`, 64-bit, disposable local cluster on `127.0.0.1:5439`)
**Production Project (`ammsjbcpbspisbyynaga`):** Zero connections, zero mutations.

---

## 1. Suite Execution Summary

| Suite | Command | Total | Passed | Failed | Skipped | Exit Code |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| `tests/test_m13_complete_rollback_chain_postgres.py` | `python tests/test_m13_complete_rollback_chain_postgres.py` | 33 | 33 | 0 | 0 | `0` |
| `tests/test_m13_rollback_provenance_postgres.py` | `python tests/test_m13_rollback_provenance_postgres.py` | 20 | 20 | 0 | 0 | `0` |
| `tests/test_m13_production_hardening_postgres.py` | `python tests/test_m13_production_hardening_postgres.py` | 20 | 20 | 0 | 0 | `0` |
| `tests/test_migration_postgres_integration.py` | `python tests/test_migration_postgres_integration.py` | 26 | 26 | 0 | 0 | `0` |
| `tests/test_migration_scenarios.py` | `python tests/test_migration_scenarios.py` | 12 | 12 | 0 | 0 | `0` |
| **Total** | | **111** | **111** | **0** | **0** | **`0`** |

---

## 2. `tests/test_m13_complete_rollback_chain_postgres.py` Actual Executed Tests (33/33 PASS)

### Provenance & Ownership (`RP-01` through `RP-20`)
- `RP-01`: Index absent before forward migration -> creates index and records provenance (`PASS`).
- `RP-02`: Exact-name index exists before migration -> preserved (`oid_before=16603, oid_after=16603, prov_tbl=None`) (`PASS`).
- `RP-03`: Equivalent index under another name -> preserved (`equiv_oid=16707`), no ownership claimed (`PASS`).
- `RP-04`: Incompatible same-name index collision -> aborted cleanly (`proconfig=None`) (`PASS`).
- `RP-05`: Provenance row missing -> rollback preserves index (`PASS`).
- `RP-06`: Wrong `index_oid` (`999999`) -> rollback aborts and preserves index (`PASS`).
- `RP-07`: Same-name index dropped and recreated -> rollback detects missing recorded OID and preserves replacement (`PASS`).
- `RP-08`: Genuine `DROP TABLE public.order_customizations CASCADE;` and table recreation -> detects `Table OID mismatch (recorded=17216, live=17265)` and preserves recreated table and index (`PASS`).
- `RP-09`: Index renamed (`idx_renamed_by_ops`) -> rollback detects mismatch and preserves renamed index (`PASS`).
- `RP-10`: Provenance tampered (`created_by_migration = FALSE`) -> rollback fails closed and preserves index (`PASS`).
- `RP-11`: Forward migration fails mid-transaction (`1/0`) -> atomic rollback, zero index or provenance state (`PASS`).
- `RP-12`: Forward migration rerun -> idempotent (`oid=17714, prov_cnt=1`) (`PASS`).
- `RP-13`: Rollback rerun -> safe idempotent behavior (`PASS`).
- `RP-14`: Valid ownership rollback -> removes only owned index and own row, preserves unrelated provenance (`['other_mig']`) (`PASS`).
- `RP-15`: Pre-existing index rollback -> preserves pre-existing index (`preserved_oid=18053`) (`PASS`).
- `RP-16`: Conflicting ownership records -> rollback aborts safely and preserves index (`PASS`).
- `RP-17`: Wrong `owning_migration` identifier -> rollback aborts safely and preserves index (`PASS`).
- `RP-18`: Wrong `table_name` in provenance -> rollback aborts safely and preserves index (`PASS`).
- `RP-19`: Provenance table structure unexpectedly modified (`DROP COLUMN index_def`) -> rollback aborts safely (`PASS`).
- `RP-20`: Application/non-owner roles (`anon`, `authenticated`, `service_role`) denied access to `m13_internal.migration_index_provenance` (`PASS`).

### Full Sequence Scenarios (`SEQ-01` through `SEQ-07`)
- `SEQ-01`: Clean DB full forward (`20261112_001` -> `20261113_2345`) + full reverse (`20261113_2345_rollback` -> `20261112_001_rollback`) removes all M13/provenance objects and preserves unrelated objects (`PASS`).
- `SEQ-02`: Pre-existing exact-name index survives full forward + `20261113_2345_rollback` (`pre_oid=18835, post_oid=18835, proconfig=None`) (`PASS`).
- `SEQ-03`: Pre-existing equivalent index survives full forward + `20261113_2345_rollback` (`equiv_oid=18939`) (`PASS`).
- `SEQ-04`: Historical `20261113_1335` index without provenance survives `20261113_2345` + `20261113_2345_rollback` (`historical_oid_preserved=19043`) (`PASS`).
- `SEQ-05`: Dropped/recreated replacement index survives `20261113_2345_rollback` (`replacement_oid=19161`) (`PASS`).
- `SEQ-06`: Dropped/recreated table and index survive `20261113_2345_rollback` (`repl_tbl_oid=19275`) (`PASS`).
- `SEQ-07`: Simulated mid-transaction failure rolls back atomically with zero partial provenance (`PASS`).

### SQL Timeout & Event-Trigger Tests (`TIMEOUT-01`..`05`, `RLS-AUTO-ENABLE-EVENT-TRIGGER`)
- `TIMEOUT-01`: `SET LOCAL lock_timeout = '5s';` verified in both forward and rollback SQL (`PASS`).
- `TIMEOUT-02`: `SET LOCAL statement_timeout = '30s';` verified in both forward and rollback SQL (`PASS`).
- `TIMEOUT-03`: Lock contention without harness timeout aborts via SQL `lock_timeout` (`pgcode=55P03, elapsed=5.03s, err=canceling statement due to lock timeout`) (`PASS`).
- `TIMEOUT-04`: Long-running statement without harness timeout aborts via SQL `statement_timeout` (`pgcode=57014, elapsed=30.04s, prov=None, err=canceling statement due to statement timeout`) (`PASS`).
- `TIMEOUT-05`: `SET LOCAL` settings do not persist into subsequent transactions (`lock_timeout: 0->0, statement_timeout: 0->0`) (`PASS`).
- `RLS-AUTO-ENABLE-EVENT-TRIGGER`: Simulated `rls_auto_enable()` `ddl_command_end` event trigger compatibility verified across full forward and reverse sequence (`rls_on=True, evt_preserved=1`) (`PASS`).
