# Janzle Creative Commerce Factory (JCCF)
# Project Instructions & Agent Operating Contract

**Workspace:** `d:\Antigravity\JCCF`  
**Primary Stack:** Python 3.11+ (FastAPI), TypeScript (Next.js), Supabase PostgreSQL, WeasyPrint / Headless Chromium  
**Authoritative Documents:**
* [JCCF Implementation Blueprint v1.0](file:///D:/Antigravity/JCCF/Janzle_Creative_Commerce_Factory_Blueprint_v1.0.docx)
* [Welcome Baby & PetStory Feasibility Assessment](file:///D:/Antigravity/JCCF/JCCF_WelcomeBaby_PetStory_Feasibility_Assessment.md)
* [M13 Architecture Remediation Report v2.1](file:///D:/Antigravity/JCCF/JCCF_M13_Architecture_Remediation_Report.md)
* [Antigravity Skill Alignment Matrix](file:///D:/Antigravity/JCCF/JCCF_SKILL_ALIGNMENT_MATRIX.md)
* [Antigravity Skill Selection Policy](file:///D:/Antigravity/JCCF/JCCF_SKILL_SELECTION_POLICY.md)
* [Antigravity Engineering Workflow Standard](file:///D:/Antigravity/JCCF/JCCF_ANTIGRAVITY_WORKFLOW.md)
* [CPL & QEL Cross-Reference Guide](file:///D:/Antigravity/JCCF/JCCF_CPL_QEL_CROSS_REFERENCE.md)
* [Governance Consistency Report](file:///D:/Antigravity/JCCF/JCCF_GOVERNANCE_CONSISTENCY_REPORT.md)
* [Phase 1 Authorization Status](file:///D:/Antigravity/JCCF/JCCF_PHASE_1_AUTHORIZATION_STATUS.md)

---

## 1. Operating Rules & Core Governance

1. **Default Voice:** Caveman Mode (Always On). Respond terse, answer first (`[thing] [action] [reason]. [next step].`), kill ceremony, active voice, payload verbatim.
2. **Primary Principle:** *Research before production. Quality before publishing. Evidence before scaling.*
3. **The Iron Law of Verification:** *No completion claims without fresh verification evidence.* Run the command, inspect output, confirm exit code 0, and cite real output before asserting success. Distinguish created test specifications from executed test runs.
4. **Canonical CPL Preservation:** The 11 lifecycle states from Blueprint v1.0 Section 4 (`IDEA` $\rightarrow$ `RESEARCHING` $\rightarrow$ `VALIDATED` $\rightarrow$ `SPECIFIED` $\rightarrow$ `GENERATING` $\rightarrow$ `GENERATED` $\rightarrow$ `QUALITY_CHECK` [FAILED / PASSED] $\rightarrow$ `APPROVED` $\rightarrow$ `PUBLISHING` $\rightarrow$ `PUBLISHED` $\rightarrow$ `MONITORING` $\rightarrow$ `OPTIMIZE / ARCHIVE`) are mapped to canonical gates G0 through G10. Never renumber, redefine, or replace canonical CPL gates. Skill workflows are operational mappings, not CPL replacements.
5. **Canonical QEL Preservation:** The 7 platform quality gates (`QG1`–`QG7`) remain the authoritative quality framework. Subsystem M13 gates (`QG-C0`, `QG-T1`–`T4`, `QG-R1`–`R4`, `QG-S1`–`S3`, `QG-C1`–`C3`) are documented strictly as domain extensions mapped into QG1–QG7.
6. **Phase Boundary Discipline:** Stop at phase boundaries. Never apply database migrations, deploy live code, configure production credentials, or spend capital without explicit, independent owner approvals. M13 Phase 1 remains unauthorized until formal owner sign-off.

---

## 2. Skill Selection & Invocation Protocol

* **Inspect First:** Consult [JCCF_SKILL_ALIGNMENT_MATRIX.md](file:///D:/Antigravity/JCCF/JCCF_SKILL_ALIGNMENT_MATRIX.md) for gate-specific skill mappings.
* **Mandatory Inspection:** Read the target `SKILL.md` using `read_file` before applying its tools or rules.
* **Strict Token Quota:** Maximum 1 Primary skill and 1 Supporting skill per atomic task turn. All other candidates are deferred, not loaded simultaneously.
* **Anti-Redundancy:** Never combine overlapping review skills (`code-review-and-quality` + `ponytail-review`).
* **Source Grounding:** Prefer official provider documentation and source code over speculative LLM assumptions (`source-driven-development`).

---

## 3. Subsystem M13 (Interactive Personalization Engine) Contracts

* **Schema Invariant:** Driven by declarative `petstory_v1_schema.json`.
* **Database Permissions:** Public roles (`anon`, `authenticated`) have `SELECT` on active rows of `personalization_templates` only, granted via explicit table-level `GRANT SELECT` and constrained by RLS. Direct table privileges are revoked (`REVOKE ALL`) on `customization_sessions` and `order_customizations` from `anon` and `authenticated`.
* **Service-Role Boundary:** `service_role` credentials exist exclusively in server-side FastAPI / background worker environments. Never expose service-role credentials to frontend client bundles or browser logs.
* **Token Security:** SHA-256 token hashing at rest (`token_hash`, `download_token_hash`). Zero token logging.
* **Rendering Pipeline:** Standard HTML5 + CSS Paged Media (210mm x 210mm square format). Zero external font or style HTTP calls. Compiles cleanly on both WeasyPrint (Linux container worker) and Headless Chromium (local Windows development workstation).
* **Payment State Machine:** Lemon Squeezy HMAC SHA-256 webhook verification + atomic idempotency locking on event ID. Pre-checkout profitability gate (`QG-C0`) prevents unprofitable checkouts; post-payment fulfillment gate (`QG-C2`) guarantees paid customers receive valid product.
