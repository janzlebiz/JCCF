# M13 Rollback Provenance Remediation — Security Review

**Repository:** `https://github.com/janzlebiz/JCCF`
**Branch:** `main`
**Scope:** Static and runtime security review of `migrations/20261113_2200_m13_rollback_provenance_fix.sql` and `migrations/20261113_2200_m13_rollback_provenance_fix_rollback.sql`.

---

## 1. Security Controls Verified

1. **Internal Provenance Schema Isolation (`m13_internal`):**
   - `m13_internal` is a dedicated private schema separate from `public`, `auth`, and Supabase-exposed API schemas.
   - Forward migration executes `REVOKE ALL ON SCHEMA m13_internal FROM PUBLIC, anon, authenticated, service_role;` and `REVOKE ALL ON TABLE m13_internal.migration_index_provenance FROM PUBLIC, anon, authenticated, service_role;`.
   - `ALTER TABLE m13_internal.migration_index_provenance ENABLE ROW LEVEL SECURITY;` is enabled with zero permissive policies (default-deny for all non-owner roles).
   - Verified in `RP-ACL-ANON` and `RP-ACL-AUTHENTICATED`: both `anon` and `authenticated` receive permission denied on `m13_internal`.

2. **Privilege & Role Surface:**
   - Zero `SECURITY DEFINER` functions introduced.
   - Zero `GRANT` statements to `PUBLIC`, `anon`, `authenticated`, or `service_role`.
   - Zero alterations to existing `public.m13_set_updated_at()` hardening (`search_path = pg_catalog`, `EXECUTE` restricted).

3. **Timeout & Lock Safety:**
   - Both forward and rollback scripts set `SET LOCAL lock_timeout = '5s';` and `SET LOCAL statement_timeout = '30s';` inside explicit `BEGIN; ... COMMIT;` transactions.
   - Verified in `RP-16`: lock contention aborts cleanly via `lock_timeout` without leaving partial state.

4. **Fail-Closed Provenance & Destructive-Action Guards:**
   - Rollback verifies:
     1. Existence of `m13_internal.migration_index_provenance`.
     2. Presence of provenance row for `migration_id = '20261113_2200_m13_rollback_provenance_fix'`.
     3. Integrity of `created_by_migration = true`, `schema_name = 'public'`, `table_name = 'order_customizations'`, `index_name = 'idx_order_customizations_session_id'`.
     4. Exact live OID match on `pg_class` (`index_oid`) and `pg_index` (`indrelid = table_oid`), plus live `pg_get_indexdef(index_oid) = index_def`.
   - Any mismatch, missing provenance, stale OID, or recreated/renamed index raises an exception and aborts the transaction without dropping any index (`RP-05` through `RP-10`).
   - Only `DROP INDEX public.idx_order_customizations_session_id;` (never `CASCADE`) is executed, and only after all 4 checks pass.

5. **No Secrets, No Production Exposure:**
   - Zero credentials, tokens, or connection strings appear in any SQL or test artifact.
   - All verification ran exclusively against an ephemeral local PostgreSQL 17.11 cluster (`127.0.0.1:5439`).

---

## 2. Security Review Verdict

**SECURITY VERDICT: PASS — Zero high, medium, or low security findings.**
