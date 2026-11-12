# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Evidence Register (Remediated v2.0)

**Document ID:** `JCCF-M13-STAGE-4-EVIDENCE-REG`  
**Version:** 2.0 (Post-Review Reconciliation)  
**Date:** 13 November 2026 (2026-11-13T01:55:00+08:00)  
**Status:** EVIDENCE REGISTER — PRE-IMPLEMENTATION GOVERNANCE  
**Repository:** `https://github.com/janzlebiz/JCCF`  
**Governing Migration Commit SHA:** `cfa4001b37ee8bdeb9030b025fb7e06bc9fab37e`  
**Verified CI Workflow SHA:** `8d02d9b9748ab2c3a47618abc59be509bd6f2420`  

---

## 1. Master Evidence Inventory (R8 Reconciled)

| Evidence ID | Description | Source File / URL | Exact Commit / Version | Evidence Type | What It Proves | What It Does NOT Prove | Status |
|---|---|---|---|---|---|---|---|
| **EV-M13-01** | Migration SQL Script | `migrations/20261112_001_personalization_engine.sql` | `cfa4001` (SHA-256: `D24F82E5...`) | Source Code | Defines declarative schema, fail-closed role preflight, RLS policies, trigger function, indexes, and column checks. | Does NOT prove execution on Supabase staging. | **VERIFIED** |
| **EV-M13-02** | Rollback SQL Script | `migrations/20261112_001_personalization_engine_rollback.sql` | `cfa4001` (SHA-256: `10721C96...`) | Source Code | Restrictive drops (`DROP TABLE ... RESTRICT`, 0 `CASCADE`), trigger OID checks, policy definition checks, and safe function cleanup. | Does NOT prove rollback execution on live staging. | **VERIFIED** |
| **EV-M13-03** | Staging Preflight Package | `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md` | `cfa4001` (SHA-256: `CE0A8C10...`) | Documentation | Preflight verification queries, PostgREST role checks, and operator safety rules. | Does NOT constitute staging execution authorization. | **VERIFIED** |
| **EV-M13-04** | Static Scenario Suite | `tests/test_migration_scenarios.py` | `cfa4001` | Automated Test Code (Local Python) | AST syntax parsing, SQL pattern matching across 12 migration/rollback scenarios. | Does NOT prove real PostgreSQL database behavior. | **VERIFIED** (12/12 PASS) |
| **EV-M13-05** | Real PostgreSQL Integration Suite | `tests/test_migration_postgres_integration.py` | `8d02d9b` | Automated Live Integration Suite (CI) | 20 scenarios executed in genuine disposable databases (`CREATE DATABASE jccf_<id>_<uuid>`). Verifies DDL, RLS, triggers, preflight rejects, rollback, role fail-closed, trigger/policy clash, and standalone/coupled FKs. | Does NOT prove Supabase staging execution. | **VERIFIED ON PG 15 CONTAINER** (20/20 PASS) |
| **EV-M13-06** | CI Verification Workflow | `.github/workflows/postgres_verification.yml` | `8d02d9b` | CI/CD Infrastructure | Automated pipeline executing PostgreSQL 15+ container service on GitHub Actions runner. | Does NOT connect to external Supabase projects. | **VERIFIED** |
| **EV-M13-07** | Live GitHub Actions CI Run | [Run 43273877704](https://github.com/janzlebiz/JCCF/actions/runs/43273877704) | `8d02d9b9748ab2c3a47618abc59be509bd6f2420` | Remote CI Telemetry | Proves all 20 real PostgreSQL integration tests, static tests, EOC audit, and sanitization tests pass in clean Linux container environment. | Does NOT prove staging database deployment. | **VERIFIED** (`success`) |
| **EV-M13-08** | Financial EOC Audit Model | `tests/audit_eoc_model.py` | `8d02d9b` | Automated Script Test | Verifies 16 mathematical assertions ($5,644.61 EOC, 86.91% margin) with accurate MoR and payout fee deductions. | Does NOT predict real-world refund or international transaction ratios. | **VERIFIED** (16/16 PASS) |
| **EV-M13-09** | Hostile Input Sanitization Audit | `tests/test_hostile_input_sanitization.py` | `8d02d9b` | Automated Script Test | Verifies 9 Jinja2 HTML escaping and SSTI rejection assertions against malicious payloads. | Does NOT prove frontend browser rendering safety. | **VERIFIED** (9/9 PASS) |
| **EV-M13-10** | PetStory 24p Sample PDF Artifact | `JCCF_PetStory_Verified_Sample_24p.pdf` | Repository Root | Binary Artifact | Proves headless Chromium rendering produces 24-page PDF keepsake adhering to 210mm square format. | Does NOT prove automated cloud background worker rendering. | **VERIFIED** |
| **EV-M13-11** | Staging Database Deployment | None | N/A | Target Deployment | Does NOT exist. Migration has NOT been applied to Supabase. | Does NOT exist. | **NOT EXECUTED** (Awaiting D4) |
| **EV-M13-12** | Phase 1 Application Code | None | N/A | Application Code | Does NOT exist. FastAPI / Next.js implementation has NOT started. | Does NOT exist. | **NOT EXECUTED** (Awaiting D5) |
