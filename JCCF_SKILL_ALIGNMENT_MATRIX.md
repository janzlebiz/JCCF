# Janzle Creative Commerce Factory (JCCF)
# Antigravity Skill Alignment Matrix: Canonical CPL Gates G0–G10 & Subsystem M13

**Document ID:** `JCCF-GOV-SKILLS-001`  
**Version:** 2.0 (Remediated)  
**Date:** 12 November 2026  
**Status:** Official Engineering Governance Reference  
**Parent Framework:** JCCF Implementation Blueprint v1.0 & Antigravity Customizations  
**Authoritative Standards:** Canonical CPL Lifecycle (G0–G10), Canonical QEL (QG1–QG7), and Subsystem M13 Architecture  

---

## 1. Governance Principles & Skill Quota Contract

Skills are operational engineering workflows that assist Antigravity. They **do not replace, renumber, or redefine** the canonical JCCF Commerce Product Lifecycle (CPL) gates G0–G10.

### The Skill Invocation Quota Invariant
* **Primary Skill:** Exactly **one (1)** primary skill selected per atomic task turn. Antigravity must read the exact `SKILL.md` before applying changes.
* **Supporting Skill:** At most **one (1)** supporting skill loaded when the task touches a specific sub-discipline (e.g., database, frontend UI, PDF layout).
* **Deferred Candidates:** Other relevant skills are listed strictly as alternative candidates to consider for future turns. They are **never** loaded simultaneously in the same task turn.

---

## 2. Canonical Commerce Product Lifecycle (CPL) Alignment

The JCCF lifecycle states defined in Blueprint v1.0 Section 4 form the canonical CPL gates G0 through G10:

$$\text{IDEA (G0)} \rightarrow \text{RESEARCHING (G1)} \rightarrow \text{VALIDATED (G2)} \rightarrow \text{SPECIFIED (G3)} \rightarrow \text{GENERATING (G4)} \rightarrow \text{GENERATED (G5)}$$
$$\rightarrow \text{QUALITY\_CHECK (G6)} \rightarrow \text{APPROVED (G7)} \rightarrow \text{PUBLISHING (G8)} \rightarrow \text{PUBLISHED (G9)} \rightarrow \text{MONITORING (G10)}$$

```
+----------------------------------------------------------------------------------------------------+
| CANONICAL CPL GATES G0–G10: OPERATIONAL SKILL EXECUTION MAP                                        |
|                                                                                                    |
| [G0: IDEA] -----------> Primary: idea-refine          | Supporting: brainstorming                  |
| [G1: RESEARCHING] ----> Primary: source-driven-dev    | Supporting: investigate-first              |
| [G2: VALIDATED] ------> Primary: constraint-driven-dev| Supporting: doubt-driven-development       |
| [G3: SPECIFIED] ------> Primary: spec-driven-dev      | Supporting: api-and-interface-design       |
| [G4: GENERATING] -----> Primary: pdf (or xlsx)        | Supporting: frontend-ui-engineering        |
| [G5: GENERATED] ------> Primary: incremental-impl     | Supporting: lean-build                     |
| [G6: QUALITY_CHECK] --> Primary: verification-before  | Supporting: test-driven-development        |
| [G7: APPROVED] -------> Primary: verify-and-stop      | Supporting: receiving-code-review          |
| [G8: PUBLISHING] -----> Primary: api-and-interface    | Supporting: source-driven-development      |
| [G9: PUBLISHED] ------> Primary: webapp-testing       | Supporting: browser-testing-with-devtools  |
| [G10: MONITORING] ----> Primary: observability-instr  | Supporting: documentation-and-adrs         |
+----------------------------------------------------------------------------------------------------+
```

### Gate-by-Gate Skill Allocation Table

