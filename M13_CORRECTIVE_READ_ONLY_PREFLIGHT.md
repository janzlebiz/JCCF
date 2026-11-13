# JCCF M13 — Corrective Read-Only Production Preflight
**Document ID:** `JCCF-M13-CORRECTIVE-PREFLIGHT`
**Date:** November 13, 2026
**Inspection Timestamp (UTC):** `2026-11-13T05:29:42.833738+00:00`
**Project Reference:** `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `ACTIVE_HEALTHY`)
**PostgreSQL Version:** `PostgreSQL 17.11 on aarch64-unknown-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit`
**Repository:** `https://github.com/janzlebiz/JCCF` (`main` @ `ee41534397d92412c5dded7b2f66ac7c49eda542`; `21a646e4c60017144ace8f05b9745751d0a0d561` verified ancestor)
**Database Identity:** `current_database() = postgres`, `current_user = postgres`, `session_user = postgres`
**Execution Method:** Python `psycopg2` over IPv4 Session Pooler (`aws-1-ap-northeast-2.pooler.supabase.com:5432`, `sslmode=require`) with `conn.set_session(readonly=True, autocommit=True)` — **100% read-only**.

---

## A1. Live Function Definition (`public.m13_set_updated_at()`)

| Property | Observed Production Value |
|---|---|
| **OID** | `17645` |
| **Owner** | `postgres` |
| **Language** | `plpgsql` |
| **Arguments** | `0` (`""`) |
| **Return Type** | `trigger` |
| **Security Mode** | `prosecdef = false` (`SECURITY INVOKER`) |
| **`proconfig`** | `NULL` (**Finding 1 confirmed:** no fixed `search_path`) |
| **`provolatile`** | `v` (`VOLATILE`) |
| **Source (`prosrc`)** | `BEGIN NEW.updated_at = now(); RETURN NEW; END;` |
| **Raw ACL (`proacl`)** | `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` |
| **Effective `EXECUTE`** | `public = true`, `anon = true`, `authenticated = true`, `service_role = true`, `postgres = true` (**Finding 2 confirmed**) |

---

## A2. Existing Trigger Dependencies

All 3 expected M13 triggers exist, are enabled (`tgenabled = 'O'`), and reference `public.m13_set_updated_at()` (`tgfoid = 17645`):

| Table | Trigger Name | Timing | Event | Enabled | Function OID & Signature |
|---|---|---|---|---|---|
| `public.personalization_templates` | `trg_personalization_templates_updated_at` | `BEFORE` | `UPDATE` | `O` | `17645` (`m13_set_updated_at()`) |
| `public.customization_sessions` | `trg_customization_sessions_updated_at` | `BEFORE` | `UPDATE` | `O` | `17645` (`m13_set_updated_at()`) |
| `public.order_customizations` | `trg_order_customizations_updated_at` | `BEFORE` | `UPDATE` | `O` | `17645` (`m13_set_updated_at()`) |

---

## A3. Exact Index & Foreign-Key Inspection (`public.order_customizations`)

### Existing Indexes
| Index Name | Access Method | Indexed Columns | Unique | Partial | Valid / Ready | Expression |
|---|---|---|---|---|---|---|
| `idx_order_customization_order` | `btree` | `['order_id']` | `false` | `false` | `true` / `true` | `false` |
| `idx_order_download_token_hash` | `btree` | `['download_token_hash']` | `false` | `false` | `true` / `true` | `false` |
| `order_customizations_download_token_hash_key` | `btree` | `['download_token_hash']` | `true` | `false` | `true` / `true` | `false` |
| `order_customizations_pkey` | `btree` | `['id']` | `true` | `false` | `true` / `true` | `false` |
| `uq_order_customization_order` | `btree` | `['order_id']` | `true` | `false` | `true` / `true` | `false` |

**Finding 3 Confirmed:** Zero existing indexes cover `session_id` as their leading key column.

### Foreign Key (`order_customizations_session_id_fkey`)
* **Source:** `order_customizations(session_id)` $\rightarrow$ **Referenced:** `customization_sessions(id)`
* **Actions:** `confupdtype = 'a'` (`NO ACTION`), `confdeltype = 'r'` (`RESTRICT`), `convalidated = true`.

---

## A4. Supabase Migration-History Inspection

* **`supabase_migrations` Schema:** Absent (`[]`).
* **`supabase_migrations.schema_migrations` Table:** Does not exist (`UndefinedTable` confirmed).
* **Repository Migration Files:** `migrations/20261112_001_personalization_engine.sql` (and rollback) reside in `migrations/`, outside `supabase/migrations/`.
* **Reconciliation:** Documented in [M13_MIGRATION_HISTORY_RECONCILIATION.md](M13_MIGRATION_HISTORY_RECONCILIATION.md). No ledger modifications were performed.

---

## A5. Out-of-Scope Function (`public.rls_auto_enable()`)

* **OID:** `17519`, **Owner:** `postgres`, **Language:** `plpgsql`, **Security:** `prosecdef = true` (`SECURITY DEFINER`), **`proconfig`:** `["search_path=pg_catalog"]`.
* **ACL:** `{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}` (`anon` and `authenticated` hold `EXECUTE = true`).
* **Status:** Out of scope for M13 corrective hardening; untouched and logged as a separate platform-security work item.

