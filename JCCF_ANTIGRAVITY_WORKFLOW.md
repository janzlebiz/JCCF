# Janzle Creative Commerce Factory (JCCF)
# Antigravity Engineering Workflow & Governance Standard

**Document ID:** `JCCF-STD-ENG-001`  
**Version:** 2.0 (Remediated)  
**Date:** 12 November 2026  
**Status:** Mandatory Engineering Standard  
**Applies To:** Antigravity Engineering Lifecycle & Subagent Coordination  
**Core Motto:** *Research before production. Quality before publishing. Evidence before scaling.*  

---

## 1. Governance Principles

The JCCF engineering workflow combines senior engineering discipline, Karpathy LLM coding guidelines, canonical CPL gates (G0–G10), and canonical QEL gates (QG1–QG7).

```
       [1. Think & Inspect Architecture]
                      |
                      v
       [2. Surface Assumptions & Check Tradeoffs]
                      |
                      v
       [3. Select Max 1 Primary + 1 Supporting Skill (Read SKILL.md)]
                      |
                      v
       [4. Test-Driven / Surgical Implementation]
                      |
                      v
       [5. Evidence-Based Verification (The Iron Law)]
                      |
                      v
       [6. Phase Boundary Stop & Owner Authorization]
```

### The 7 Pillars of JCCF Governance
1. **Think Before Coding:** Never begin editing files without inspecting existing documentation, architecture baselines, and database schemas first.
2. **Preserve Canonical CPL & QEL:** The 11 lifecycle states (G0–G10) and 7 platform quality gates (QG1–QG7) are immutable foundations. Never replace or renumber them. Subsystem M13 gates are documented as extensions mapped to QG1–QG7.
3. **Surgical, Minimal Edits:** Make the smallest change that completely solves the task. Never refactor adjacent code, reformat untouched files, or add speculative configurability.
4. **Test-Driven Rigor (TDD):** For new features or bug fixes, write the failing test first, run it to observe failure, write the implementation, and run tests to confirm green.
5. **Verification Status Accuracy:** Distinguish documentation, implementation, test creation, test execution, and test passage. Never label a test specification as an executed test.
6. **The Iron Law of Verification:** *No completion claims without fresh verification evidence.* Run the full command, inspect the return code, and quote actual terminal output before asserting success.
7. **Phase Boundary Discipline:** Stop at phase milestones. Never apply database migrations, spend capital, or deploy live code without explicit, independent owner approvals.

---

## 2. Standard 6-Step Task Execution Loop

### Step 1: Task Intake & Architectural Inspection
* Read task requirements carefully.
* Inspect project files, blueprints, and relevant source code before typing any replacement code.
* Identify which canonical JCCF CPL gate (G0–G10) or subsystem (M01–M13) is affected.

### Step 2: Surface Assumptions & Stop on Ambiguity
* If requirements or edge cases are unclear, **STOP**.
* State assumptions explicitly:
  ```markdown
  ASSUMPTIONS:
  1. [Requirement assumption]
  2. [Architecture boundary]
  -> Correct me now or I will proceed with these.
  ```
* If a conflict exists between the prompt and the blueprint, present the tradeoff and ask for direction.

### Step 3: Targeted Skill Invocation (1 Primary + 1 Supporting)
* Consult `JCCF_SKILL_ALIGNMENT_MATRIX.md` to identify the single Primary skill and optional Supporting skill.
* Use `read_file` to inspect the exact `SKILL.md` before applying changes.
* Enforce skill selection policy: max 2 skills total. All other candidates must be deferred.

### Step 4: Surgical Implementation (TDD & Slicing)
* Create tests before code:
  * Backend API / Database: write `pytest` contract tests in `/tests`.
  * Frontend: write component render / interaction tests.
* Keep changes surgical: touch only target lines. Match existing codebase conventions and naming.

### Step 5: Evidence-Based Verification
* Execute fresh verification commands via `run_command`:
  * Python lint/test: `pytest -v tests/test_target.py`
  * PDF rendering: execute headless render command and inspect Mediabox with `pypdf`.
  * SQL syntax: validate DDL syntax and constraint definitions.
* Read actual output, confirm zero failures and exit code 0.
* Quote actual verification evidence in the final response.

### Step 6: Phase Boundary Gate & Review
* Evaluate QEL gates against canonical QG1–QG7 and M13 extensions.
* If a phase boundary is reached (e.g., Phase 1 ready for migration): **STOP**.
* Present deliverables, list decisions made, and state: **"Awaiting Owner Authorization to proceed to next phase."**

---

## 3. Anti-Patterns & Prohibited Actions

| Anti-Pattern | Why Prohibited | Enforced Corrective Rule |
|---|---|---|
| **Speculative Over-Engineering** | Adds unused complexity, maintenance debt, and failure modes | Implement only requested behavior. No unasked flexibility. |
| **Silent RLS / Security Bypass** | Exposes private user data or creates privilege escalation | Every table must have RLS. Never use tautological policies (`token = token`). |
| **Unverified Success Claims** | Hallucinated tests hide real defects | Quote actual terminal output showing passing test count and 0 errors. |
| **Stacking Redundant Skills** | Bloats context, wastes tokens, triggers conflicting rules | Max 1 Primary + 1 Supporting skill per turn. |
| **Unapproved Migration Execution** | Causes irreversible schema drift or data loss | Migrations run only after explicit owner approval. |
| **Failing Post-Payment Fulfillment** | Violates consumer contract and triggers chargebacks | Margin checks run pre-checkout (QG-C0). Paid orders must always be fulfilled (QG-C2). |

---

## 4. Phase Boundary Sign-Off Contract

Whenever a milestone or implementation phase finishes:
1. Generate an updated verification report.
2. Update the architecture remediation report if changes occurred.
3. List all files created, modified, or deleted.
4. List all unresolved decisions requiring owner input.
5. Explicitly state: **"Governance consistency remediation complete. Awaiting owner review. M13 Phase 1 remains unauthorized."**
