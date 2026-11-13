# JCCF Subsystem M13 — D4 Local Supabase Backup & Recoverability Report
**Document ID:** `JCCF-M13-D4-LOCAL-BACKUP-REPORT`  
**Document Version:** 1.0  
**Date:** November 13, 2026  
**Repository:** `https://github.com/janzlebiz/JCCF`  
**Target Project:** JCCF (Personalization Engine)  
**Supabase Project Reference:** `ammsjbcpbspisbyynaga`  
**Target Database Engine:** PostgreSQL 17.11  
**Supabase CLI Version:** `3.1.0`  
**Status:** Pre-Execution Safety Artifact — Temporary Owner-Approved Risk Mitigation  
**Execution State:** `BLOCKED PENDING OPERATOR STAGING CREDENTIAL RELEASE`

---

## 1. Executive Summary & Context

To support the conditional authorization of Decision 4 (D4) while maintaining capital discipline, the project owner approved a **Local Logical Backup strategy as a temporary risk mitigation**. Under this policy, expensive Supabase paid plan upgrades (such as daily managed physical backups, 7-day Point-in-Time-Recovery, and branching add-ons) are intentionally deferred until the PetStory personalized keepsake generates sufficient commercial sales revenue to justify platform overhead.

This report establishes the local logical backup protocol, documents the execution behavior of the Supabase CLI (`3.1.0`) against project `ammsjbcpbspisbyynaga`, identifies two specific infrastructure boundaries that currently prevent unauthenticated local extraction, and defines the exact restoration procedure required to verify recoverability into a disposable PostgreSQL 17 environment.

---

## 2. Supabase Target Project Identification

* **Project Name:** JCCF
* **Project Reference ID:** `ammsjbcpbspisbyynaga`
* **Direct Database Hostname:** `db.ammsjbcpbspisbyynaga.supabase.co`
* **Direct Host IP (DNS AAAA):** `2406:da12:557:f802:7f91:c16:3244:d046` (IPv6 unicast)
* **Target Engine Version:** PostgreSQL 17.11 (GA release channel)
* **Cloud Infrastructure:** AWS Asia Pacific Region

---

## 3. Supabase CLI Local Backup Protocol

The approved local logical backup must capture three independent SQL artifacts into a dedicated, timestamped local directory:

```
backups/
└── staging_backup_ammsjbcpbspisbyynaga_20261113_UTC/
    ├── roles_ammsjbcpbspisbyynaga.sql      # Database roles & permissions (--role-only)
    ├── schema_ammsjbcpbspisbyynaga.sql     # Complete DDL, RLS, functions, triggers
    ├── data_ammsjbcpbspisbyynaga.dump      # Pre-existing data payloads (--data-only)
    └── checksums.sha256                   # Cryptographic verification manifest
```

### 3.1 CLI Execution Commands:
1. **Roles Backup:**
   ```bash
   npx supabase db dump --remote=<target> --role-only -f backups/roles.sql
   ```
2. **Schema Backup:**
   ```bash
   npx supabase db dump --remote=<target> -f backups/schema.sql
   ```
3. **Data Backup:**
   ```bash
   npx supabase db dump --remote=<target> --data-only --use-copy -f backups/data.sql
   ```

### 3.2 Git & Security Invariants:
* **Zero Secret Logging:** Connection strings, passwords, and personal access tokens are strictly prohibited from appearing in terminal logs, git commit history, or documentation artifacts.
* **Git Exclusion (`.gitignore`):** The `backups/` directory must be permanently excluded from version control to prevent exposing database dumps or PII.

---

## 4. Execution Obstacles & Technical Investigation

During the initial execution attempt using Supabase CLI `3.1.0`, two distinct technical obstacles were encountered:

### 4.1 Obstacle 1: Authorization Boundary (HTTP 403 Forbidden)
* **Observed CLI Behavior:** When querying the Supabase Management API for project `ammsjbcpbspisbyynaga`, the API returned:
  ```json
  {
    "code": "ProjectsApiKeysUnexpectedStatusError",
    "message": "unexpected get api keys status 403: {\"message\":\"Your account does not have the necessary privileges to access this endpoint. For more details, refer to our documentation https://supabase.com/docs/guides/platform/access-control\"}"
  }
  ```
* **Root Cause Analysis:** The active Supabase CLI access token stored in the local Windows Credential Manager belongs to an account with access to organization `fpyqttksvcgqjuuipfei` (project `Agila-Hub-BEEC`, ref `jgpigkeekfuawbyilycq`). It does **not possess role privileges or organizational membership** for project `ammsjbcpbspisbyynaga`.
* **Remediation Required:** The project owner or designated staging administrator must provide an access token with administrative privileges on project `ammsjbcpbspisbyynaga`, or authenticate via the Supabase Plugin interface.

