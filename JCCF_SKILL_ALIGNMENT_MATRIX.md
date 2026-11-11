# Janzle Creative Commerce Factory (JCCF)
# Antigravity Skill Alignment Matrix: CPL Gates G0–G10 & Subsystem M13

**Document ID:** `JCCF-GOV-SKILLS-001`  
**Date:** 12 November 2026  
**Status:** Official Engineering Governance Reference  
**Parent Framework:** JCCF Implementation Blueprint v1.0 & Antigravity Customizations  
**Authoritative Standards:** CPL Lifecycle (G0–G10), QEL (QG1–QG7, QG-R1–R4), and M13 Architecture  

---

## 1. Skill Taxonomy & Operational Classification

Installed skills in Antigravity are strictly classified by role for every engineering task:
* **Primary (Core) Skills:** Mandatory operational guides for a given lifecycle stage. The agent MUST read and apply the `SKILL.md` before executing work.
* **Supporting Skills:** Context-specific skills loaded only when the task touches that exact sub-domain (e.g., database, frontend UI, PDF layout).
* **Optional Skills:** Discretionary tools invoked only when explicitly required by complexity, refactoring needs, or operator request.
* **Capability Gaps:** Essential business or verification functions not currently covered by installed skills, requiring native deterministic JCCF code or external validation.

---

## 2. JCCF Commerce Product Lifecycle (CPL) Alignment Matrix

```
+----------------------------------------------------------------------------------------------------+
| JCCF CPL GATES G0–G10: SKILL EXECUTION MAP                                                         |
|                                                                                                    |
| [G0: Idea] --------> idea-refine | brainstorming                                                   |
| [G1: Research] ----> source-driven-development | research subagent                                 |
| [G2: Validated] ---> constraint-driven-development | doubt-driven-development                       |
| [G3: Specified] ---> spec-driven-development | api-and-interface-design                            |
| [G4: Generating] --> frontend-ui-engineering | pdf | xlsx | canvas-design                          |
| [G5: Generated] ---> incremental-implementation | lean-build                                        |
| [G6: QEL Check] ---> verification-before-completion | test-driven-development | security-and-hardening|
| [G7: Approved] ----> verify-and-stop | receiving-code-review                                       |
| [G8: Publishing] --> api-and-interface-design | source-driven-development                           |
| [G9: Published] ---> webapp-testing | browser-testing-with-devtools                                |
| [G10: Monitor] ----> observability-and-instrumentation | documentation-and-adrs                     |
+----------------------------------------------------------------------------------------------------+
```

### Detailed Gate-by-Gate Skill Mapping

| Gate | Phase Name | Primary Skill | Supporting Skills | Optional Skills | Capability Gaps & Manual Controls |
|---|---|---|---|---|---|
| **G0** | **Idea / Inception** | `idea-refine` | `brainstorming`, `spec-driven-development` | `domain-modeling` | *Market demand scraper:* No automated Etsy/Amazon keyword tool. Handled via permitted public APIs. |
| **G1** | **Research & Evidence** | `source-driven-development` | `investigate-first`, `research` subagent | `browser-use` | *Competitor pricing scraper:* No native dynamic pricing extractor. Manual evidence capture required. |
| **G2** | **Scoring & Validation** | `constraint-driven-development` | `doubt-driven-development` | `karpathy-guidelines` | *TSD-001 Scoring Engine:* Proprietary formula ($0.2D+0.15B...$). Must run in deterministic Python. |
| **G3** | **Product Spec (PSD)** | `spec-driven-development` | `api-and-interface-design`, `planning-and-task-breakdown` | `documentation-and-adrs` | *E-commerce packaging specs:* No packaging manifest standard. Governed by JCCF PSD template. |
| **G4** | **Asset Generation** | `pdf` (for documents), `xlsx` (for sheets) | `frontend-ui-engineering`, `canvas-design`, `theme-factory` | `algorithmic-art`, `slides` | *WeasyPrint CSS Paged Media linter:* No native CLI tool in skills. Validated by worker compile tests. |
| **G5** | **Packaging & Build** | `incremental-implementation` | `lean-build`, `safe-refactor` | `code-simplification` | *Archive security:* ZIP slip and path traversal inspection handled by deterministic Python validators. |
| **G6** | **Quality (QEL)** | `verification-before-completion` | `test-driven-development`, `security-and-hardening` | `code-review-and-quality` | *IP & Trademark Clearance:* No USPTO/TESS API skill installed. Operator manual escalation required. |
| **G7** | **Operator Approval** | `verify-and-stop` | `receiving-code-review`, `ponytail-review` | `caveman` | *Audit log immutability:* Verified via PostgreSQL write-once audit table triggers. |
| **G8** | **Publishing** | `api-and-interface-design` | `source-driven-development` | `git-workflow-and-versioning` | *Marketplace approval crawler:* Listing review state checks require custom platform webhooks. |
| **G9** | **Live Verification** | `webapp-testing` | `browser-testing-with-devtools`, `playwright-cli` | `browser-use` | *Secret canary scanner:* No automated credential leak monitor on live URLs. Handled by CI rules. |
| **G10**| **Monitor & Finance** | `observability-and-instrumentation` | `documentation-and-adrs`, `shipping-and-launch` | `performance-optimization`| *Double-Entry Reconciliation:* MoR payout reconciliation logic implemented in JCCF finance module M12. |

