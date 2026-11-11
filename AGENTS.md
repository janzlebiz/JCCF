# Janzle Creative Commerce Factory (JCCF)
# Project Instructions & Agent Operating Contract

**Workspace:** `d:\Antigravity\JCCF`  
**Primary Language/Stack:** Python 3.11+ (FastAPI), TypeScript (Next.js), Supabase PostgreSQL, WeasyPrint  
**Authoritative Documents:**
* [JCCF Implementation Blueprint v1.0](file:///D:/Antigravity/JCCF/Janzle_Creative_Commerce_Factory_Blueprint_v1.0.docx)
* [Welcome Baby & PetStory Feasibility Assessment](file:///D:/Antigravity/JCCF/JCCF_WelcomeBaby_PetStory_Feasibility_Assessment.md)
* [M13 Architecture Remediation Report v2.0](file:///D:/Antigravity/JCCF/JCCF_M13_Architecture_Remediation_Report.md)
* [Antigravity Skill Alignment Matrix](file:///D:/Antigravity/JCCF/JCCF_SKILL_ALIGNMENT_MATRIX.md)
* [Antigravity Skill Selection Policy](file:///D:/Antigravity/JCCF/JCCF_SKILL_SELECTION_POLICY.md)
* [Antigravity Engineering Workflow Standard](file:///D:/Antigravity/JCCF/JCCF_ANTIGRAVITY_WORKFLOW.md)

---

## 1. Operating Rules & Core Principles

1. **Default Voice:** Caveman Mode (Always On). Respond terse, answer first (`[thing] [action] [reason]. [next step].`), kill ceremony, active voice, payload verbatim.
2. **Primary Principle:** *Research before production. Quality before publishing. Evidence before scaling.*
3. **The Iron Law of Verification:** *No completion claims without fresh verification evidence.* Run the command, inspect output, confirm exit code 0, and cite real output before asserting success.
4. **Preserve Architecture:** Do not modify JCCF v1.0 modules (M01–M12), CPL gates (G0–G10), or approved M13 designs without explicit justification.
5. **Phase Boundaries:** Stop at phase boundaries. Never apply database migrations, deploy live code, or configure production payment credentials without explicit written owner approval.

---

## 2. Skill Selection & Invocation Protocol

* **Inspect First:** Consult [JCCF_SKILL_ALIGNMENT_MATRIX.md](file:///D:/Antigravity/JCCF/JCCF_SKILL_ALIGNMENT_MATRIX.md) for gate-specific skill mappings.
* **Mandatory Reading:** Use `read_file` on the target `SKILL.md` before using its tools or guidelines.
* **Token Budget:** Maximum 1 Primary skill and 1 Supporting skill per atomic task turn. Zero redundant review skills.
* **Source Grounding:** Prefer official documentation over LLM assumptions (`source-driven-development`).

---

## 3. Subsystem M13 (Interactive Personalization Engine) Contracts

* **Schema:** Driven by declarative `petstory_v1_schema.json`.
* **Database:** `migrations/20261112_001_personalization_engine.sql`. Table access restricted to `service_role`. Public direct PostgREST access is revoked (`REVOKE ALL`).
* **Tokens:** SHA-256 token hashing at rest (`token_hash`, `download_token_hash`). Zero token logging.
* **Rendering:** WeasyPrint + Jinja2 inside bounded Python background worker. CSS Paged Media square format (210mm x 210mm).
* **Payment State Machine:** Lemon Squeezy HMAC SHA-256 verification + atomic idempotency locking on event ID. QG-C0 pre-checkout profitability check; QG-C2 post-payment fulfillment check (paid customers always receive product).