| Gate | Canonical State Name | Primary Skill (Max 1) | Supporting Skill (Max 1) | Deferred Candidates (Not Loaded Simultaneously) | Capability Gaps & Manual Controls |
|---|---|---|---|---|---|
| **G0** | **IDEA** | `idea-refine` | `brainstorming` | `domain-modeling`, `prototype` | *Niche signal crawler:* No automated Etsy/Amazon scraper. Relies on permitted public sources. |
| **G1** | **RESEARCHING** | `source-driven-development` | `investigate-first` | `research` subagent, `browser-use` | *Competitor price tracking:* No native dynamic price monitor. Manual evidence capture required. |
| **G2** | **VALIDATED** | `constraint-driven-development` | `doubt-driven-development` | `karpathy-guidelines` | *TSD-001 Scoring:* Proprietary formula ($0.2D+0.15B...$). Executed via deterministic Python logic. |
| **G3** | **SPECIFIED** | `spec-driven-development` | `api-and-interface-design` | `planning-and-task-breakdown`, `documentation-and-adrs` | *E-commerce packaging spec:* Governed by versioned JCCF PSD template. |
| **G4** | **GENERATING** | `pdf` (or `xlsx`) | `frontend-ui-engineering` | `canvas-design`, `theme-factory`, `algorithmic-art` | *WeasyPrint CSS Paged Media linter:* Verified via offline headless print engine compilation tests. |
| **G5** | **GENERATED** | `incremental-implementation` | `lean-build` | `safe-refactor`, `code-simplification` | *Archive security:* ZIP slip and path traversal inspection validated via deterministic Python. |
| **G6** | **QUALITY_CHECK** | `verification-before-completion` | `test-driven-development` | `code-review-and-quality`, `security-and-hardening` | *IP Clearance:* No USPTO/TESS API skill installed. Strict human review gate (`QG6`) blocks commercial marks. |
| **G7** | **APPROVED** | `verify-and-stop` | `receiving-code-review` | `ponytail-review`, `caveman` | *Audit log immutability:* Verified via PostgreSQL write-once audit table triggers. |
| **G8** | **PUBLISHING** | `api-and-interface-design` | `source-driven-development` | `git-workflow-and-versioning` | *Marketplace review status:* Listing review state checks require custom platform webhooks. |
| **G9** | **PUBLISHED** | `webapp-testing` | `browser-testing-with-devtools` | `playwright-cli`, `browser-use` | *Production canary:* Secret leakage scanning handled by pre-commit CI rules. |
| **G10**| **MONITORING** | `observability-and-instrumentation`| `documentation-and-adrs` | `shipping-and-launch`, `performance-optimization` | *Double-entry reconciliation:* MoR payout reconciliation logic implemented in JCCF finance module M12. |

---

## 3. Subsystem M13 & PetStory Pilot Task Allocation

For activities within Subsystem M13 (Interactive Personalization Engine), skills are allocated strictly under the 1 Primary + 1 Supporting rule:

| M13 Engineering Task | Primary Skill (Max 1) | Supporting Skill (Max 1) | Deferred Candidates | Mandatory Rule |
|---|---|---|---|---|
| **Architecture & Database DDL** | `spec-driven-development` | `supabase-postgres-best-practices` | `domain-modeling` | Use `now()`; explicit `GRANT SELECT` on templates; `REVOKE ALL` on sessions. |
| **Session Security & Hashing** | `security-and-hardening` | `api-security-testing` | `doubt-driven-development` | SHA-256 token hashing at rest; application boundary; zero token logging. |
| **Funnel Wizard Frontend** | `frontend-ui-engineering` | `ui-styling` | `design-taste-frontend` | Consume `petstory_v1_schema.json`; client-side EXIF stripping. |
| **WeasyPrint / Print PDF** | `pdf` | `source-driven-development` | `theme-factory` | CSS Paged Media `@page` standards; verified 24 pages; offline system fonts. |
| **Worker Concurrency & Queue** | `api-and-interface-design` | `observability-and-instrumentation` | `debugging-and-error-recovery` | PostgreSQL atomic `FOR UPDATE SKIP LOCKED` job claiming. |
| **Payment & Webhook Pipeline** | `api-and-interface-design` | `verification-before-completion` | `testing-and-release` | Lemon Squeezy HMAC SHA-256; atomic idempotency; pre-checkout QG-C0. |
| **E2E Customer Journey Testing**| `webapp-testing` | `browser-testing-with-devtools` | `playwright-cli` | Verify full flow: `/start` $\rightarrow$ quiz $\rightarrow$ preview $\rightarrow$ test purchase $\rightarrow$ download. |

---

## 4. Capability Gaps & Remediation Status

| Missing Capability | JCCF Operational Impact | Remediation & Fallback Policy |
|---|---|---|
| **E-Commerce Niche Scraper** | G0/G1 intake requires manual signal capture | Use permitted public search, Google Trends, Reddit API, and manual PSD authoring. |
| **Automated IP / Trademark Clearance** | Risk of trademark infringement | Strict manual review under canonical QG6; block all protected commercial characters. |
| **CSS Paged Media Headless Linter** | Layout defects caught only at render time | Automated worker test compiles template with mock data and asserts `len(pages) == 24`. |
| **Double-Entry Financial Reconciler** | Currency conversion variance risk | JCCF M12 Finance ledger records transaction date, exchange rate source, gross/net amounts. |
| **Product Growth / CRO Optimizer** | Funnel step drop-off analytics missing | Integrate lightweight privacy-friendly analytics or server-side step logging. |
