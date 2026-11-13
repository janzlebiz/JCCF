# JCCF Subsystem M13 — Production Backup and Recovery Report
**Document ID:** `JCCF-M13-PROD-BACKUP-RECOVERY`  
**Document Version:** 1.0  
**Date:** November 13, 2026  
**Target Environment:** **JCCF Production Supabase Project** (`ammsjbcpbspisbyynaga`, `ap-northeast-2`, `PostgreSQL 17.11`)  
**Status:** Fresh Production Recovery Point Captured & Verified on PostgreSQL 17.11

---

## 1. Fresh Production Recovery Point (Phase D1)

* **Backup Directory (Outside Git):** `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC`
* **Capture Window (UTC):** `2026-11-13T03:03:12.412693+00:00` $\rightarrow$ `2026-11-13T03:04:02.578312+00:00`
* **Connection Method:** IPv4 Session Pooler (`aws-1-ap-northeast-2.pooler.supabase.com:5432`, user `postgres.ammsjbcpbspisbyynaga`, `sslmode=require`, local `%APPDATA%\postgresql\pgpass.conf`).
* **Dump Tooling:** `pg_dump (PostgreSQL) 17.11` and `pg_dumpall (PostgreSQL) 17.11` using Supabase CLI `3.1.0` schema/table exclusion lists.
* **Execution Result:** `roles=0`, `schema=0`, `data=0` (`0` warnings/errors).

| Artifact | Size (Bytes) | SHA-256 Checksum | Contents |
|---|---|---|---|
| `roles.sql` | `6301` | `F86A00F97E6FD712EFBA0FC28A86A8BA205E3A0A037B9CE55E2B11C6FBBE6BDB` | Cluster roles (`--roles-only --no-role-passwords`) |
| `schema.sql` | `39515` | `7CE743085F704C9F1D5683ECB3D7B8C75DCA2D2514A407172BE647EDBF99F6BB` | `public` schema DDL & extensions (`--schema-only`) |
| `data.sql` | `4750` | `1B0F32E27FC3B63A89169ECA2396603EE7F6604BF5E4F0AA088A8DCBC70CF77A` | `0` application rows (`auth.refresh_tokens_id_seq` setval only) |
| `backup_metadata.json` | — | Recorded in `checksums.sha256` | Capture telemetry & exclusions (`0` secrets) |
| `checksums.sha256` | — | — | SHA-256 manifest |

*(Historical reference: earlier pre-transition backup `D:\JCCF_SECURE_BACKUPS\M13\staging_backup_ammsjbcpbspisbyynaga_20261113_022827_UTC` is retained as historical audit evidence only and superseded by `prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC`.)*

---

## 2. Disposable PostgreSQL 17.11 Restore Verification

* **Target:** Disposable local `PostgreSQL 17.11` cluster (port `5434`, database `jccf_prod_restore_verify`, destroyed immediately after verification).
* **Restore Return Codes:** `roles=0`, `schema=0`, `data=0`.
* **Verified Restored State:**
  - `roles_check`: `anon,authenticated,authenticator,service_role,supabase_admin`
  - `schemas_check`: `extensions,public,vault`
  - `public_tables`: `NONE (0 tables)` (matches production)
  - `public_funcs`: `rls_auto_enable` (matches production)
  - `event_triggers`: `ensure_rls` (matches production)

---

## 3. Supabase Platform Recovery & Explicit Limitations (Phase D2)

* **Supabase Plan Status:** Free tier (`ammsjbcpbspisbyynaga`). Managed daily physical backups and Point-in-Time Recovery (PITR) are **not available** on the Free plan. No paid plan upgrade is authorized without owner approval.
* **Logical Backup Limitations (Explicit):**
  1. A local logical PostgreSQL dump is **not** a complete Supabase platform backup.
  2. Supabase-managed internal schemas (`auth`, `storage`, `realtime`, `vault`, `extensions`, `pgsodium`, `supabase_migrations`, etc.) and platform configuration (API keys, JWT secret, Auth providers, Edge Functions, Storage policies) are excluded or platform-managed.
  3. Vanilla PostgreSQL 17.11 restoration cannot reproduce Supabase-managed platform components (`supabase_vault`, `extensions.pgrst_*`, `extensions.grant_pg_*`).
  4. Auth and Storage require separate export/recovery procedures once user data or objects exist (currently `0` Auth users, `0` Storage buckets, `0` Storage objects).
* **Recommended Production Recovery Strategy:**
  - Pre-revenue / current state (`0` live customer rows): Use the verified local logical backup + `migrations/20261112_001_personalization_engine_rollback.sql` (`RESTRICT` only, zero `CASCADE`).
  - Before processing live paid customer orders in production: Upgrade to Supabase Pro (+PITR if needed) with explicit owner approval.

