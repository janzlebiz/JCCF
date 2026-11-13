# JCCF Subsystem M13 — Production Change Plan
**Document ID:** `JCCF-M13-PROD-CHANGE-PLAN`
**Document Version:** 1.1
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
| **4** | **Production Backup Ref** | `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC` (see [M13_PRODUCTION_BACKUP_AND_RECOVERY_REPORT.md](M13_PRODUCTION_BACKUP_AND_RECOVERY_REPORT.md)). |
| **5** | **Preflight Results** | `11/11 PASS` (`PF-01`..`PF-11`, `2026-11-13T03:27:18Z–20Z`): PG 17.11, `gen_random_uuid()` OK, `anon`/`authenticated`/`service_role` present, `0` collisions (see [M13_PRODUCTION_STATE_INSPECTION_REPORT.md](M13_PRODUCTION_STATE_INSPECTION_REPORT.md)). |
| **6** | **Expected Objects** | `3` tables (`personalization_templates`, `customization_sessions`, `order_customizations`), `1` function (`public.m13_set_updated_at()`), `3` triggers, `4` RLS policies (`ENABLE ROW LEVEL SECURITY`), `2` internal FKs, `5` explicit secondary indexes (+ PK/unique indexes), table grants. |
| **7** | **Pre-Condition (Consumers)** | `0` customer writes, `0` active application consumers, and `0` external dependencies may exist at migration time unless separately reviewed and approved. |
| **8** | **Estimated Duration & Impact** | **Estimated** DDL duration: `< 5 seconds` under current empty-database conditions; **estimated** service disruption: minimal/none while `0` public tables and `0` active consumers exist (estimate only, not a guarantee). |

---

## 2. Execution Timeouts, Transaction Boundaries & Safety Protocol

### 2.1 Session Timeouts (`lock_timeout` & `statement_timeout`)

Before executing `migrations/20261112_001_personalization_engine.sql`, the migration session sets:

```sql
SET lock_timeout = '5000ms';
SET statement_timeout = '30000ms';
```

* **`lock_timeout = '5000ms'` (5 seconds):**
  * *Why appropriate:* In an empty database with zero active application consumers, DDL lock acquisition should be near-instantaneous; 5 seconds allows brief transient metadata activity while preventing the migration from queuing indefinitely behind an unexpected lock holder (such as `postgres_exporter`, `pg_cron`, or a stray session).
  * *Effect:* If any lock request waits longer than 5000 ms, PostgreSQL aborts the statement with `canceling statement due to lock timeout`, rolls back the active transaction cleanly, and leaves zero partial schema changes.
* **`statement_timeout = '30000ms'` (30 seconds):**
  * *Why appropriate:* Caps total execution time for any single statement (including the `DO $$ ... $$` preflight blocks and DDL creation) over the IPv4 session pooler (`aws-1-ap-northeast-2.pooler.supabase.com:5432`) while remaining well below pooler connection timeouts.
  * *Effect:* If any statement runs longer than 30000 ms, PostgreSQL cancels it with `canceling statement due to statement timeout` and aborts the transaction, triggering a full rollback of all uncommitted DDL.

### 2.2 Transaction Boundaries & Atomicity

