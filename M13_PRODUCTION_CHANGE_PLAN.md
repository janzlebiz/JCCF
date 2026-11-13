# JCCF Subsystem M13 — Production Change Plan
**Document ID:** `JCCF-M13-PROD-CHANGE-PLAN`
**Document Version:** 1.2
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
| **7** | **Expected Objects** | `3` tables (`personalization_templates`, `customization_sessions`, `order_customizations`), `1` function (`public.m13_set_updated_at()`), `3` triggers, `4` RLS policies (`ENABLE ROW LEVEL SECURITY`), `2` internal FKs, `5` explicit secondary indexes (+ PK/unique indexes), table grants. |
| **8** | **Pre-Condition (Consumers)** | `0` customer writes, `0` active application consumers, and `0` external dependencies may exist at migration time unless separately reviewed and approved. |
| **9** | **Estimated Duration & Impact** | **Estimated** DDL duration: `< 5 seconds` under current empty-database conditions; **estimated** service disruption: minimal/none while `0` public tables and `0` active consumers exist (estimate only, not a guarantee). |

---

## 2. Execution Timeouts, Transaction Failure Protocol & Safety Controls

### 2.1 Session Timeouts (`lock_timeout` & `statement_timeout`)

Before executing `migrations/20261112_001_personalization_engine.sql` (with `psql -v ON_ERROR_STOP=1`), the migration session sets:

```sql
SET lock_timeout = '5000ms';
SET statement_timeout = '30000ms';
```

* **`lock_timeout = '5000ms'` (5 seconds):** Prevents queuing indefinitely behind an unexpected lock holder. If a lock wait exceeds 5000 ms, PostgreSQL cancels the offending statement (`canceling statement due to lock timeout`).
* **`statement_timeout = '30000ms'` (30 seconds):** Caps per-statement execution time over the IPv4 session pooler (`aws-1-ap-northeast-2.pooler.supabase.com:5432`). If any statement exceeds 30000 ms, PostgreSQL cancels that statement (`canceling statement due to statement timeout`).

### 2.2 PostgreSQL Transaction Failure Protocol

Operators must distinguish the four phases of a PostgreSQL transaction failure:

1. **Statement Cancellation:** `lock_timeout` or `statement_timeout` cancels only the currently running SQL statement; it does **not** by itself issue `ROLLBACK`.
2. **Aborted Transaction State:** Because the migration runs inside an explicit `BEGIN;` ... `COMMIT;` block, any cancelled or errored statement places the session into PostgreSQL's `aborted` (`25P02: current transaction is aborted, commands ignored until end of transaction block`) state.
3. **Explicit `ROLLBACK`:** With `ON_ERROR_STOP=1`, `psql` halts immediately on the first error. The operator (or session cleanup) must issue an explicit `ROLLBACK;` to end the aborted transaction cleanly and discard all prior uncommitted DDL. (Even if `COMMIT;` were reached on an aborted transaction, PostgreSQL converts it to `ROLLBACK`, but explicit `ON_ERROR_STOP=1` + `ROLLBACK;` is mandatory.)
4. **Connection Termination & Server-Side Transaction Cleanup:** If the client connection drops or is terminated mid-transaction, the PostgreSQL backend implicitly rolls back any uncommitted or aborted transaction upon backend exit—unless `COMMIT;` had already completed on the server before the disconnect.

**Mandatory Pre-Inspection / Pre-Retry Rule:** Before inspecting objects, retrying, or taking any further action after a timeout, error, or disconnect, the operator **MUST** confirm that the previous transaction has ended on the server by querying `pg_stat_activity`:

```sql
SELECT pid, state, xact_start, left(query, 100)
FROM pg_stat_activity
WHERE datname = current_database()
  AND pid <> pg_backend_pid();
```

Confirm zero active or `idle in transaction` / `idle in transaction (aborted)` migration sessions remain before proceeding.

### 2.3 Transaction Boundaries & Atomicity

