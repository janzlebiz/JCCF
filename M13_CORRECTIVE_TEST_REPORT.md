# JCCF M13 — Corrective Hardening Test Report
**Document ID:** `JCCF-M13-CORRECTIVE-TEST-REPORT`
**Date:** November 13, 2026
**PostgreSQL Version:** Disposable `PostgreSQL 17.11` (`127.0.0.1:5438`, destroyed after execution)
**Test Databases:** `m13_harden_test_main`, `m13_harden_test_equiv`, `m13_harden_test_fail`, `m13_harden_test_lt`, `m13_harden_test_st`, `m13_harden_test_mid`, `m13_harden_test_dc` (disposable; zero production impact)
**Test Command:** `python tests/test_m13_production_hardening_postgres.py`
**Exit Code:** `0`
**Summary:** `TOTAL HARDENING INTEGRATION TESTS: 20 | PASSED: 20 | FAILED: 0 | SKIPPED: 0`

---

## 1. Executed Test Cases (`20/20 PASS`)

| Test ID | Category | Result | Observed Evidence |
|---|---|---|---|
| `D1-FUNC-SEC` | Function Security | **PASS** | `prosecdef = False`, `proconfig = ['search_path=pg_catalog']`, body intact, `proacl = {postgres=X/postgres}`, `PUBLIC`/`anon`/`authenticated`/`service_role` `EXECUTE = False`, `postgres` `EXECUTE = True` |
| `D2-TRG-TPL` | Trigger Regression | **PASS** | `personalization_templates`: `updated_at` advanced (`13:16:02.701669` $\rightarrow$ `14:16:02.701669`) under `SET LOCAL ROLE service_role` (without direct `EXECUTE`); `version` unchanged; rolled back |
| `D2-TRG-SESS` | Trigger Regression | **PASS** | `customization_sessions`: `updated_at` advanced under `SET LOCAL ROLE service_role`; `token_hash` unchanged; rolled back |
| `D2-TRG-ORD` | Trigger Regression | **PASS** | `order_customizations`: `updated_at` advanced under `SET LOCAL ROLE service_role`; `download_token_hash` unchanged; rolled back |
| `D3-INDEX` | Index Verification | **PASS** | `idx_order_customizations_session_id`, `indisvalid = True`, `indisready = True`, indexed cols `['session_id']` |
| `D4-IDEMPOTENT` | Idempotency | **PASS** | Re-running hardening migration succeeds; `session_id` index count = `1` (no duplicate) |
| `D4-EQUIV-SKIP` | Idempotency | **PASS** | Pre-existing valid covering index skips creating duplicate `idx_order_customizations_session_id` (`count = 0`) |
| `D6-ROLLBACK` | Rollback | **PASS** | `proconfig = None`, sorted ACL `['=X/postgres', 'anon=X/postgres', 'authenticated=X/postgres', 'postgres=X/postgres', 'service_role=X/postgres']`, `idx_cnt = 0`, `tables = 3` |
| `D5-01-MISSING-FUNC` | Failure / Guard | **PASS** | Aborted cleanly (`Expected 1 public.m13_set_updated_at() function, found 0`); 0 partial changes |
| `D5-02-WRONG-SIG` | Failure / Guard | **PASS** | Aborted cleanly (`Function signature/mode mismatch (nargs=1...)`); 0 partial changes |
| `D5-03-WRONG-SECDEF` | Failure / Guard | **PASS** | Aborted cleanly (`Function signature/mode mismatch (secdef=t)`); 0 partial changes |
| `D5-04-MISSING-TRG` | Failure / Guard | **PASS** | Aborted cleanly (`Expected 3 M13 triggers..., found 2`); 0 partial changes |
| `D5-05-TRG-OTHER-FN` | Failure / Guard | **PASS** | Aborted cleanly (`Expected 3 M13 triggers..., found 2`); 0 partial changes |
| `D5-06-MISSING-FK` | Failure / Guard | **PASS** | Aborted cleanly (`Expected validated FK order_customizations_session_id_fkey...`); 0 partial changes |
| `D5-07-WRONG-FK` | Failure / Guard | **PASS** | Aborted cleanly (`Expected validated FK ... ON DELETE RESTRICT`); 0 partial changes |
| `D5-08-IDX-COLLISION` | Failure / Guard | **PASS** | Aborted cleanly (`Index idx_order_customizations_session_id exists with incompatible definition`); 0 partial changes |
| `D5-09-LOCK-TIMEOUT` | Failure / Timeout | **PASS** | `canceling statement due to lock timeout`; `proconfig = None` |
| `D5-10-STMT-TIMEOUT` | Failure / Timeout | **PASS** | `canceling statement due to statement timeout`; `proconfig = None` |
| `D5-11-MID-TX-ROLLBACK` | Failure / Atomicity | **PASS** | `division by zero`; earlier `ALTER FUNCTION` rolled back (`proconfig = None`) |
| `D5-12-CLIENT-DISCONNECT` | Failure / Disconnect | **PASS** | Client terminated mid-tx; server rolled back (`proconfig = None`) |

---

## 2. Cleanup Evidence

Disposable PostgreSQL 17.11 cluster (`$env:TEMP\pgsql17_harden5`) was stopped (`pg_ctl stop -m immediate`) and deleted along with `$env:TEMP\pgsql17_harden5.zip` immediately after test completion.

