# Janzle Creative Commerce Factory (JCCF)
# Antigravity Skill Selection & Invocation Policy

**Document ID:** `JCCF-POL-SKILLS-001`  
**Date:** 12 November 2026  
**Status:** Mandatory Engineering Policy  
**Applies To:** Antigravity AI Coding Assistant & Subagents  
**Authority:** JCCF Blueprint v1.0 & System Governance  

---

## 1. Purpose & Core Principles

This policy establishes strict operating rules for selecting, inspecting, and executing skills within the Janzle Creative Commerce Factory (JCCF). Skills are specialized instruction bundles that enhance engineering rigor, but unconstrained skill loading causes token bloat, conflicting workflows, and slow execution.

### The 4 Cardinal Rules
1. **Targeted Selection:** Select only skills strictly relevant to the immediate, atomic task.
2. **Mandatory Inspection:** Read the actual `SKILL.md` instructions before applying a skill.
3. **Bounded Overhead:** Load at most 1 Primary skill and 1 Supporting skill per atomic task.
4. **Source Grounding:** Prefer official external documentation and local source verification over speculative skill rules.

---

## 2. Skill Selection Rules

### Rule 1: Relevance Gate
Before invoking any skill, Antigravity must evaluate:
* *Does this skill directly govern the specific file, module, or test being modified in this turn?*
* If YES: Select the skill.
* If NO: Do NOT load the skill. Never load a skill "just in case" or because it might be needed later in the phase.

### Rule 2: Mandatory Inspection Protocol
Antigravity must never invoke tools or make architectural decisions based on assumed skill behavior. 
* Whenever a skill is selected, Antigravity must read the exact `SKILL.md` file using `read_file` before making edits or running tests.
* If delegating to a subagent, the prompt must explicitly specify which `SKILL.md` path the subagent must inspect.

### Rule 3: Anti-Redundancy & Conflict Prevention
Never stack overlapping or conflicting review skills within the same task turn.
* **Prohibited Combination:** Running `code-review-and-quality` + `ponytail-review` + `requesting-code-review` simultaneously. Choose exactly ONE review framework appropriate to the scope.
* **Prohibited Combination:** Running `test-driven-development` and `verify-and-stop` on initial drafting steps. TDD governs implementation; `verify-and-stop` governs final gate sign-off.

### Rule 4: Source-Driven Verification Over Speculation
* When integrating third-party APIs (Supabase, Lemon Squeezy, WeasyPrint, Resend), invoke `source-driven-development` to verify exact endpoint contracts and syntax against official documentation.
* Do not invent API fields or query parameters. If an endpoint behavior is unverified, classify it as `[UNVERIFIED]` and stop.

---

## 3. Skill Invocation Budget & Quota Constraints

| Task Type | Permitted Skill Allowance | Recommended Skill Pairing | Disallowed Overlap |
|---|---|---|---|
| **Architecture / Spec** | 1 Primary, 1 Supporting | `spec-driven-development` + `api-and-interface-design` | Review skills (`code-review-and-quality`) |
| **Database Schema** | 1 Primary, 1 Supporting | `spec-driven-development` + `supabase-postgres-best-practices` | UI skills (`frontend-ui-engineering`) |
| **Backend Implementation**| 1 Primary, 1 Supporting | `incremental-implementation` + `test-driven-development` | Creative skills (`canvas-design`) |
| **Frontend UI Wizard** | 1 Primary, 1 Supporting | `frontend-ui-engineering` + `ui-styling` | Database skills (`supabase-postgres-best-practices`) |
| **Document Rendering** | 1 Primary, 1 Supporting | `pdf` + `source-driven-development` | Automation skills (`automation`) |
| **Security Audit** | 1 Primary, 1 Supporting | `security-and-hardening` + `api-security-testing` | Performance skills (`performance-optimization`) |
| **Gate Verification** | 1 Primary | `verification-before-completion` | Implementation skills (`incremental-implementation`) |

---

## 4. Execution Reporting Standard

Every response or artifact delivering engineering work must explicitly declare the skills utilized in the following standardized format:

```markdown
### Skill Execution Audit
* **Primary Skill:** [skill-name] (Inspected: C:\path\to\SKILL.md)
* **Supporting Skill:** [skill-name] (Inspected: C:\path\to\SKILL.md)
* **Objective:** [One sentence explaining why this pairing was selected]
* **Unused / Deferred Skills:** [List of related skills intentionally bypassed to prevent bloat]
```

---

## 5. Violation Triggers & Corrective Action

If an agent exhibits any of the following failure modes:
1. Loading more than 2 skills for a routine bug fix or test run $\rightarrow$ **STOP. Prune to the single narrowest skill.**
2. Claiming compliance with a skill without reading its `SKILL.md` $\rightarrow$ **VIOLATION. Read instructions immediately.**
3. Asserting that a build or test passes without executing verification commands $\rightarrow$ **VIOLATION OF THE IRON LAW. Run verification command before making claim.**
4. Silently resolving ambiguous requirements rather than stopping and asking $\rightarrow$ **VIOLATION. Surface assumptions and present tradeoffs.**

