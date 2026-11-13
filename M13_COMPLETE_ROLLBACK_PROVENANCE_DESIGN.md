# M13 Complete Rollback Provenance Design

**Artifacts:**
- `migrations/20261113_2345_m13_hardening_and_provenance.sql` (`SHA-256: 047C1C916CE48825D0516304F060C33488EC2F75D6869315572EF35478619BEA`)
- `migrations/20261113_2345_m13_hardening_and_provenance_rollback.sql` (`SHA-256: CE707D18B9A69B1E9A4806D3190935280909164081E405B1C7032405A5A51D8C`)

---

## 1. Atomic Ownership Model

When `20261113_2345_m13_hardening_and_provenance.sql` runs:
1. It enforces `SET LOCAL lock_timeout = '5s';` and `SET LOCAL statement_timeout = '30s';`.
2. It verifies all M13 tables, `public.m13_set_updated_at()`, 3 triggers, FK `order_customizations_session_id_fkey`, index preconditions, and provenance integrity (if `m13_internal.migration_index_provenance` already exists).
3. It applies function hardening (`SET search_path = pg_catalog` and `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon, authenticated, service_role`).
4. If no valid covering index exists on `public.order_customizations(session_id)`, it creates `public.idx_order_customizations_session_id` and atomically creates `m13_internal.migration_index_provenance` (RLS enabled, `REVOKE ALL` from `PUBLIC, anon, authenticated, service_role`) recording:
   - `migration_id` (`'20261113_2345_m13_hardening_and_provenance'`)
   - `owning_migration` (`'20261113_2345_m13_hardening_and_provenance'`)
   - `schema_name` (`'public'`), `table_name` (`'order_customizations'`), `table_oid`
   - `index_name` (`'idx_order_customizations_session_id'`), `index_oid`, `index_def` (`pg_get_indexdef`)
   - `created_by_migration = TRUE`, `created_at`
5. If an exact-name or equivalent covering index already exists (pre-existing operator index or historical `20261113_1335` index), it **skips creation and records zero ownership**. Ownership is never inferred from name or claimed retroactively.

---

## 2. Fail-Closed Rollback Verification

`20261113_2345_m13_hardening_and_provenance_rollback.sql`:
1. Enforces `SET LOCAL lock_timeout = '5s';` and `SET LOCAL statement_timeout = '30s';`.
2. Reverses `public.m13_set_updated_at()` `search_path` and `EXECUTE` grants.
3. Preserves all indexes if `m13_internal.migration_index_provenance` or the `'20261113_2345_m13_hardening_and_provenance'` row is absent.
4. Aborts without dropping any index if:
   - The provenance table structure was altered (column count != 10).
   - Conflicting ownership records exist for `idx_order_customizations_session_id` or `owning_migration`.
   - `owning_migration`, `created_by_migration`, `schema_name`, `table_name`, or `index_name` fail validation.
   - `to_regclass('public.order_customizations')` != recorded `table_oid`.
   - Recorded `index_oid` does not exist in `pg_class` / `pg_index` (or was dropped/recreated).
   - Live schema, index name, `indrelid`, or `pg_get_indexdef(index_oid)` differs from recorded values.
5. Drops `public.idx_order_customizations_session_id` (without `CASCADE`) and deletes only its own provenance row when all checks pass, dropping `m13_internal` only if zero provenance rows remain.

