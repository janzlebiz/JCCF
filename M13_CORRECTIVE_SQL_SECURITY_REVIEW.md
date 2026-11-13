# JCCF M13 — Corrective SQL & Security Review
**Document ID:** `JCCF-M13-CORRECTIVE-SEC-REVIEW`
**Date:** November 13, 2026
**Artifacts Reviewed:**
* `migrations/20261113_1335_m13_production_hardening.sql` (SHA-256 `4F74EC3B6660B49367639B0AD1981AA637F1D130F00C8E66163F46B23594A5EA`)
* `migrations/20261113_1335_m13_production_hardening_rollback.sql` (SHA-256 `3D10A9C212250C270FC4E337B1539ED51B78BD0D42C29B09AD9D6F62AE8347C6`)

---

## 1. Statement-by-Statement Classification

### Corrective Migration (`20261113_1335_m13_production_hardening.sql`)
| Section | Statement | Classification | Purpose & Safety |
|---|---|---|---|
| `BEGIN;` / `COMMIT;` | Explicit transaction boundaries | Transaction Control | Atomic all-or-nothing execution |
| `0.1`–`0.5` `DO $$ ... $$` | Catalog inspection & `RAISE EXCEPTION` | Read-Only (procedural guard) | Fail-closed precondition verification; zero mutations |
| `1` | `ALTER FUNCTION public.m13_set_updated_at() SET search_path = pg_catalog;` | DDL | Fixes mutable `search_path` without altering body/owner/mode |
| `2` | `REVOKE ALL ON FUNCTION public.m13_set_updated_at() FROM PUBLIC, anon, authenticated, service_role;` | DCL | Removes unnecessary direct `EXECUTE`; owner `postgres` retains `EXECUTE` |
| `3` `DO $$ ... $$` | Conditional `CREATE INDEX idx_order_customizations_session_id ON public.order_customizations (session_id);` | DDL | Adds missing FK index only if no valid covering index exists |

* **Unintended DML:** `0` DML statements (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`).

### Corrective Rollback (`20261113_1335_m13_production_hardening_rollback.sql`)
| Section | Statement | Classification | Purpose & Safety |
|---|---|---|---|
| `BEGIN;` / `COMMIT;` | Explicit transaction boundaries | Transaction Control | Atomic rollback |
| `DO $$ ... $$` | Conditional `ALTER FUNCTION public.m13_set_updated_at() RESET search_path;` | Read-Only + DDL | Resets `search_path` only if set to `pg_catalog` |
| `GRANT` | `GRANT EXECUTE ON FUNCTION public.m13_set_updated_at() TO PUBLIC, anon, authenticated, service_role;` | DCL | Restores exact Phase A baseline ACL |
| `DROP INDEX` | `DROP INDEX IF EXISTS public.idx_order_customizations_session_id;` | DDL | Removes only the corrective index |

---

## 2. Security & Compatibility Checklist

| Review Dimension | Assessment |
|---|---|
| **SQL Injection & Dynamic SQL** | Zero `EXECUTE format(...)` or user-input string interpolation. All identifiers are static literals. |
| **Search-Path Vulnerabilities** | `SET search_path = pg_catalog` eliminates object-shadowing attacks; compatible with `now()` (`pg_catalog.now()`) and PL/pgSQL `NEW` record in PG 17.11. |
| **Excessive Privileges & ACL** | `REVOKE ALL ... FROM PUBLIC, anon, authenticated, service_role` leaves `{postgres=X/postgres}`. Trigger execution is unaffected because PostgreSQL invokes trigger functions internally without requiring caller `EXECUTE`. |
| **SECURITY DEFINER Risk** | Function remains `SECURITY INVOKER` (`prosecdef = false`). Precondition `0.2` aborts if `prosecdef` is `true`. |
| **Index Duplication & Locking** | Precondition `0.5` & Section `3` inspect `pg_index` for any valid non-partial, non-expression index with `session_id` as `indkey[0]`. Transactional `CREATE INDEX` acquires `SHARE` lock on `order_customizations` (`0` rows, `0` active consumers; `lock_timeout = 5000ms` bounds wait). |
| **Ownership & Unrelated Objects** | Zero ownership changes; `public.rls_auto_enable()` and original M13 tables/policies/triggers untouched. |
| **Rollback Completeness** | Reverses all 3 changes back to exact Phase A baseline (`proconfig = NULL`, exact baseline ACL, index dropped) without dropping M13 tables or data. |
| **Remaining Risk** | Out-of-scope `public.rls_auto_enable()` (`SECURITY DEFINER`) retains `anon`/`authenticated` `EXECUTE` as a Supabase platform object; tracked separately. |