### 4.2 Obstacle 2: Network Protocol Constraint (`DbConfigIpv6Error`)
* **Observed CLI Behavior:** When attempting direct database extraction, the CLI produced:
  ```json
  {
    "code": "DbConfigIpv6Error",
    "message": "IPv6 is not supported on your current network",
    "suggestion": "Pass the project's connection pooler URL with --remote=<pooler db-url> to connect over IPv4."
  }
  ```
* **Root Cause Analysis:** Supabase directs default database connections to `db.ammsjbcpbspisbyynaga.supabase.co`, which resolves exclusively to an IPv6 address (`2406:da12:557:f802:7f91:c16:3244:d046`). The local development workstation operates on an IPv4-only local network interface without global IPv6 routing.
* **Remediation Required:** For environments lacking global IPv6 connectivity, Supabase requires connecting through its IPv4 connection pooler (Supavisor) on port 6543 or 5432 using a connection URI:
  ```bash
  npx supabase db dump --remote="postgresql://postgres.ammsjbcpbspisbyynaga:[PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres" -f backups/schema.sql
  ```

---

## 5. Local Logical Backup vs. Managed Enterprise Backup

| Dimension | Temporary Local Logical Backup (Approved Mitigation) | Supabase Pro Managed Backup (Deferred) |
|---|---|---|
| **Storage Location** | Local workstation / encrypted offline storage | Managed AWS S3 / Supabase Cloud Vault |
| **Recovery Point Objective (RPO)** | Snapshot point-in-time of dump execution | Continuous WAL archiving (< 1 minute RPO) |
| **Recovery Time Objective (RTO)** | ~15–30 minutes (Manual `psql` / `pg_restore`) | ~5–15 minutes (One-click Dashboard PITR) |
| **Storage Buckets & Auth** | Database tables & roles only; storage objects excluded | Full platform state (tables, auth users, storage objects) |
| **Monthly Operating Overhead** | **$0.00 / month** (Owner-approved for MVP bootstrap) | **+$25.00 to +$100.00 / month** (Pro tier + PITR addon) |
| **Commercial Alignment** | Appropriate for pre-revenue digital MVP | Mandatory when processing > 50 daily live customer orders |

---

## 6. Part C: Backup Recoverability Verification Procedure

To ensure that the captured local backup is genuine and recoverable, the operator must execute this verification sequence in an isolated local PostgreSQL 17 container before applying any DDL:

```
[LOCAL BACKUP SQL ARTIFACTS]
              │
              ▼
 1. PROVISION DISPOSABLE LOCAL POSTGRESQL 17 INSTANCE
 ├── Port: 5433 (Isolated from production)
 └── Database: jccf_recovery_test_db
              │
              ▼
 2. EXECUTE RESTORATION SEQUENCE
 ├── Step A: Restore cluster roles (roles.sql)
 ├── Step B: Restore schemas, functions, and RLS (schema.sql)
 └── Step C: Restore data records (data.sql)
              │
              ▼
 3. SCHEMA INTEGRITY AUDIT
 ├── Verify information_schema.tables count matches source
 ├── Confirm pg_roles contains required Supabase roles
 ├── Confirm RLS policies are attached and active
 └── Validate row counts across pre-existing tables
              │
              ▼
 4. TEARDOWN DISPOSABLE RECOVERY CONTAINER
 └── DROP DATABASE jccf_recovery_test_db;
```

### Managed Supabase Restoration Boundary:
* **NEVER RESTORE OVER LIVE SUPABASE PROJECT:** The recovery verification test must run exclusively in a local disposable PostgreSQL 17 environment. Attempting a full restore over a live Supabase project can cause unrecoverable state loss.
* **No `DROP DATABASE postgres` on Cloud:** Managed Supabase does not permit dropping the system database. Disaster restoration must use table-level `pg_restore --clean --if-exists` or the Supabase Management Console.

---

## 7. Current Readiness Verdict

**Verdict:** `STAGE B BLOCKED PENDING BACKUP EXTRACTION PREREQUISITES`.

1. **PostgreSQL 17 Engine Compatibility:** `PASS` (Verified locally and in CI).
2. **Local Backup Extraction:** `BLOCKED` (Requires authorized Supabase token or IPv4 connection pooler URL for project `ammsjbcpbspisbyynaga`).
3. **Execution Safety Boundary:** Physical DDL execution (`migrations/20261112_001_personalization_engine.sql`) remains strictly prohibited until Stage B prerequisites are fulfilled.

