# M13 Complete Rollback Execution Plan

**Production Target:** `ammsjbcpbspisbyynaga` (`ap-northeast-2`, PostgreSQL 17.11)
**Authorization Status:** **NOT AUTHORIZED**
**Execution Method:** Persistent interactive `psql` session using `\i` against SHA-256-verified SQL files.

---

## 1. Approved Candidate Checksums

- Forward: `migrations/20261113_2345_m13_hardening_and_provenance.sql` (`047C1C916CE48825D0516304F060C33488EC2F75D6869315572EF35478619BEA`)
- Rollback: `migrations/20261113_2345_m13_hardening_and_provenance_rollback.sql` (`CE707D18B9A69B1E9A4806D3190935280909164081E405B1C7032405A5A51D8C`)

Do **NOT** execute `20261113_1335_m13_production_hardening.sql`, `20261113_1335_m13_production_hardening_rollback.sql`, `20261113_2200_m13_rollback_provenance_fix.sql`, or `20261113_2200_m13_rollback_provenance_fix_rollback.sql`.

---

## 2. Operator Protocol (Only Upon Explicit Owner Authorization)

1. Verify local SHA-256 checksums match Section 1.
2. Enforce production schema-change freeze and confirm zero lingering DDL sessions in `pg_stat_activity`.
3. In interactive `psql` with `\set ON_ERROR_STOP on`:
   - Forward: `\i migrations/20261113_2345_m13_hardening_and_provenance.sql`
   - Rollback (only if separately authorized): `\i migrations/20261113_2345_m13_hardening_and_provenance_rollback.sql`
4. Both scripts enforce `SET LOCAL lock_timeout = '5s';` and `SET LOCAL statement_timeout = '30s';` inside `BEGIN; ... COMMIT;`. On any abort, verify transaction cleanup before inspecting or retrying.
5. If `20261113_2345_rollback` preserves an unowned residual `idx_order_customizations_session_id` (e.g., created earlier by historical `1335` or manually by an operator), retain it for explicit manual review.
