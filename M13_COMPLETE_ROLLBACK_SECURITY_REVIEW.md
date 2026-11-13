# M13 Complete Rollback Security Review

**Scope:** `migrations/20261113_2345_m13_hardening_and_provenance.sql` and `migrations/20261113_2345_m13_hardening_and_provenance_rollback.sql`.

---

## 1. Security & Trust Boundary Checklist

1. **Provenance Schema & Table Ownership:** Created by the migration-executing privileged role (`postgres`/owner). Ordinary roles cannot create or alter objects in `m13_internal`.
2. **RLS & Grants/Revokes:** `ALTER TABLE m13_internal.migration_index_provenance ENABLE ROW LEVEL SECURITY;` with zero permissive policies, plus explicit `REVOKE ALL ON SCHEMA m13_internal` and `REVOKE ALL ON TABLE m13_internal.migration_index_provenance` from `PUBLIC, anon, authenticated, service_role`. Verified in `RP-20` (all 3 roles denied).
3. **Trust Boundary Note (Privileged Owners):** RLS does not restrict table owners or `BYPASSRLS` / superuser roles. The provenance trust boundary assumes privileged migration-owner roles (`postgres`) do not maliciously tamper with `m13_internal.migration_index_provenance`. If tampering occurs anyway, structural, OID, and `pg_get_indexdef` checks fail closed (`RP-10`, `RP-16`, `RP-17`, `RP-18`, `RP-19`).
4. **Search Path & `SECURITY DEFINER`:** Zero `SECURITY DEFINER` functions added. `public.m13_set_updated_at()` retains `SET search_path = pg_catalog` and `REVOKE ALL ... FROM PUBLIC, anon, authenticated, service_role`.
5. **Dynamic SQL & Injection Exposure:** Zero dynamic SQL (`EXECUTE`) in either `20261113_2345` script; all catalog lookups use parameterized/static SQL.
6. **Transaction Boundaries & Lock Behavior:** Explicit `BEGIN; SET LOCAL lock_timeout = '5s'; SET LOCAL statement_timeout = '30s'; ... COMMIT;`. Verified in `TIMEOUT-03` (`55P03` at `5.03s`), `TIMEOUT-04` (`57014` at `30.04s`), and `TIMEOUT-05` (`0->0`).
7. **Index Identity, OID Reuse & `DROP INDEX` Safety:** Never drops by name alone. Verifies `table_oid`, `index_oid`, `indrelid`, schema, index name, `owning_migration`, `created_by_migration`, and exact `pg_get_indexdef(index_oid)`. Never uses `CASCADE`.
8. **Idempotency:** Forward rerun (`RP-12`) and rollback rerun (`RP-13`) are both safe and deterministic.
9. **`rls_auto_enable()` Event Trigger Compatibility:** Neither script modifies `rls_auto_enable()`. Tested with an active `ddl_command_end` `CREATE TABLE` event trigger (`RLS-AUTO-ENABLE-EVENT-TRIGGER`: `rls_on=True, evt_preserved=1`).

---

## 2. Security Verdict

**SECURITY VERDICT: PASS — Zero unresolved security findings.**
