# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13 Stage 4: Evidence Register (Remediated v3.0)

**Document ID:** `JCCF-M13-STAGE-4-EVIDENCE-REG`  
**Version:** 3.0 (Post-Review Reconciliation)  
**Date:** 13 November 2026 (2026-11-13T02:06:00+08:00)  
**Status:** EVIDENCE REGISTER — PRE-IMPLEMENTATION GOVERNANCE  
**Repository:** `https://github.com/janzlebiz/JCCF`  
**Governing Migration Commit SHA:** `e624e95f74932441dfee90cad7a9cb4544f64d6d`  
**Verified CI Workflow SHA:** `e624e95f74932441dfee90cad7a9cb4544f64d6d`  

---

## 1. Master Evidence Inventory

| Evidence ID | Description | Source File / URL | Exact Commit / Version | Evidence Type | What It Proves | What It Does NOT Prove | Status |
|---|---|---|---|---|---|---|---|
| **EV-M13-01** | Migration SQL Script | `migrations/20261112_001_personalization_engine.sql` | `e624e95` (SHA-256: `9D6579BC...`) | Source Code | Defines declarative schema, fail-closed role preflight, RLS policies, trigger function, indexes, and 15 column checks. | Does NOT prove execution on Supabase staging. | **VERIFIED** |
| **EV-M13-02** | Rollback SQL Script | `migrations/20261112_001_personalization_engine_rollback.sql` | `e624e95` (SHA-256: `33911582...`) | Source Code | Restrictive drops (`DROP TABLE ... RESTRICT`, 0 `CASCADE`), trigger OID & function presence checks, policy role array checks. | Does NOT prove rollback execution on live staging. | **VERIFIED** |
| **EV-M13-03** | Staging Preflight Package | `migrations/JCCF_M13_STAGING_MIGRATION_PREFLIGHT_PACKAGE.md` | `e624e95` (SHA-256: `CE0A8C10...`) | Documentation | Preflight verification queries, PostgREST role checks, and operator safety rules. | Does NOT constitute staging execution authorization. | **VERIFIED** |
| **EV-M13-04** | Static Scenario Suite | `tests/test_migration_scenarios.py` | `e624e95` | Automated Test Code (Local Python) | AST syntax parsing, SQL pattern matching across 12 migration/rollback scenarios. | Does NOT prove real PostgreSQL database behavior. | **VERIFIED** (12/12 PASS) |
| **EV-M13-05** | Real PostgreSQL Integration Suite | `tests/test_migration_postgres_integration.py` | `e624e95` | Automated Live Integration Suite (CI) | 24 scenarios executed in genuine disposable databases (`CREATE DATABASE jccf_<id>_<uuid>`). Verifies DDL, RLS, triggers, preflight rejects, rollback, role fail-closed, trigger/policy clash, standalone/coupled FKs, policy role verification, trigger missing-function abort, direct session permissions, and 15-column rejection. | Does NOT prove Supabase staging execution. | **VERIFIED ON PG 15 CONTAINER** (24/24 PASS) |
| **EV-M13-06** | CI Verification Workflow | `.github/workflows/postgres_verification.yml` | `e624e95` | CI/CD Infrastructure | Automated pipeline executing PostgreSQL 15+ container service on GitHub Actions runner. | Does NOT connect to external Supabase projects. | **VERIFIED** |
| **EV-M13-07** | Live GitHub Actions CI Run | [Run 43276015572](https://github.com/janzlebiz/JCCF/actions/runs/43276015572) | `e624e95f74932441dfee90cad7a9cb4544f64d6d` | Remote CI Telemetry | Proves all 24 real PostgreSQL integration tests, static tests, EOC audit, and sanitization tests pass in clean Linux container environment. | Does NOT prove staging database deployment. | **VERIFIED** (`success`) |
| **EV-M13-08** | Financial EOC Audit Model | `tests/audit_eoc_model.py` | `e624e95` | Automated Script Test | Verifies 16 mathematical assertions ($5,644.61 EOC, 86.91% margin) with accurate MoR and payout fee deductions. | Does NOT predict real-world refund or international transaction ratios. | **VERIFIED** (16/16 PASS) |
| **EV-M13-09** | Hostile Input Sanitization Audit | `tests/test_hostile_input_sanitization.py` | `e624e95` | Automated Script Test | Verifies 9 Jinja2 HTML escaping and SSTI rejection assertions against malicious payloads. | Does NOT prove frontend browser rendering safety. | **VERIFIED** (9/9 PASS) |
| **EV-M13-10** | PetStory 24p Sample PDF Artifact | `JCCF_PetStory_Verified_Sample_24p.pdf` | Repository Root | Binary Artifact | Proves headless Chromium rendering produces 24-page PDF keepsake adhering to 210mm square format. | Does NOT prove automated cloud background worker rendering. | **VERIFIED** |
| **EV-M13-11** | Staging Database Deployment | None | N/A | Target Deployment | Does NOT exist. Migration has NOT been applied to Supabase. | Does NOT exist. | **NOT EXECUTED** (Awaiting D4) |
| **EV-M13-12** | Phase 1 Application Code | None | N/A | Application Code | Does NOT exist. FastAPI / Next.js implementation has NOT started. | Does NOT exist. | **NOT EXECUTED** (Awaiting D5) |
