# JCCF M13 — Rollback Provenance Design
**Document ID:** `JCCF-M13-ROLLBACK-PROVENANCE-DESIGN`
**Date:** November 13, 2026

---

## 1. Design Overview

To guarantee that rollback drops `public.idx_order_customizations_session_id` **only** when the corrective remediation migration itself created it, the migration uses a durable, transaction-coupled provenance record in a private internal schema:

* **Schema:** `m13_internal` (`REVOKE ALL ON SCHEMA m13_internal FROM PUBLIC, anon, authenticated, service_role`)
* **Table:** `m13_internal.migration_index_provenance` (`ENABLE ROW LEVEL SECURITY`, `REVOKE ALL` from `PUBLIC`, `anon`, `authenticated`, `service_role`):
  * `migration_id TEXT PRIMARY KEY` (`'20261113_2200_m13_rollback_provenance_fix'`)
  * `schema_name TEXT NOT NULL` (`'public'`)
  * `table_name TEXT NOT NULL` (`'order_customizations'`)
  * `table_oid OID NOT NULL`
  * `index_name TEXT NOT NULL` (`'idx_order_customizations_session_id'`)
  * `index_oid OID NOT NULL`
  * `index_def TEXT NOT NULL` (`pg_get_indexdef(index_oid)`)
  * `created_by_migration BOOLEAN NOT NULL` (`TRUE` only when created by this migration)
  * `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

---

## 2. Decision Matrix Across All Scenarios

| Scenario | Migration Behavior | Rollback Behavior |
|---|---|---|
| **No covering index exists** | Creates `idx_order_customizations_session_id` and records `table_oid`, `index_oid`, `index_def`, `created_by_migration = TRUE` atomically. | Verifies provenance row, `table_oid`, `index_oid`, `relname`, and `pg_get_indexdef(index_oid) = index_def`; drops `public.idx_order_customizations_session_id` and removes provenance/empty `m13_internal`. |
| **Exact target index pre-exists (valid)** | Skips creation; writes **no** provenance row. | Sees no provenance row; preserves index (`0` drops). |
| **Equivalent valid index under another name** | Skips creation; writes **no** provenance row. | Sees no provenance row; preserves equivalent index (`0` drops). |
| **Target index name exists with incompatible definition** | Raises `EXCEPTION` and aborts transaction. | N/A (zero partial changes). |
| **Provenance missing** | N/A | Sees no provenance row; preserves index (`0` drops). |
| **Index dropped & recreated, renamed, altered, or provenance tampered** | Reruns fail closed if existing provenance mismatches live catalog. | Detects `index_oid`, `table_oid`, `relname`, `index_def`, or `created_by_migration` mismatch; **fails closed** (`RAISE EXCEPTION`) and preserves index. |
