# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Comprehensive Verification & Evidence Gap Report

**Document ID:** `JCCF-REP-EVIDENCE-GAP-001`  
**Date:** 12 November 2026  
**Status:** Verification Audit Complete — Gaps Documented  
**Author:** Antigravity Architecture & Verification  
**Governing Standard:** Iron Law of Verification (`AGENTS.md`)  
**Operating State:** Pre-Implementation Specification Complete (Phase 1 Unauthorized)  

---

## 1. Executive Summary & Verification Taxonomy

In strict compliance with the **Iron Law of Verification**, every claim of readiness, compliance, and functionality across Subsystem M13 was audited against observable repository reality. Unsupported assertions, premature passes, and conflations between specification and execution were identified and remediated.

All findings are categorized using this rigorous verification taxonomy:
1. `[SPECIFICATION ONLY]`: Architectural contract, schema, or DDL authored and syntax-checked, but not executed against live infrastructure.
2. `[EMPIRICAL ARTIFACT INSPECTION]`: Physical file or rendered document compiled locally and inspected byte-by-byte (e.g., PDF page count, mediabox, extracted text).
3. `[SIMULATED SCRIPT VERIFICATION]`: Code verified using standalone local Python scripts without external service dependencies.
4. `[NOT RUN / UNVERIFIED]`: Runtime integration, live webhook handshakes, external SMTP dispatch, or database execution that requires live infrastructure and remains strictly unauthorized.

---

## 2. Comprehensive Subsystem Gate Audit (15 Gates)

