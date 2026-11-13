# JCCF Subsystem M13 — Production Change Plan
**Document ID:** `JCCF-M13-PROD-CHANGE-PLAN`  
**Document Version:** 1.0  
**Date:** November 13, 2026  
**Target Project:** `JCCF` (`ammsjbcpbspisbyynaga`, `ap-northeast-2`, `PostgreSQL 17.11`)  
**Status:** Pending Explicit Operator Release (`AUTHORIZE M13 PRODUCTION MIGRATION EXECUTION`)

---

| # | Change Plan Element | Specification |
|---|---|---|
| **1** | **Purpose & Scope** | Deploy M13 Interactive Personalization Engine schema (`personalization_templates`, `customization_sessions`, `order_customizations`) for PetStory 24-page PDF MVP. |
| **2** | **Target Project Ref** | `ammsjbcpbspisbyynaga` (`JCCF`, `ap-northeast-2`, `PostgreSQL 17.11.0.019`), via IPv4 Session Pooler (`aws-1-ap-northeast-2.pooler.supabase.com:5432`). |
| **3** | **Artifact Identities** | **Migration:** `migrations/20261112_001_personalization_engine.sql` (Commit `e624e95f74932441dfee90cad7a9cb4544f64d6d`, Blob `679f5a8086fb1070e39b7f0cef4b5b381999ce78`, SHA-256 `9D6579BC93842C57E3EA03C93F3802CF2D89C5A5F0DB6D81D64A3826BF148B6E`).<br>**Rollback:** `migrations/20261112_001_personalization_engine_rollback.sql` (Commit `f9a4eb3fc2fd6b5a1645b8c962e51596758a9ed4`, Blob `e7b1c60ef9ab5ddb96d3512262db6a700e2fc9bf`, SHA-256 `73725DF9716772A355EC159117F2DD68DB5720C00B1F2C5AB967A13C63EF10F4`). |
| **4** | **Production Backup Ref** | `D:\JCCF_SECURE_BACKUPS\M13\prod_backup_ammsjbcpbspisbyynaga_20261113_030312_UTC` (`roles.sql` `F86A00F9...`, `schema.sql` `7CE74308...`, `data.sql` `1B0F32E2...`). |
| **5** | **Preflight Results** | `11/11 PASS` (`PF-01`..`PF-11`, `2026-11-13T02:57:40Z–42Z`): PG 17.11, `gen_random_uuid()` OK, `anon`/`authenticated`/`service_role` present, 0 collisions. |
| **6** | **Expected Objects** | `3` tables (`personalization_templates`, `customization_sessions`, `order_customizations`), `1` function (`public.m13_set_updated_at()`), `3` triggers, `4` RLS policies (`FORCE ROW LEVEL SECURITY`), `2` internal FKs, indexes & grants. |
| **7** | **Locks & App Impact** | Zero table locks on existing traffic (`0` existing public tables, `0` active consumers). |
| **8** | **Execution Sequence** | 1) Reconfirm Git repo/branch/HEAD/clean tree; 2) Reconfirm `ammsjbcpbspisbyynaga` & PG 17.11; 3) Reconfirm backup checksums; 4) Reconfirm migration/rollback SHA-256; 5) Obtain explicit `AUTHORIZE M13 PRODUCTION MIGRATION EXECUTION`; 6) Execute migration SQL once inside transaction; 7) Run post-migration checks (`E6.1`–`E6.10`); 8) Publish `M13_PRODUCTION_EXECUTION_REPORT.md`. |
| **9** | **Post-Migration Checks** | Verify 3 tables, 15 columns on `order_customizations`, `m13_set_updated_at()`, 3 triggers, `relrowsecurity` & `relforcerowsecurity`, 4 RLS policies, `anon` read/deny checks, `NOTIFY pgrst, 'reload schema';`. |
| **10** | **Rollback Conditions** | Execute rollback only on verified post-migration defect/regression before live customer writes, and never automatically mid-failure. |
| **11** | **Rollback Procedure** | Manual operator review of production state, then execute `migrations/20261112_001_personalization_engine_rollback.sql` (`RESTRICT` only, `0 CASCADE`, preserves unrelated objects). If new external dependencies or customer writes exist, stop and recover rather than forcing rollback. |
| **12** | **Recovery Limitations** | Free plan has no managed backups/PITR; logical backup excludes Supabase internal schemas/platform config. |
| **13** | **Operator & Window** | Designated Migration Operator; UTC window scheduled upon explicit release. |
| **14** | **Duration & Impact** | < 5 seconds DDL execution; zero downtime. |