* `migrations/20261112_001_personalization_engine.sql` is wrapped in a single explicit transaction: `BEGIN;` (line 16) through `COMMIT;` (line 642).
* **Transaction-Safety Verification:** Every statement inside the script (`DO $$ ... $$` preflight guards, `CREATE FUNCTION`, `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD CONSTRAINT`, standard non-concurrent `CREATE INDEX IF NOT EXISTS`, `CREATE TRIGGER`, `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, `REVOKE`/`GRANT`, `CREATE POLICY`, `COMMENT ON`) is transaction-safe in PostgreSQL 17.11. There are zero `CREATE INDEX CONCURRENTLY`, `VACUUM`, or non-transactional commands.
* **Post-Commit Step:** `NOTIFY pgrst, 'reload schema';` runs in a separate step **after** `COMMIT;` succeeds.

### 2.4 Connection-Loss Handling

If the client connection drops mid-execution before `COMMIT` confirmation is received:
1. **Do not** re-run the migration and **do not** execute rollback.
2. Reconnect in read-only mode and confirm the previous transaction has ended (`pg_stat_activity` check in Section 2.2).
3. Inspect `pg_tables` (`personalization_templates`, `customization_sessions`, `order_customizations`) and `pg_proc` (`m13_set_updated_at`):
   * **All 3 tables + function + triggers + policies present:** `COMMIT` succeeded on the server before the network drop. Proceed to Section 4 (PMV-01..PMV-11).
   * **0 M13 objects present:** Server-side cleanup rolled back the uncommitted transaction. Inspect logs and `pg_stat_activity` before any manual retry.

### 2.5 Idempotency, Failure Handling & Stop Conditions

* **Idempotency & Duplicate Prevention:** SQL guards (`IF NOT EXISTS`, fail-closed `DO $$` definition checks) prevent partial overwrites, but operational discipline requires executing the migration **once**, never concurrently, and verifying commit outcome before any retry.
* **Failure Handling:** On any error, timeout, or unexpected warning: **STOP immediately**, confirm the previous transaction has ended, and inspect actual database state. **Never automatically execute rollback.** Rollback (`migrations/20261112_001_personalization_engine_rollback.sql`, `RESTRICT` only, zero `CASCADE`) is a separate manual operator decision only when no live customer writes or unreviewed external dependencies exist.
* **Stop Conditions:** Stop immediately on any artifact SHA-256/blob mismatch, backup checksum mismatch, `PF-01`..`PF-11` failure, unexpected active consumer/data/dependency, timeout/error/disconnect, or `PMV-01`..`PMV-11` failure.

---

## 3. Ordered Operator Execution Sequence

Execute steps in exact numerical order. If any check fails, **stop and inspect**; never automatically execute rollback.

1. Verify repository (`https://github.com/janzlebiz/JCCF`, `main`) and exact approved commit.
2. Verify migration (`9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`) and rollback (`73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`) SHA-256 checksums.
3. Verify production project identity (`ammsjbcpbspisbyynaga`, `JCCF`, `ap-northeast-2`, `PostgreSQL 17.11`).
4. Re-run all live read-only preflight checks (`PF-01` through `PF-11`).
5. Verify backup files and complete SHA-256 checksums in `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC`.
6. Confirm no new data, consumers, dependencies, or collisions (`pg_tables`, `auth.users`, `storage.objects`, `pg_stat_activity`).
7. Confirm transaction timeout settings (`lock_timeout = '5000ms'`, `statement_timeout = '30000ms'`, `ON_ERROR_STOP=1`).
8. Confirm the exact owner authorization has been received.
9. Execute the migration once.
10. Verify transaction commit (and confirm no aborted/hanging session in `pg_stat_activity`).
11. Execute all `PMV-01` through `PMV-11` checks.
12. Verify PostgREST schema availability (`NOTIFY pgrst, 'reload schema';` and independent `anon` HTTP check).
13. Produce the production execution report.

---

## 4. Post-Migration Verification Matrix (`PMV-01` through `PMV-11`)

Every check below must pass before declaring production deployment verified.

| Check ID | Verification Target | Expected Outcome | Verification Method / Evidence |
|---|---|---|---|
| **PMV-01** | **3 Expected Tables & All Columns** | `personalization_templates` (9 cols), `customization_sessions` (11 cols), `order_customizations` (15 cols) exist in `public`. | `information_schema.columns` query checking exact count (`9`, `11`, `15`) and column names. |
| **PMV-02** | **Data Types, Nullability, Defaults, Constraints** | Exact match to SQL spec: `UUID`, `VARCHAR(20/30/50/64/100)`, `JSONB`, `TEXT`, `INT`, `BOOLEAN`, `TIMESTAMPTZ`; `NOT NULL` vs nullable (`preview_artifact_path`, `rendered_artifact_path`, `render_error_log`, `revoked_at`, `revocation_reason`); defaults (`gen_random_uuid()`, `24`, `true`, `now()`, `'pet_type'`, `'{}'::jsonb`, `'[]'::jsonb`, `'draft'`, `now() + 30 days`, `'pending'`, `0`, `now() + 90 days`); unique (`uq_personalization_template_version`, `token_hash`, `uq_order_customization_order`, `download_token_hash`) and check (`chk_customization_session_status`, `chk_order_customization_status`). | `information_schema.columns` + `pg_constraint` (`contype IN ('u','c')`, `pg_get_constraintdef`). |
| **PMV-03** | **Primary Keys, Foreign Keys & Indexes** | 3 PKs on `(id)`; 2 internal FKs (`customization_sessions.template_id -> personalization_templates(id) ON DELETE RESTRICT`, `order_customizations.session_id -> customization_sessions(id) ON DELETE RESTRICT`); 0 optional external FKs (`products`/`orders` absent); 5 explicit secondary indexes (`idx_customization_sessions_token_hash`, `idx_customization_sessions_template_id`, `idx_customization_sessions_expires_at` partial `WHERE status = 'draft'`, `idx_order_customization_order`, `idx_order_download_token_hash`). | `pg_constraint` (`contype IN ('p','f')`, `pg_get_constraintdef`) + `pg_indexes` (`schemaname = 'public'`). |
| **PMV-04** | **Function Signature, Owner, Security Mode & Privileges** | `public.m13_set_updated_at()`: 0 args, `RETURNS trigger`, `LANGUAGE plpgsql`, `prosecdef = false` (`SECURITY INVOKER`), owner `postgres`. | `pg_proc` + `pg_get_functiondef` + `information_schema.routine_privileges`. |
| **PMV-05** | **3 Expected Triggers & Definitions** | `trg_personalization_templates_updated_at`, `trg_customization_sessions_updated_at`, `trg_order_customizations_updated_at`: all `BEFORE UPDATE ... FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at()`. | `pg_trigger` (`NOT tgisinternal`) + `pg_get_triggerdef`. |
| **PMV-06** | **RLS Enabled Status** | `relrowsecurity = true` on all 3 tables. (`relforcerowsecurity = false` because migration uses `ENABLE ROW LEVEL SECURITY`, not `FORCE ROW LEVEL SECURITY`). | `SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class` for the 3 tables. |
| **PMV-07** | **4 RLS Policies (Expressions, Roles, Commands)** | 1) `"Public read active templates"` on `personalization_templates` (`SELECT`, `{anon,authenticated}`, `USING (is_active = true)`, `WITH CHECK` null);<br>2–4) `"Service role full access on <table_name>"` on all 3 tables (`ALL`, `{service_role}`, `USING (true)`, `WITH CHECK (true)`). | `SELECT tablename, policyname, cmd, roles, qual, with_check FROM pg_policies WHERE schemaname = 'public'`. |
| **PMV-08** | **Table & Sequence Grants** | `anon` & `authenticated`: `SELECT` only on `personalization_templates`; `0` privileges on `customization_sessions` and `order_customizations`. `service_role`: `ALL` on all 3 tables. `0` M13 sequences created (`information_schema.sequences`). | `information_schema.role_table_grants` + `information_schema.sequences`. |
| **PMV-09** | **Non-Privileged RLS Verification (Disposable Fixtures + Savepoints)** | **Never use `service_role` to demonstrate RLS enforcement.** Inside a single rolled-back transaction (`BEGIN; ... ROLLBACK;`):<br>1. Insert disposable fixtures as `postgres` (1 active template `is_active = true`, 1 inactive template `is_active = false`, 1 `customization_sessions` row, 1 `order_customizations` row).<br>2. Under `SET LOCAL ROLE anon;` and independently under `SET LOCAL ROLE authenticated;`:<br>&nbsp;&nbsp;- `SELECT` on `personalization_templates` returns **only** the active template (`1` row; inactive template is hidden).<br>&nbsp;&nbsp;- Expected permission failures (`INSERT`/`UPDATE` on `personalization_templates`; `SELECT`/`INSERT`/`UPDATE` on `customization_sessions` and `order_customizations`) are each wrapped in an independent `SAVEPOINT sp_...;` and rolled back via `ROLLBACK TO SAVEPOINT sp_...;` after asserting `permission denied`, so expected errors do not abort subsequent tests.<br>3. End with outer `ROLLBACK;` so zero test fixtures persist; verify `0` rows remain in all 3 tables. | SQL test output using disposable transaction-local fixtures + `SAVEPOINT`s + `SET LOCAL ROLE anon`/`authenticated` + outer `ROLLBACK;`. |
| **PMV-10** | **PostgREST Schema Reload & Independent Confirmation** | Execute `NOTIFY pgrst, 'reload schema';` post-commit. Independently confirm via HTTP using the public `anon` key (without exposing `service_role` secrets): `GET /rest/v1/personalization_templates?select=id&limit=0` returns HTTP `200` (`[]`); `GET /rest/v1/customization_sessions?select=id&limit=0` returns HTTP `401`/`403` permission denied. | HTTP status codes & response headers from PostgREST endpoint. |
| **PMV-11** | **Absence of Unexpected Objects** | `pg_tables` in `public` contains **only** the 3 M13 tables; `pg_proc` in `public` contains **only** `rls_auto_enable` and `m13_set_updated_at`; `auth.users = 0`, `storage.buckets = 0`, `storage.objects = 0`. | Read-only catalog counts matching pre-migration baseline + M13 delta only. |
