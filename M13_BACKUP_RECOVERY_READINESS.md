# JCCF Subsystem M13 — Backup and Disaster Recovery Readiness Assessment
**Document Version:** 1.0  
**Status:** Pre-Execution Safety Assessment (READ-ONLY)  
**Governing Migration Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Governing Rollback Commit:** `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`  
**Authorization Status:** Decision 4 (D4) and Decision 5 (D5) remain **NOT AUTHORIZED**.

---

## 1. Executive Summary

Executing a schema migration against a shared database environment introduces inherent risks of service disruption, accidental object collisions, and unrecoverable data loss. This document establishes the backup prerequisites, Point-In-Time-Recovery (PITR) parameters, restoration procedures, and operational boundaries required before any future staging execution of M13 DDL.

**Core Finding:** The M13 migration exclusively creates new tables and a namespaced utility function; it modifies zero existing shared tables. However, rollback scripts execute `DROP TABLE ... RESTRICT`, which permanently destroys all session and order data created after migration execution. Therefore, a verified pre-migration backup remains a mandatory prerequisite before D4 authorization.

---

## 2. B1: Inventory of Affected Database Objects

| Object Name | Object Type | Action | Classification | Description |
|---|---|---|---|---|
| `public.personalization_templates` | Table | Create | `Created` | Stores book definitions (e.g. PetStory 24p) |
| `public.customization_sessions` | Table | Create | `Created` | Guest customization state & draft payloads |
| `public.order_customizations` | Table | Create | `Created` | 15 columns: customer PII, tokens, renders |
| `public.m13_set_updated_at()` | Function | Create | `Created` | Isolated timestamp trigger procedure |
| `trg_templates_updated_at` | Trigger | Create | `Created` | Fires on templates `BEFORE UPDATE` |
| `trg_sessions_updated_at` | Trigger | Create | `Created` | Fires on sessions `BEFORE UPDATE` |
| `trg_orders_updated_at` | Trigger | Create | `Created` | Fires on orders `BEFORE UPDATE` |
| `idx_sessions_token_hash` | Index | Create | `Created` | Lookup index on `session_token_hash` |
| `idx_sessions_expires_at` | Index | Create | `Created` | Pruning index on `expires_at` |
| `idx_orders_download_token_hash` | Index | Create | `Created` | Token lookup index |
| `idx_orders_fulfillment_status` | Index | Create | `Created` | Worker polling queue index |
| `idx_orders_order_number` | Index | Create | `Created` | E-commerce reference index |
| `personalization_templates_select_anon` | RLS Policy | Create | `Created` | Anonymous template read |
| `personalization_templates_select_authenticated`| RLS Policy | Create | `Created` | Authenticated template read |
| `customization_sessions_service_role_all` | RLS Policy | Create | `Created` | Service role session management |
| `order_customizations_service_role_all` | RLS Policy | Create | `Created` | Service role order management |
| `public.products` | Table | Reference | `Dependent` | Optional foreign key target (if present) |
| Core Supabase Auth / Storage Schemas | Schema | None | `Unaffected` | `auth.*`, `storage.*` untouched by SQL |

---

## 3. B2: Backup Requirements Prior to Staging Execution

Before executing any DDL in the Supabase staging environment, the staging database owner must complete and document the following backup artifacts:

1. **Logical Schema Snapshot (`pg_dump --schema-only`):**
   * Scope: Complete database schema export, including grants, triggers, extensions, and RLS policies.
   * Command: `pg_dump -h <host> -U postgres -d postgres --schema-only --no-owner --no-privileges -f staging_pre_m13_schema.sql`
2. **Logical Data Snapshot (`pg_dump --data-only`):**
   * Scope: All pre-existing production/staging tables (`public.*`, `auth.users`).
   * Command: `pg_dump -h <host> -U postgres -d postgres --data-only -F c -b -v -f staging_pre_m13_data.dump`
3. **Supabase Platform Snapshot / PITR Tag:**
   * In Supabase Dashboard -> Database -> Backups, generate a manual snapshot or record the exact timestamp (ISO 8601 UTC) to enable Point-In-Time-Recovery.
4. **Storage Bucket Inventory:**
   * Record existing storage bucket definitions (`storage.buckets`) to confirm zero name collisions with `petstory-assets`.

### Staging Owner Backup Evidence Sign-Off Table (Pre-Execution Prerequisite)
```
[ ] Backup Execution Timestamp (UTC): ________________________
[ ] Backup Storage Location (S3 / Encrypted Vault): ________________________
[ ] Backup SHA-256 Checksum: ________________________
[ ] Backup Size (Bytes): ________________________
[ ] Sign-Off Platform Engineer / DBA: ________________________
```

---

## 4. B3: Database Restoration Procedure

If migration execution encounters an unrecoverable failure or damages existing staging state, the operator must execute this sequence:

