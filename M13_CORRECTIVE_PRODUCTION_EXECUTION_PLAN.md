# JCCF M13 — Corrective Production Execution Plan
**Document ID:** `JCCF-M13-CORRECTIVE-EXEC-PLAN`
**Date:** November 13, 2026
**Target Project:** `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `PostgreSQL 17.11`)
**Status:** Ready for Explicit Owner Release (Live DDL **NOT EXECUTED**)

---

## 1. Artifact & Control Summary

| Parameter | Specification |
|---|---|
| **Target Project Ref** | `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `PostgreSQL 17.11`) |
| **Corrective Migration** | `migrations/20261113_1335_m13_production_hardening.sql` |
| **Migration SHA-256** | `35A99DE63EF547C16808E6ECF12F9ED8DAD17CBA57110A9B52B1109EE0A48054` |
| **Corrective Rollback** | `migrations/20261113_1335_m13_production_hardening_rollback.sql` |
| **Rollback SHA-256** | `D98B1807284C4FCFA860D8EF9143708072C4B04050C91EB815FF53A7E73066F2` |
| **Required Operator Role** | `postgres` (via `postgres.ammsjbcpbspisbyynaga` over IPv4 Session Pooler `aws-1-ap-northeast-2.pooler.supabase.com:5432`, `sslmode=require`) |
| **Session Timeouts** | `SET lock_timeout = '5000ms';` and `SET statement_timeout = '30000ms';` |
| **Official Execution Method** | Persistent interactive `psql` session using `\i migrations/20261113_1335_m13_production_hardening.sql` (without `ON_ERROR_STOP=1`) |

---

## 2. Pre-Execution Backup & Read-Only Preflight

1. **Backup Requirement:** Capture a fresh logical backup (`pg_dump` / `pg_dumpall` 17.11) to `D:\JCCF_SECURE_BACKUPS\M13\` outside Git prior to execution and verify its SHA-256 manifest.
2. **Read-Only Preflight Commands:**
   * Verify open transactions (`pg_stat_activity` where `xact_start IS NOT NULL` and `pid <> pg_backend_pid()` returns `0` rows).
   * Verify `public.m13_set_updated_at()` (`oid`, `prosecdef = false`, `proconfig`, `proacl`), 3 M13 triggers, `order_customizations_session_id_fkey`, and `order_customizations` indexes.
   * Verify SHA-256 hashes of migration and rollback SQL match Section 1.

---

## 3. Freeze, Execution & Failure Protocol

1. **Schema-Change Freeze:** Notify operators, pause CI/CD/automated DDL, record freeze start UTC timestamp.
2. **Owner Release:** Confirm explicit owner authorization for `20261113_1335_m13_production_hardening.sql` before connecting for DDL.
3. **Execute Once:**
   ```sql
   SET lock_timeout = '5000ms';
   SET statement_timeout = '30000ms';
   SHOW lock_timeout;
   SHOW statement_timeout;
   \i migrations/20261113_1335_m13_production_hardening.sql
   ```
4. **Failure / Timeout / Disconnect Handling:**
   * **SQL error / `lock_timeout` / `statement_timeout`:** Cancels statement and places session in `25P02`; trailing `COMMIT;` converts to `ROLLBACK`; issue explicit `ROLLBACK;`, inspect `pg_stat_activity` from a new read-only session, **never automatically retry**, and **never automatically execute rollback**.
   * **Client disconnect / connection termination:** Reconnect read-only, confirm zero lingering transactions in `pg_stat_activity`, inspect `proconfig`/`proacl`/`pg_indexes`, and report to owner.
5. **Rollback Decision Process:** Execute `20261113_1335_m13_production_hardening_rollback.sql` **only** after manual state inspection and explicit owner approval.
6. **Migration-History Handling:** Keep `psql \i` consistent now; follow [M13_MIGRATION_HISTORY_RECONCILIATION.md](M13_MIGRATION_HISTORY_RECONCILIATION.md) (`supabase migration repair`) only when adopting `supabase/migrations/`.
7. **Freeze Release:** Record freeze end UTC timestamp after post-migration verification passes.

---

## 4. Post-Migration Verification Queries

1. **Function `search_path` & `SECURITY INVOKER`:**
   ```sql
   SELECT proname, prosecdef, proconfig, proacl::text
   FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
   WHERE n.nspname = 'public' AND p.proname = 'm13_set_updated_at';
   ```
   Expected: `prosecdef = false`, `proconfig = {search_path=pg_catalog}`, `proacl = {postgres=X/postgres}`.
2. **Effective Privileges:**
   ```sql
   SELECT r, has_function_privilege(r, 'public.m13_set_updated_at()', 'EXECUTE')
   FROM unnest(ARRAY['public','anon','authenticated','service_role','postgres']) AS r;
   ```
   Expected: `false` for `public`, `anon`, `authenticated`, `service_role`; `true` for `postgres`.
3. **Index Verification:**
   ```sql
   SELECT indexname, indexdef FROM pg_indexes
   WHERE schemaname = 'public' AND tablename = 'order_customizations'
   ORDER BY indexname;
   ```
   Expected: `idx_order_customizations_session_id` present (`btree (session_id)`), `indisvalid = true`, `indisready = true`, zero duplicate `session_id` indexes.
4. **Out-of-Scope & Trigger Integrity:** Confirm `public.rls_auto_enable()` is unchanged and all 3 M13 triggers remain enabled (`tgenabled = 'O'`).