| Gate ID | Gate Name | Previous Classification | Corrected Classification | Verification Evidence & Method | Identified Limitation / Evidence Gap | Corrected Status |
|---|---|---|---|---|---|---|
| **QG-C0** | **Pre-Checkout Margin Gate** | Simulated | `[SIMULATED SCRIPT VERIFICATION]` | Audited unit economics calculation: \$12.99 gross less \$1.15 baseline costs yields \$11.84 contribution. | Assumes zero customer acquisition cost (organic traffic) and standard gateway fees. | **PASS (Simulated)** |
| **QG-C1** | **Payment Receipt Invariant** | Runtime | `[SPECIFICATION ONLY]` | Inspected `src/modules/m13_personalization/contracts.py` lines 45–70 for webhook `status == 'paid'` condition. | No live Lemon Squeezy webhook handshake executed. Database table not migrated. | **PASS (Contract Specification)** |
| **QG-C2** | **Post-Payment Fulfillment Gate** | Realigned | `[SPECIFICATION ONLY]` | Decoupled from QG-C0 in report and matrix; asserts paid customer is never denied generation. | No end-to-end payment-to-fulfillment worker pipeline executed. | **PASS (Contract Specification)** |
| **QG-C3** | **Transactional Email Dispatch** | NOT RUN | `[NOT RUN / UNVERIFIED]` | Live SMTP/Resend API requires production credentials and network calls, which are strictly restricted. | Email delivery to customer inbox has not occurred. | **NOT RUN** |
| **QG-T1** | **CSS Paged Media Syntax** | Runtime | `[EMPIRICAL ARTIFACT INSPECTION]` | Headless Chromium printed `template.html` + `style.css` without syntax errors, generating 24 square pages. | WeasyPrint v70.0 fails on local Windows workstation due to missing GTK3 C-libraries (`libgobject-2.0-0.dll`). | **PASS (Chromium Only)** |
| **QG-T2** | **Asset Isolation & Offline** | Static Audit | `[EMPIRICAL ARTIFACT INSPECTION]` | Scanned CSS and HTML: 0 remote `http://`/`https://` URLs. System fonts utilized. | No standalone `.ttf`/`.otf` font files are bundled in repository; rendering relies on local OS system fonts (`Segoe UI`, `Georgia`). | **PASS (System Font Fallback Only)** |
| **QG-T3** | **Layout Stress Clamping** | Static Audit | `[EMPIRICAL ARTIFACT INSPECTION]` | Tested 35-character name ("Sir Reginald Bartholomew...") on Cover and chapters; clamped cleanly to 24 pages. | Dynamic pagination for long custom dedications (>500 characters) relies on container scroll clipping rather than auto-reflow. | **PASS (Clamped Container)** |
| **QG-T4** | **Color Contrast (WCAG)** | Pass (AAA) | `[SIMULATED SCRIPT VERIFICATION]` | Primary text on all 5 cover palettes exceeds 7.0:1 (measured 8.50:1 to 13.86:1). | **Secondary text/accent elements failed WCAG AAA**: Running headers (#A89F98 on #FFFFFF) measured 2.60:1; Warm Sand accent (#8C786E on #F5EFEB) measured 3.67:1. | **PARTIAL PASS (AAA Body/Cover, Sub-AAA Accents)** |
| **QG-R1** | **Photo Slot Mapping** | Runtime | `[EMPIRICAL ARTIFACT INSPECTION]` | Jinja2 template conditionally renders `photos.p1`–`p6`. When omitted, illustrated quotes render. | `JCCF_PetStory_Verified_Sample_24p.pdf` was rendered with **0 images attached** (all fallback spreads); raster photo placement remains empirically untested. | **PASS (Fallback Quotes Only)** |
| **QG-R2** | **Page Count Invariant** | Runtime | `[EMPIRICAL ARTIFACT INSPECTION]` | `pypdf.PdfReader` verified exactly 24 pages (`len(pages) == 24`) on `JCCF_PetStory_Verified_Sample_24p.pdf`. | Invariant holds when content is clamped; unchecked user inputs of extreme length could overflow if container heights fail. | **PASS (Empirical 24p)** |
| **QG-R3** | **Text Sanitization** | Static Audit | `[SIMULATED SCRIPT VERIFICATION]` | Jinja2 autoescaping `| e` escapes `<script>alert(1)</script>` to `&lt;script&gt;`. | Test suite in `tests/test_m13_specifications.py` was not executed via pytest runner in local environment. | **PASS (Specification & Jinja Invariant)** |
| **QG-R4** | **PDF Structural Integrity** | Runtime | `[EMPIRICAL ARTIFACT INSPECTION]` | Mediabox verified at 595.0 pt x 595.0 pt (209.9 mm x 209.9 mm). PDF 1.7 syntax valid. | File generated via Chromium PDF writer rather than WeasyPrint / cairo backend. | **PASS (Chromium PDF 1.7)** |
| **QG-S1** | **EXIF Data Scrubbing** | Runtime | `[SPECIFICATION ONLY]` | Pillow strip-on-save pipeline specified in `contracts.py`. | No live file uploads have been processed or scrubbed in a running worker. | **PASS (Code Specification)** |
| **QG-S2** | **Token Hashing at Rest** | Runtime | `[SIMULATED SCRIPT VERIFICATION]` | Python `hashlib.sha256` verified to produce deterministic 64-character hex digests from 256-bit entropy tokens. | Tokens not yet stored in live PostgreSQL database. | **PASS (Algorithm Verified)** |
| **QG-S3** | **Rate Limiting Invariant** | Runtime | `[SPECIFICATION ONLY]` | Token bucket rate limit rules defined in route declarations (10 creates/hr/IP). | No Redis or in-memory token bucket backend is currently running or tested under load. | **PASS (Specification Only)** |

---

## 3. Questionnaire-to-Template Field Mapping Gaps

A thorough audit of `petstory_v1_schema.json` against `templates/petstory_v1/template.html` revealed:

1. **Fully Mapped & Functioning Fields:**
   - `pet_type`: Drives dog/cat terminology throughout the 24 pages.
   - `life_stage`: Dynamically switches Chapter 1 and memorial chapters (`young`, `adult`, `senior`, `memorial`).
   - `origin_type`: Conditionally branches origin story (`rescue`, `breeder`, `serendipity`).
   - `pet_identity` (`pet_name`, `nicknames`, `gotcha_date`, `breed_description`): Correctly injected across certificate, cover, and colophon.
   - `personality_traits` & `quirks`: Rendered as bullet lists and badges on Pages 6 and 9.
   - `owner_identity` (`owner_names`, `home_city`): Mapped to Certificate (Page 2) and Inner Circle (Page 12).
   - `dedication_message` (`dedication_text`): Rendered on Dedication spread (Page 3).
   - `cover_builder` (`palette_id`, `icon_id`): Correctly binds CSS class `palette-{palette_id}` and SVG emblem.

2. **Unmapped / Ignored Fields (Evidence Gap):**
   - `book_purpose` (Step 2: Keepsake, Birthday, Memorial, Gift): **Not referenced anywhere in Jinja2 template**. The template branches solely on `life_stage` (`answers.life_stage == 'memorial'`), ignoring `answers.book_purpose`.
   - **Remediation Requirement:** In Phase 1 template refinement, bind `book_purpose` to subtitle nuances or dedication framing, or formally deprecate Step 2 from `petstory_v1_schema.json`.

3. **Untested Questionnaire Branches:**
   - Only `dog` + `adult` + `serendipity` and `cat` + `memorial` + `rescue` branches were rendered to PDF.
   - The `breeder` origin branch, multi-trait selection (>3 traits), and custom icon options (`adventure_compass`, `crest_star`) remain uncompiled to physical PDF.

---

## 4. Typography & Font Asset Reality

* `[CRITICAL EVIDENCE GAP]` **Font Embedding vs System Font Fallback:**
  - Previous reports claimed fonts were embedded in the PDF.
  - Inspection of `JCCF_PetStory_Verified_Sample_24p.pdf` via `pypdf` reveals embedded font subsets: `/DAAAAA+SegoeUI`, `/AAAAAA+Georgia-Bold`, and `/CAAAAA+SegoeUI-Italic`.
  - **These fonts were embedded by Chromium from the host Windows OS font cache (`C:\Windows\Fonts`), NOT from bundled local project assets.**
  - There are currently **zero font files** (`.ttf`, `.otf`, `.woff2`) inside `templates/petstory_v1/`.
  - **Container Consequence:** When deployed to a minimal Linux Docker container (Debian/Alpine) lacking Microsoft TrueType fonts, the PDF engine will fall back to basic sans-serif (`DejaVu Sans` or `Liberation Sans`), altering letter spacing and line heights.
  - **Required Phase 1 Remediation:** Bundle open-source font binaries (e.g., `Cabin-Regular.ttf`, `PlayfairDisplay-Bold.ttf`) directly in `templates/petstory_v1/fonts/` with `@font-face` declarations.

---

## 5. Commercial Cost Model & Payout Settlement Realities

* **Estimated Operating Contribution (EOC):**
  - Gross sales: \$6,495.00 USD (500 units @ \$12.99).
  - Net baseline EOC: **\$5,727.85 USD / month (88.2% margin)**.
* **Preserved External Realities (Unverified):**
  - **Philippine Taxation:** Domestic Bureau of Internal Revenue (BIR) taxes (12% VAT or 1%–3% percentage tax + income tax) are not deducted by Lemon Squeezy and must be settled by the operator.
  - **Banking FX Spreads:** Local bank clearing (USD to PHP via BDO, BPI, or UnionBank) incurs a 1.5% to 2.5% foreign exchange spread.
  - These external factors are correctly excluded from software gate logic and documented as operator obligations.

---

## 6. Audit Verdict

All evidence gaps and specification boundaries are transparently documented. Phase 1 remains strictly unauthorized.