* `migrations/20261112_001_personalization_engine.sql` is wrapped in a single explicit transaction: `BEGIN;` (line 16) through `COMMIT;` (line 642).
* **Transaction-Safety Verification:** Every statement inside the script (`DO $$ ... $$` preflight guards, `CREATE FUNCTION`, `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD CONSTRAINT`, standard non-concurrent `CREATE INDEX IF NOT EXISTS`, `CREATE TRIGGER`, `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, `REVOKE`/`GRANT`, `CREATE POLICY`, `COMMENT ON`) is transaction-safe in PostgreSQL 17.11. There are zero `CREATE INDEX CONCURRENTLY`, `VACUUM`, or non-transactional commands.
* **Atomicity Guarantee:** All M13 objects either commit together at `COMMIT;` or roll back together on any error, timeout, or session abort.
* **Post-Commit Step:** `NOTIFY pgrst, 'reload schema';` is executed in a separate step **after** `COMMIT;` succeeds.

### 2.3 Connection-Loss Handling

If the client connection drops mid-execution before `COMMIT` confirmation is received:
1. **Do not** immediately re-run the migration and **do not** execute rollback.
2. Reconnect in read-only mode and inspect server state:
   * Check `pg_stat_activity` (`SELECT pid, state, left(query, 100) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();`) to confirm no prior migration session is still running.
   * Check `pg_tables` for `personalization_templates`, `customization_sessions`, `order_customizations`, and `pg_proc` for `m13_set_updated_at`.
3. Because the migration runs inside a single `BEGIN ... COMMIT` transaction:
   * **All 3 tables + function + triggers + policies present:** `COMMIT` succeeded on the server before the network drop. Proceed directly to Section 3 (Post-Migration Verification).
   * **0 M13 objects present:** The server rolled back the uncommitted transaction on disconnect. Inspect logs and `pg_stat_activity` before any manual retry.

### 2.4 Idempotency & Duplicate-Execution Prevention

* **SQL Guards:** The migration uses `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and fail-closed `DO $$` definition checks for `m13_set_updated_at()`, FKs, triggers, and policies; `ENABLE ROW LEVEL SECURITY` and `REVOKE`/`GRANT` are idempotent. Any incompatible pre-existing object aborts the transaction via `RAISE EXCEPTION`.
* **Operational Prevention:** The operator executes the migration **once**, never concurrently, and verifies commit outcome (Section 2.3) before any retry.

### 2.5 Failure Handling & Rollback Rules

* On any SQL error, timeout, or unexpected warning: **STOP immediately.**
* Inspect actual production database state (`pg_tables`, `pg_proc`, `pg_trigger`, `pg_policies`, `pg_stat_activity`).
* **Never automatically execute rollback.** Rollback (`migrations/20261112_001_personalization_engine_rollback.sql`, `RESTRICT` only, zero `CASCADE`) is a separate manual operator decision executed only after verifying that no live customer writes or unreviewed external dependencies exist.

### 2.6 Mandatory Operator Stop Conditions

Stop immediately and do not proceed if any of the following occur:
1. Repository HEAD, migration SHA-256 (`9D6579BC...`), or rollback SHA-256 (`73725DF9...`) does not match approved identities.
2. Any backup file in `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC` is unreadable or fails SHA-256 verification.
3. Any `PF-01`..`PF-11` check fails, or any unexpected public table, M13 object, Auth user, Storage object, or active application consumer is detected.
4. `lock_timeout`, `statement_timeout`, connection drop, or any `RAISE EXCEPTION` occurs during execution.
5. Any post-migration verification check in Section 3 fails.

---

## 3. Post-Migration Verification Matrix

Every check below must pass before declaring production deployment verified.

| Check ID | Verification Target | Expected Outcome | Verification Method / Evidence |
|---|---|---|---|
| **PMV-01** | **3 Expected Tables & All Columns** | `personalization_templates` (9 cols), `customization_sessions` (11 cols), `order_customizations` (15 cols) exist in `public`. | `information_schema.columns` query checking exact count (`9`, `11`, `15`) and column names. |
| **PMV-02** | **Data Types, Nullability, Defaults, Constraints** | Exact match to SQL spec: `UUID`, `VARCHAR(20/30/50/64/100)`, `JSONB`, `TEXT`, `INT`, `BOOLEAN`, `TIMESTAMPTZ`; `NOT NULL` vs nullable (`preview_artifact_path`, `rendered_artifact_path`, `render_error_log`, `revoked_at`, `revocation_reason`); defaults (`gen_random_uuid()`, `24`, `true`, `now()`, `'pet_type'`, `'{}'::jsonb`, `'[]'::jsonb`, `'draft'`, `now() + 30 days`, `'pending'`, `0`, `now() + 90 days`); unique (`uq_personalization_template_version`, `token_hash`, `uq_order_customization_order`, `download_token_hash`) and check (`chk_customization_session_status`, `chk_order_customization_status`). | `information_schema.columns` (`data_type`, `character_maximum_length`, `is_nullable`, `column_default`) + `pg_constraint` (`contype IN ('u','c')`, `pg_get_constraintdef`). |
| **PMV-03** | **Primary Keys, Foreign Keys & Indexes** | 3 PKs on `(id)`; 2 internal FKs (`customization_sessions.template_id -> personalization_templates(id) ON DELETE RESTRICT`, `order_customizations.session_id -> customization_sessions(id) ON DELETE RESTRICT`); 0 optional external FKs (`products`/`orders` absent); 5 explicit secondary indexes (`idx_customization_sessions_token_hash`, `idx_customization_sessions_template_id`, `idx_customization_sessions_expires_at` partial `WHERE status = 'draft'`, `idx_order_customization_order`, `idx_order_download_token_hash`). | `pg_constraint` (`contype IN ('p','f')`, `pg_get_constraintdef`) + `pg_indexes` (`schemaname = 'public'`). |
| **PMV-04** | **Function Signature, Owner, Security Mode & Privileges** | `public.m13_set_updated_at()`: 0 args, `RETURNS trigger`, `LANGUAGE plpgsql`, `prosecdef = false` (`SECURITY INVOKER`), owner `postgres`. | `pg_proc` + `pg_get_functiondef` + `information_schema.routine_privileges`. |
| **PMV-05** | **3 Expected Triggers & Definitions** | `trg_personalization_templates_updated_at`, `trg_customization_sessions_updated_at`, `trg_order_customizations_updated_at`: all `BEFORE UPDATE ... FOR EACH ROW EXECUTE FUNCTION public.m13_set_updated_at()`. | `pg_trigger` (`NOT tgisinternal`) + `pg_get_triggerdef`. |
| **PMV-06** | **RLS Enabled Status** | `relrowsecurity = true` on all 3 tables. (`relforcerowsecurity = false` because migration uses `ENABLE ROW LEVEL SECURITY`, not `FORCE ROW LEVEL SECURITY`). | `SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class` for the 3 tables. |
| **PMV-07** | **4 RLS Policies (Expressions, Roles, Commands)** | 1) `"Public read active templates"` on `personalization_templates` (`SELECT`, `{anon,authenticated}`, `USING (is_active = true)`, `WITH CHECK` null);<br>2–4) `"Service role full access on <table_name>"` on all 3 tables (`ALL`, `{service_role}`, `USING (true)`, `WITH CHECK (true)`). | `SELECT tablename, policyname, cmd, roles, qual, with_check FROM pg_policies WHERE schemaname = 'public'`. |
| **PMV-08** | **Table & Sequence Grants** | `anon` & `authenticated`: `SELECT` only on `personalization_templates`; `0` privileges on `customization_sessions` and `order_customizations`. `service_role`: `ALL` on all 3 tables. `0` M13 sequences created (`information_schema.sequences`). | `information_schema.role_table_grants` + `information_schema.sequences`. |
| **PMV-09** | **Non-Privileged Role Read/Deny Behavior** | **Never use `service_role` as evidence that RLS works.** Inside `BEGIN; SET LOCAL ROLE anon; ... ROLLBACK;` (and `SET LOCAL ROLE authenticated;`): `SELECT` on `personalization_templates` succeeds (`0` rows returned; active-only filter enforced, write denied); `SELECT`/`INSERT` on `customization_sessions` and `order_customizations` fail with `permission denied`. Zero secret keys exposed or logged. | Direct SQL test output under `SET LOCAL ROLE anon` and `SET LOCAL ROLE authenticated` inside rolled-back transaction. |
| **PMV-10** | **PostgREST Schema Reload & Independent Confirmation** | Execute `NOTIFY pgrst, 'reload schema';` post-commit. Independently confirm via HTTP using the public `anon` key (without exposing `service_role` secrets): `GET /rest/v1/personalization_templates?select=id&limit=0` returns HTTP `200` (`[]`); `GET /rest/v1/customization_sessions?select=id&limit=0` returns HTTP `401`/`403` permission denied. | HTTP status codes & response headers from PostgREST endpoint. |
| **PMV-11** | **Absence of Unexpected Objects** | `pg_tables` in `public` contains **only** the 3 M13 tables; `pg_proc` in `public` contains **only** `rls_auto_enable` and `m13_set_updated_at`; `auth.users = 0`, `storage.buckets = 0`, `storage.objects = 0`. | Read-only catalog counts matching pre-migration baseline + M13 delta only. |
