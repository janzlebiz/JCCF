# JCCF Subsystem M13 — Production Change Plan
**Document ID:** `JCCF-M13-PROD-CHANGE-PLAN`
**Document Version:** 1.3
**Date:** November 13, 2026
**Target Project:** `JCCF` (`ammsjbcpbspisbyynaga`, `ap-northeast-2`, `PostgreSQL 17.11.0.019`)
**Status:** Ready for Explicit Production Execution Release (Live DDL **NOT EXECUTED**)

---

## 1. Change Summary & Artifact Identity

| # | Change Plan Element | Specification |
|---|---|---|
| **1** | **Purpose & Scope** | Deploy M13 Interactive Personalization Engine schema (`personalization_templates`, `customization_sessions`, `order_customizations`) for PetStory 24-page PDF MVP. |
| **2** | **Target Project Ref** | `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `PostgreSQL 17.11.0.019`), via IPv4 Session Pooler (`aws-1-ap-northeast-2.pooler.supabase.com:5432`). |
| **3** | **Artifact Identities** | **Migration:** `migrations/20261112_001_personalization_engine.sql` (Commit `e624e95f74932441dfee90cad7a9cb4544f64d6d`, Blob `679f5a8086fb1070e39b7f0cef4b5b381999ce78`, SHA-256 `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`).<br>**Rollback:** `migrations/20261112_001_personalization_engine_rollback.sql` (Commit `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`, Blob `e7b1c60ef9ab5ddb96d3512262db6a700e2fc9bf`, SHA-256 `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`). |
| **4** | **Historical SQL Header** | The migration SQL header's historical wording (`PRE-IMPLEMENTATION SPECIFICATION ONLY (DO NOT APPLY AUTOMATICALLY)`) is preserved unchanged and does **not** authorize automatic execution. The current process requires manual operator execution only after explicit owner release. |
| **5** | **Production Backup Ref** | `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC` (see [M13_PRODUCTION_BACKUP_AND_RECOVERY_REPORT.md](M13_PRODUCTION_BACKUP_AND_RECOVERY_REPORT.md)). |
| **6** | **Preflight Results** | `11/11 PASS` (`PF-01`..`PF-11`, `2026-11-13T03:27:18Z–20Z`): PG 17.11, `gen_random_uuid()` OK, `anon`/`authenticated`/`service_role` present, `0` collisions (see [M13_PRODUCTION_STATE_INSPECTION_REPORT.md](M13_PRODUCTION_STATE_INSPECTION_REPORT.md)). |
| **7** | **Expected Objects** | `3` tables (`personalization_templates`, `customization_sessions`, `order_customizations`), `1` function (`public.m13_set_updated_at()`), `3` triggers, `4` RLS policies (`ENABLE ROW LEVEL SECURITY`), `2` internal FKs (`0` optional external FKs), `5` explicit secondary indexes (+ PK/unique indexes), table grants. |
| **8** | **Pre-Condition (Consumers)** | `0` customer writes, `0` active application consumers, and `0` external dependencies may exist at migration time unless separately reviewed and approved. |
| **9** | **Estimated Duration & Impact** | **Estimated** DDL duration: `< 5 seconds` under current empty-database conditions; **estimated** service disruption: minimal/none while `0` public tables and `0` active consumers exist (estimate only, not a guarantee). |

---

## 2. Official Execution Mode, Timeouts & Transaction Failure Protocol

### 2.1 Official Production Execution Mode: Persistent Interactive `psql` Session

**Selected Official Mode:** **Persistent Interactive `psql` Session** (sole authorized execution method; non-interactive `psql -v ON_ERROR_STOP=1` script mode is **not** used for production execution).

* **Rationale:** In a persistent interactive `psql` session connected to `aws-1-ap-northeast-2.pooler.supabase.com:5432` (user `postgres.ammsjbcpbspisbyynaga`, `sslmode=require`), any SQL error, `lock_timeout`, or `statement_timeout` cancels only the offending statement and places the live session into PostgreSQL's `aborted` (`25P02`) transaction state without dropping the connection. The operator observes the exact error, issues an explicit `ROLLBACK;` in the same live session, and confirms clean transaction termination before any inspection. By contrast, non-interactive `psql -v ON_ERROR_STOP=1` exits immediately (`rc=3`) on error and closes the connection, relying on backend exit cleanup.
* **Interactive Procedure:**
  1. Connect once via persistent interactive `psql` (`sslmode=require`).
  2. Run `SET lock_timeout = '5000ms';` and `SET statement_timeout = '30000ms';` and verify with `SHOW lock_timeout; SHOW statement_timeout;`.
  3. Execute the contents of `migrations/20261112_001_personalization_engine.sql` (`BEGIN;` ... `COMMIT;`) once in that session.
  4. On any error or timeout: **stop**, issue explicit `ROLLBACK;` in the same live session, confirm `ROLLBACK` output, and verify server-side cleanup (`pg_stat_activity`) before any inspection.
  5. After `COMMIT;` succeeds, run `NOTIFY pgrst, 'reload schema';` in the same session.

### 2.2 Session Timeouts (`lock_timeout` & `statement_timeout`)

```sql
SET lock_timeout = '5000ms';
SET statement_timeout = '30000ms';
```

* **`lock_timeout = '5000ms'` (5 seconds):** Prevents queuing indefinitely behind an unexpected lock holder. Cancels only the waiting statement (`ERROR: canceling statement due to lock timeout`).
* **`statement_timeout = '30000ms'` (30 seconds):** Caps per-statement execution time over the IPv4 session pooler. Cancels only the slow statement (`ERROR: canceling statement due to statement timeout`).

### 2.3 PostgreSQL Transaction Failure Protocol & Connection-Loss Handling

1. **Statement Cancellation:** `lock_timeout` or `statement_timeout` cancels only the currently running statement; it does **not** issue `ROLLBACK`.
2. **Aborted Transaction State:** Because the migration runs inside `BEGIN;` ... `COMMIT;`, any error places the live session into `aborted` (`25P02: current transaction is aborted, commands ignored until end of transaction block`).
3. **Explicit `ROLLBACK`:** In the persistent interactive session, the operator issues explicit `ROLLBACK;` to end the aborted transaction cleanly and discard all prior uncommitted DDL.
4. **Connection Termination & Server-Side Cleanup:** If the connection drops or is terminated mid-transaction before `COMMIT` confirmation, the PostgreSQL backend implicitly rolls back any uncommitted or aborted transaction on exit—unless `COMMIT;` had already completed on the server before the disconnect. **Never interpret a lost connection as proof that the migration failed or succeeded.**
5. **Mandatory Pre-Inspection / Pre-Retry Check:** Before inspecting objects or taking any further action after an error or disconnect, reconnect in a **new read-only session** and confirm zero lingering transactions remain:
   ```sql
   SELECT pid, state, xact_start, left(query, 100)
   FROM pg_stat_activity
   WHERE datname = current_database()
     AND pid <> pg_backend_pid();
   ```
   Then inspect `pg_tables` (`personalization_templates`, `customization_sessions`, `order_customizations`) and `pg_proc` (`m13_set_updated_at`): either all M13 objects committed before disconnect (proceed to `PMV-01`..`PMV-11`) or `0` M13 objects exist (record incident and request owner review).
6. **Failure Rule:** On any failure: **stop immediately**, **do not automatically retry**, and **never automatically execute rollback**.

### 2.4 Disposable PostgreSQL 17.11 Failure Test Evidence

Executed against a disposable local `PostgreSQL 17.11` cluster (port `5435`, destroyed immediately after testing; zero production impact):

| Test ID | Scenario & Method | Expected Behavior | Actual Observed Behavior | Exit Code | Cleanup & Result |
|---|---|---|---|---:|---|
| **TFT-01** | Successful `BEGIN; CREATE TABLE t_ok; COMMIT;` with `lock_timeout=5000ms`, `statement_timeout=30000ms` | Commits cleanly; table visible | `SET`, `SET`, `BEGIN`, `CREATE TABLE`, `COMMIT`; `t_ok` (`1 row`) | `0` | Clean commit — **PASS** |
| **TFT-02a** | Persistent interactive session: `BEGIN; CREATE TABLE t_err; SELECT 1/0; SELECT 1; ROLLBACK;` | Error enters `25P02` aborted state; explicit `ROLLBACK` discards `t_err` | `ERROR: division by zero`; `ERROR: current transaction is aborted...`; `ROLLBACK` (`t_err_count = 0`) | `0` | `0` objects remain — **PASS** |
| **TFT-02b** | Non-interactive `psql -v ON_ERROR_STOP=1` with `SELECT 1/0;` before `COMMIT;` | Script halts immediately, closes connection; backend rolls back `t_err2` | `ERROR: division by zero`; exited immediately without `COMMIT` | `3` | `t_err2` count = `0` — **PASS** |
| **TFT-03** | `statement_timeout = '400ms'` during `SELECT pg_sleep(2)` inside `BEGIN` | Cancels statement, enters `25P02`; explicit `ROLLBACK` discards `t_st` | `ERROR: canceling statement due to statement timeout`; `25P02`; `ROLLBACK` | `0` | `t_st_count = 0` — **PASS** |
| **TFT-04** | `lock_timeout = '400ms'` against held `ACCESS EXCLUSIVE` lock inside `BEGIN` | Cancels DDL, enters `25P02`; explicit `ROLLBACK` discards `t_lt` | `ERROR: canceling statement due to lock timeout`; `25P02`; `ROLLBACK` | `0` | `t_lt_count = 0` — **PASS** |
| **TFT-05** | Client process terminated mid-transaction before `COMMIT` | Backend detects EOF/disconnect and rolls back `t_int` | Client terminated; server cleaned up transaction | `1` | `t_int` count = `0` — **PASS** |
| **TFT-06** | Server-side `pg_terminate_backend(pid)` mid-transaction before `COMMIT` | Connection lost (`FATAL: terminating connection...`); server rolls back `t_term` | `FATAL: terminating connection due to administrator command` / `connection to server was lost` | `2` | `t_term` count = `0` — **PASS** |
| **TFT-07** | Reconnect & query `pg_stat_activity` for `state LIKE '%transaction%'` | `0` lingering active/aborted transactions | `count = 0` | `0` | Confirmed clean — **PASS** |
| **TFT-08** | Query `pg_tables` for all failed test tables (`t_err`..`t_term`) | `(0 rows)` — zero partial objects remain | `(0 rows)` | `0` | Zero partial objects — **PASS** |

---

## 3. Conditional `orders` Foreign-Key Precondition

### 3.1 Required Pre-Execution Check

Immediately before migration execution, the operator must execute this read-only check:

```sql
SELECT
    to_regclass('public.orders') AS orders_table,
    to_regclass('public.order_customizations') AS order_customizations_table;
