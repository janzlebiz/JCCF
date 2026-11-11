# Janzle Creative Commerce Factory (JCCF)
# Antigravity Skill Selection & Invocation Policy

**Document ID:** `JCCF-POL-SKILLS-001`  
**Version:** 2.0 (Remediated)  
**Date:** 12 November 2026  
**Status:** Mandatory Engineering Policy  
**Applies To:** Antigravity AI Coding Assistant & Subagents  
**Authority:** JCCF Blueprint v1.0 & Canonical Governance Standards  

---

## 1. Purpose & Core Principles

This policy establishes strict operating rules for selecting, inspecting, and executing skills within the Janzle Creative Commerce Factory (JCCF). Skills are specialized instruction bundles that enhance engineering rigor, but unconstrained skill loading causes token bloat, conflicting workflows, and degraded context quality.

### The 4 Cardinal Rules
1. **Targeted Selection:** Select only skills strictly relevant to the immediate, atomic task.
2. **Mandatory Inspection:** Read the actual `SKILL.md` instructions using `read_file` before applying a skill.
3. **Strict Quota Limit:** Exactly **one (1)** Primary skill and at most **one (1)** Supporting skill per atomic task turn. All other skills are deferred candidates, never loaded simultaneously.
4. **Source Grounding:** Prefer official external documentation and local source verification over speculative skill rules (`source-driven-development`).

---

## 2. Selection & Invocation Protocol

### Rule 1: Relevance Gate
Before invoking any skill, Antigravity must evaluate:
* *Does this skill directly govern the specific file, module, or test being modified in this turn?*
* If YES: Select the skill.
* If NO: Do NOT load the skill. Never load a skill "just in case" or because it might be needed later in the phase.

### Rule 2: Mandatory Inspection Protocol
Antigravity must never invoke tools or make architectural decisions based on assumed skill behavior. 
* Whenever a skill is selected, Antigravity must inspect the exact `SKILL.md` file using `read_file` before making edits or running tests.
* If delegating to a subagent, the prompt must explicitly specify which `SKILL.md` path the subagent must inspect.

### Rule 3: Anti-Redundancy & Conflict Prevention
Never stack overlapping or conflicting review skills within the same task turn.
* **Prohibited Combination:** Running `code-review-and-quality` + `ponytail-review` + `requesting-code-review` simultaneously. Choose exactly ONE review framework appropriate to the scope.
* **Prohibited Combination:** Running `test-driven-development` and `verify-and-stop` on initial drafting steps. TDD governs implementation; `verify-and-stop` governs final gate sign-off.

### Rule 4: Candidate Deferral Contract
Any skill identified as potentially relevant beyond the 1 Primary + 1 Supporting limit must be placed into a **Deferred Candidates** list in the execution audit. It must not be read or executed in the current turn.

---

## 3. Skill Invocation Budget & Quota Constraints

| Task Discipline | Primary Skill (Max 1) | Supporting Skill (Max 1) | Deferred Candidates (Not Loaded Simultaneously) |
|---|---|---|---|
| **Architecture / Spec** | `spec-driven-development` | `api-and-interface-design` | `planning-and-task-breakdown`, `documentation-and-adrs` |
| **Database Schema** | `spec-driven-development` | `supabase-postgres-best-practices` | `domain-modeling`, `security-and-hardening` |
| **Backend Implementation**| `incremental-implementation` | `test-driven-development` | `safe-refactor`, `code-simplification` |
| **Frontend UI Wizard** | `frontend-ui-engineering` | `ui-styling` | `design-taste-frontend`, `fixing-accessibility` |
| **Document Rendering** | `pdf` | `source-driven-development` | `theme-factory`, `canvas-design` |
| **Security Audit** | `security-and-hardening` | `api-security-testing` | `doubt-driven-development` |
| **Gate Verification** | `verification-before-completion`| `test-driven-development` | `verify-and-stop`, `code-review-and-quality` |

---

## 4. Execution Reporting Standard

Every response or artifact delivering engineering work must declare the skills utilized in the following standardized format:

```markdown
### Skill Execution Audit
* **Primary Skill:** [skill-name] (Inspected: C:\path\to\SKILL.md)
* **Supporting Skill:** [skill-name] (Inspected: C:\path\to\SKILL.md)
* **Objective:** [One sentence explaining why this pairing was selected]
* **Deferred Candidates:** [List of related skills intentionally deferred to preserve token budget]
```

---

## 5. Violation Triggers & Corrective Action

If an agent exhibits any of the following failure modes:
1. Loading more than 2 skills simultaneously $\rightarrow$ **STOP. Prune to the single primary and single supporting skill.**
2. Claiming compliance with a skill without reading its `SKILL.md` $\rightarrow$ **VIOLATION. Read instructions immediately.**
3. Asserting that a build or test passes without executing verification commands $\rightarrow$ **VIOLATION OF THE IRON LAW. Run verification command before making claim.**
4. Silently resolving ambiguous requirements rather than stopping and asking $\rightarrow$ **VIOLATION. Surface assumptions and present tradeoffs.**