```
[MIGRATION FAILURE / UNRECOVERABLE DRIFT]
                    │
                    ▼
       1. HALT EXECUTION & ABORT
                    │
                    ▼
       2. EVALUATE FAILURE SEVERITY
       ├── Schema Isolated? ──► Execute SQL Rollback Script
       └── Database Corrupted? ──► Execute Full Snapshot Restoration
                    │
                    ▼
       3. RESTORATION FROM DUMP
       ├── Step A: Terminate active client connections
       ├── Step B: Drop modified/corrupted staging database
       ├── Step C: Re-create empty target database with extensions
       ├── Step D: Restore schema from logical backup
       └── Step E: Restore data payloads using pg_restore
                    │
                    ▼
       4. POST-RESTORATION VERIFICATION
       ├── Validate table counts against pre-migration baseline
       ├── Verify auth.users and core product tables intact
       └── Confirm RLS policies re-enabled
```

### Detailed Command Execution for Full Disaster Restoration:
```bash
# Terminate connections
psql -h $DB_HOST -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'postgres' AND pid <> pg_backend_pid();"

# Restore database from custom-format archive
pg_restore -h $DB_HOST -U postgres -d postgres -v --clean --if-exists staging_pre_m13_data.dump
```

---

## 5. B4: Recovery Point Objective (RPO) and Recovery Time Objective (RTO)

* **Staging Environment RPO:** **0 seconds** of data loss for pre-existing tables (`public.products`, etc.).
  * For M13 tables: Staging contains zero live customer transactions. Re-running migration produces 0 data loss.
* **Staging Environment RTO:** **15 minutes**.
  * Complete restoration of a staging Supabase instance via logical dump or PITR restore completes in under 15 minutes.
* **Production Anticipated Targets (G4 Spec):**
  * Production RPO: < 1 minute (enabled via Supabase Continuous Archiving / WAL archiving).
  * Production RTO: < 30 minutes for complete cluster failover.

---

## 6. B5: Recovery Testing & Verification Status

* **Static Procedure Validation:** Documented and verified against standard PostgreSQL 15 `pg_dump` / `pg_restore` semantics.
* **Automated CI Container Recovery:** Verified in GitHub Actions CI (Run `43277854888`): Scenarios run in ephemeral databases with complete teardown and re-creation between test cases.
* **Live Supabase Staging Restore:** **NOT VERIFIED — LIVE ENVIRONMENT REQUIRED**.
  * Formal restoration cannot be tested on Supabase without explicit D4 authorization and staging instance provisioning.

---

## 7. B6: SQL Rollback vs. Full Disaster Recovery

It is critical to distinguish between executing `migrations/20261112_001_personalization_engine_rollback.sql` and performing a full database restoration:

| Dimension | SQL Rollback (`rollback.sql`) | Full Database Restoration (`pg_restore`) |
|---|---|---|
| **Scope** | Targets only M13 objects (`templates`, `sessions`, `orders`, `m13_set_updated_at`) | Reverts entire database to pre-migration snapshot |
| **Duration** | < 1 second | 5 to 15 minutes |
| **Target Data Impact** | **Permanently deletes** all M13 sessions, custom messages, and order history via `DROP TABLE ... RESTRICT` | Reverts all database tables (including external tables) to snapshot time |
| **External Table Impact**| Zero impact on external tables (`public.products` remains untouched) | External tables lose any writes made since snapshot |
| **Prerequisites** | M13 objects must still exist and retain exact expected RLS policies and trigger definitions | Clean database instance and valid dump file required |
| **Failure Modes** | Aborts if external foreign keys reference M13 tables (`RESTRICT` mode) | Requires downtime / exclusive database lock |

### Rollback Limitation Risk Matrix
| Risk Factor | Consequence | Mitigation Enforced in M13 |
|---|---|---|
| Post-Migration Data Loss | Active customer orders dropped if rollback run in production | Rollback strictly permitted during initial deployment window; never in mature production without data export |
| Unrelated Foreign Key Dependency | `DROP TABLE ... RESTRICT` fails if third-party table references M13 | Explicitly designed with `RESTRICT`; halts rollback to prevent cascading data destruction |
| Modified RLS Policy | Rollback aborts if someone manually altered policy roles | F6 Remediation checks exact role array; aborts safely rather than dropping unknown configurations |

---

## 8. B7: Recovery Readiness Verdict

**Verdict:** `READY WITH CONDITIONS`

### Mandatory Conditions Prior to Execution:
1. Staging database owner must capture a confirmed logical backup (`pg_dump`) immediately prior to migration.
2. PITR snapshot timestamp must be logged in the preflight execution checklist.
3. The operator must confirm that no production customer data resides in the target staging database.
4. Final execution must proceed only after D4 owner authorization.