```

* **Expected Production Result:** `orders_table = NULL` and `order_customizations_table = NULL`.
* **Stop Condition:** If either `orders_table` or `order_customizations_table` is non-NULL, **STOP immediately**. Do not silently accept a different migration path.

### 3.2 Migration-Path & `ON DELETE CASCADE` Implication

* **Why Conditional:** `migrations/20261112_001_personalization_engine.sql` (lines 363–401) conditionally adds `fk_order_customizations_order` (`order_customizations.order_id -> public.orders(id) ON DELETE CASCADE`) only if `public.orders` exists, allowing M13 to deploy standalone before a core `orders` table exists.
* **When `public.orders` is Absent (`NULL`):** The conditional block is skipped; only the 2 internal M13 FKs (`customization_sessions.template_id -> personalization_templates(id) ON DELETE RESTRICT`, `order_customizations.session_id -> customization_sessions(id) ON DELETE RESTRICT`) are created.
* **If `public.orders` Exists:** The migration would create `fk_order_customizations_order` with `ON DELETE CASCADE`. Deleting an `orders` row would cascade-delete the linked `order_customizations` fulfillment record (affecting audit/download/revocation history and retention assumptions). Because this changes the data-deletion dependency graph, any change to this precondition requires renewed architectural review and owner approval.
* **Post-Migration Check:** Confirm via `pg_constraint` that `fk_order_customizations_order` is **absent** (matching `orders_table = NULL`) and only the 2 expected internal `RESTRICT` FKs exist. An unexpected FK result is a failed verification requiring investigation.

---

## 4. Ordered Production Operator Execution Procedure

Execute steps in exact numerical order. If any step fails: **stop immediately**, **do not automatically retry**, **do not automatically execute rollback**, inspect actual production state using a new read-only connection, record the incident, and request owner review.

1. Verify repository URL (`https://github.com/janzlebiz/JCCF`), branch (`main`), and exact approved commit.
2. Verify migration (`9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`) and rollback (`73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`) SHA-256 values.
3. Verify exact production project reference (`ammsjbcpbspisbyynaga`) and region (`ap-northeast-2`).
4. Re-run live read-only preflight `PF-01` through `PF-11`.
5. Verify production backup files and complete SHA-256 checksums in `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC`.
6. Confirm the production state has not changed unexpectedly.
7. Confirm zero unexpected application tables, customer data, or consumers (`pg_tables`, `auth.users`, `storage.objects`, `pg_stat_activity`).
8. Execute the explicit `public.orders` and `public.order_customizations` precondition check (Section 3.1; both must be `NULL`).
9. Open the official **persistent interactive `psql` session**, set and verify `lock_timeout = '5000ms'` and `statement_timeout = '30000ms'`.
10. Confirm the exact owner authorization (`AUTHORIZE M13 PRODUCTION MIGRATION EXECUTION`) has been received.
11. Execute `migrations/20261112_001_personalization_engine.sql` exactly once in the persistent interactive `psql` session.
12. Confirm transaction `COMMIT` (and verify `fk_order_customizations_order` absence), then execute `PMV-01` through `PMV-11`.
13. Verify PostgREST schema availability (`NOTIFY pgrst, 'reload schema';` + `anon` HTTP check) and produce the final production execution report.