---

## 3. Subsystem M13 & Janzle PetStory Pilot Execution Matrix

Specific skill allocation for the Interactive Personalization Subsystem (M13) across development activities:

```
+----------------------------------------------------------------------------------------------------+
| M13 PERSONALIZATION ENGINE: WORKFLOW EXECUTION MATRIX                                              |
+----------------------------------------------------------------------------------------------------+
| Architecture & DB DDL     --> spec-driven-development + supabase-postgres-best-practices          |
| Security & Token Hashing   --> security-and-hardening + api-security-testing                        |
| Funnel Frontend Wizard     --> frontend-ui-engineering + ui-styling + design-taste-frontend        |
| WeasyPrint PDF Pipeline    --> pdf + source-driven-development + theme-factory                     |
| Concurrency & Worker Queue --> api-and-interface-design + observability-and-instrumentation        |
| Customer Journey E2E Test  --> webapp-testing + browser-testing-with-devtools                       |
| MoR Payment & Webhooks     --> api-and-interface-design + verification-before-completion           |
| Production Gate Audit      --> verification-before-completion + shipping-and-launch               |
+----------------------------------------------------------------------------------------------------+
```

### Detailed M13 Task Allocations

1. **Architecture & Database Schema:**
   * *Primary Skill:* `spec-driven-development`
   * *Supporting Skill:* `supabase-postgres-best-practices`
   * *Mandatory Rule:* Use `now()` for `TIMESTAMPTZ`, declare explicit SQL privileges (`GRANT SELECT`), and isolate public roles.
2. **Session Security & Token Cryptography:**
   * *Primary Skill:* `security-and-hardening`
   * *Supporting Skill:* `api-security-testing`
   * *Mandatory Rule:* SHA-256 token hashing at rest, application boundary isolation, and zero-token logging.
3. **Questionnaire Funnel (Next.js Wizard):**
   * *Primary Skill:* `frontend-ui-engineering`
   * *Supporting Skills:* `ui-styling`, `design-taste-frontend`
   * *Mandatory Rule:* Consume declarative `petstory_v1_schema.json`, auto-save step answers, and strip EXIF from client uploads.
4. **Document Rendering (WeasyPrint 24-Page Keepsake):**
   * *Primary Skill:* `pdf`
   * *Supporting Skill:* `source-driven-development`
   * *Mandatory Rule:* Apply CSS Paged Media `@page` standards, embed local TrueType fonts, and clamp dynamic name containers.
5. **Worker Concurrency & Job Claiming:**
   * *Primary Skill:* `api-and-interface-design`
   * *Supporting Skill:* `observability-and-instrumentation`
   * *Mandatory Rule:* Enforce atomic PostgreSQL `FOR UPDATE SKIP LOCKED` and state transitions to `processing`.
6. **Payment Ingestion & Webhook Safety:**
   * *Primary Skill:* `api-and-interface-design`
   * *Supporting Skill:* `verification-before-completion`
   * *Mandatory Rule:* Verify Lemon Squeezy HMAC SHA-256 signatures, enforce atomic idempotency on event ID, and separate pre-checkout profitability (QG-C0) from post-payment fulfillment (QG-C2).
7. **Customer Journey E2E Verification:**
   * *Primary Skill:* `webapp-testing`
   * *Supporting Skill:* `browser-testing-with-devtools`
   * *Mandatory Rule:* Execute full automated flow: `/start` $\rightarrow$ complete quiz $\rightarrow$ preview $\rightarrow$ test checkout $\rightarrow$ verify PDF download.

---

## 4. Capability Gaps & Remediation Actions

| Missing Capability | Impact on JCCF | Engineering Remediation / Workaround |
|---|---|---|
| **E-Commerce Niche Scraper** | G0/G1 signal intake requires manual input | Use official Google Trends, Reddit API, and manual evidence capture via permitted web search. |
| **Automated IP / Trademark Clearance** | Risk of infringing character marks | Strict QG6 human review gate; block all character names (e.g. Disney, Marvel, Pokémon). |
| **CSS Paged Media Headless Linter** | Layout errors only caught at render time | Automated worker test suite compiles template with dummy data and asserts page count == 24. |
| **Double-Entry Financial Reconciler** | Currency conversion variance risk | JCCF M12 Finance module records transaction date, exchange rate source, and gross/net amounts. |
| **Product Growth / CRO Optimizer** | Funnel drop-off analytics missing | Integrate PostHog or lightweight event logging in Next.js funnel steps. |

