# JCCF M13 — Supabase Migration-History Reconciliation
**Document ID:** `JCCF-M13-MIGRATION-HISTORY-RECON`
**Date:** November 13, 2026
**Target Project:** `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `PostgreSQL 17.11`)

---

## 1. Current State Distinction

1. **Database Schema State:** M13 tables (`personalization_templates`, `customization_sessions`, `order_customizations`), `m13_set_updated_at()`, 3 triggers, and 4 RLS policies are deployed and verified (`PMV-01`..`PMV-11` passed).
2. **Repository Migration Files:** Stored in `migrations/` (`20261112_001_personalization_engine.sql` + `20261113_1335_m13_production_hardening.sql`), outside `supabase/migrations/`.
3. **Supabase Migration Ledger (`supabase_migrations.schema_migrations`):** Does **not** exist on `ammsjbcpbspisbyynaga` (`A4_ledger_schema = []`).
4. **CLI Migration Tracking State:** Project is linked (`supabase/.temp/linked-project.json`), but no `supabase/migrations/` directory or ledger tracking is active.

---

## 2. Why Manual Ledger Inserts Are Unsafe

* Manually running `INSERT INTO supabase_migrations.schema_migrations` is unsupported by Supabase CLI, bypasses schema/table initialization (`supabase_migrations` schema creation, column/constraint defaults, statement/hash tracking), and risks breaking future `supabase db push` / `supabase migration list` runs.

---

## 3. Recommended Supported Workflow (Future Reconciliation)

1. **Short-Term (Current Corrective Migration):** Continue executing the corrective hardening migration via the verified persistent interactive `psql \i` protocol ([M13_CORRECTIVE_PRODUCTION_EXECUTION_PLAN.md](M13_CORRECTIVE_PRODUCTION_EXECUTION_PLAN.md)), keeping a single consistent execution mechanism.
2. **Long-Term (When Adopting `supabase db push`):**
   * Copy/convert migrations into `supabase/migrations/` using strict 14-digit Supabase CLI timestamps (`YYYYMMDDHHMMSS_<name>.sql`, e.g., `20261112000001_personalization_engine.sql` and `20261113133500_m13_production_hardening.sql`).
   * Use the supported Supabase CLI command to mark already-applied migrations in `supabase_migrations.schema_migrations` without re-executing their DDL:
     ```bash
     npx supabase migration repair --status applied 20261112000001
     npx supabase migration repair --status applied 20261113133500
     ```
   * Verify with `npx supabase migration list` before ever running `npx supabase db push`.
3. **Authorization Note:** Do **not** run `supabase db push` or `supabase migration repair` against `ammsjbcpbspisbyynaga` without separate owner authorization.