---

## 5. Post-Migration Verification Matrix (`PMV-01` through `PMV-11`)

Every check below must pass before declaring production deployment verified.

| Check ID | Verification Target | Expected Outcome | Verification Method / Evidence |
|---|---|---|---|
| **PMV-01** | **3 Expected Tables & All Columns** | `personalization_templates` (9 cols), `customization_sessions` (11 cols), `order_customizations` (15 cols) exist in `public`. | `information_schema.columns` query checking exact count (`9`, `11`, `15`) and column names. |
| **PMV-02** | **Data Types, Nullability, Defaults, Constraints** | Exact match to SQL spec: `UUID`, `VARCHAR(20/30/50/64/100)`, `JSONB`, `TEXT`, `INT`, `BOOLEAN`, `TIMESTAMPTZ`; `NOT NULL` vs nullable (`preview_artifact_path`, `rendered_artifact_path`, `render_error_log`, `revoked_at`, `revocation_reason`); defaults (`gen_random_uuid()`, `24`, `true`, `now()`, `'pet_type'`, `'{}'::jsonb`, `'[]'::jsonb`, `'draft'`, `now() + 30 days`, `'pending'`, `0`, `now() + 90 days`); unique (`uq_personalization_template_version`, `token_hash`, `uq_order_customization_order`, `download_token_hash`) and check (`chk_customization_session_status`, `chk_order_customization_status`). | `information_schema.columns` + `pg_constraint` (`contype IN ('u','c')`, `pg_get_constraintdef`). |
| **PMV-03** | **Primary Keys, Foreign Keys & Indexes** | 3 PKs on `(id)`; 2 internal `RESTRICT` FKs (`customization_sessions.template_id -> personalization_templates(id)`, `order_customizations.session_id -> customization_sessions(id)`); **`fk_order_customizations_order` absent** (matching `public.orders` = `NULL` precondition); 5 explicit secondary indexes (`idx_customization_sessions_token_hash`, `idx_customization_sessions_template_id`, `idx_customization_sessions_expires_at` partial `WHERE status = 'draft'`, `idx_order_customization_order`, `idx_order_download_token_hash`). | `pg_constraint` (`contype IN ('p','f')`, `pg_get_constraintdef`) + `pg_indexes` (`schemaname = 'public'`). |
| **PMV-04** | **Function Signature, Owner, Security Mode & Privileges** | `public.m13_set_updated_at()`: 0 args, `RETURNS trigger`, `LANGUAGE plpgsql`, `prosecdef = false` (`SECURITY INVOKER`), owner `postgres`. | `pg_proc` + `pg_get_functiondef` + `information_schema.routine_privileges`. |
| **PMV-05** | **3 Expected Triggers & Definitions** | `trg_personalization_templates_updated_at`, `trg_customization_sessions_updated_at`, `trg_order_customizations_updated_at`: all `BEFORE UPDATE ... FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at()`. | `pg_trigger` (`NOT tgisinternal`) + `pg_get_triggerdef`. |
| **PMV-06** | **RLS Enabled Status** | `relrowsecurity = true` on all 3 tables. (`relforcerowsecurity = false` because migration uses `ENABLE ROW LEVEL SECURITY`, not `FORCE ROW LEVEL SECURITY`). | `SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class` for the 3 tables. |
| **PMV-07** | **4 RLS Policies (Expressions, Roles, Commands)** | 1) `"Public read active templates"` on `personalization_templates` (`SELECT`, `{anon,authenticated}`, `USING (is_active = true)`, `WITH CHECK` null);<br>2–4) `"Service role full access on <table_name>"` on all 3 tables (`ALL`, `{service_role}`, `USING (true)`, `WITH CHECK (true)`). | `SELECT tablename, policyname, cmd, roles, qual, with_check FROM pg_policies WHERE schemaname = 'public'`. |
| **PMV-08** | **Table & Sequence Grants** | `anon` & `authenticated`: `SELECT` only on `personalization_templates`; `0` privileges on `customization_sessions` and `order_customizations`. `service_role`: `ALL` on all 3 tables. `0` M13 sequences created (`information_schema.sequences`). | `information_schema.role_table_grants` + `information_schema.sequences`. |
| **PMV-09** | **Non-Privileged RLS Verification (Disposable Fixtures + Savepoints)** | **Never use `service_role` to demonstrate RLS enforcement.** Inside a single rolled-back transaction (`BEGIN; ... ROLLBACK;`):<br>1. Insert disposable fixtures as `postgres` (1 active template `is_active = true`, 1 inactive template `is_active = false`, 1 `customization_sessions` row, 1 `order_customizations` row).<br>2. Under `SET LOCAL ROLE anon;` and independently under `SET LOCAL ROLE authenticated;`:<br>&nbsp;&nbsp;- `SELECT` on `personalization_templates` returns **only** the active template (`1` row; inactive template is hidden).<br>&nbsp;&nbsp;- Expected permission failures (`INSERT`/`UPDATE` on `personalization_templates`; `SELECT`/`INSERT`/`UPDATE` on `customization_sessions` and `order_customizations`) are each wrapped in an independent `SAVEPOINT sp_...;` and rolled back via `ROLLBACK TO SAVEPOINT sp_...;` after asserting `permission denied`, so expected errors do not abort subsequent tests.<br>3. End with outer `ROLLBACK;` so zero test fixtures persist; verify `0` rows remain in all 3 tables. | SQL test output using disposable transaction-local fixtures + `SAVEPOINT`s + `SET LOCAL ROLE anon`/`authenticated` + outer `ROLLBACK;`. |
| **PMV-10** | **PostgREST Schema Reload & Independent Confirmation** | Execute `NOTIFY pgrst, 'reload schema';` post-commit. Independently confirm via HTTP using the public `anon` key (without exposing `service_role` secrets): `GET /rest/v1/personalization_templates?select=id&limit=0` returns HTTP `200` (`[]`); `GET /rest/v1/customization_sessions?select=id&limit=0` returns HTTP `401`/`403` permission denied. | HTTP status codes & response headers from PostgREST endpoint. |
| **PMV-11** | **Absence of Unexpected Objects** | `pg_tables` in `public` contains **only** the 3 M13 tables; `pg_proc` in `public` contains **only** `rls_auto_enable` and `m13_set_updated_at`; `auth.users = 0`, `storage.buckets = 0`, `storage.objects = 0`. | Read-only catalog counts matching pre-migration baseline + M13 delta only. |
