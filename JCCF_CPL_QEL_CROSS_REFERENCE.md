# Janzle Creative Commerce Factory (JCCF)
# Canonical CPL Lifecycle & QEL Quality Gate Cross-Reference Guide

**Document ID:** `JCCF-REF-CPL-QEL-001`  
**Date:** 12 November 2026  
**Status:** Official Architectural Cross-Reference  
**Authoritative Baseline:** JCCF Implementation Blueprint v1.0 (Sections 4, 6, 9)  
**Governs:** Canonical CPL Gates (G0–G10), Canonical QEL (QG1–QG7), and Subsystem M13 Extensions  

---

## 1. Executive Summary

This reference guide establishes the formal relationship between the immutable platform-level frameworks defined in JCCF Blueprint v1.0 and the subsystem-specific extensions introduced for Module M13 (Interactive Personalization Engine):

1. **Commerce Product Lifecycle (CPL):** The 11 product lifecycle states from Blueprint Section 4 are codified as canonical gates **G0 through G10**. Operational skill mappings assist Antigravity at each gate but do not replace or renumber the canonical lifecycle.
2. **Quality Enforcement Layer (QEL):** The 7 platform quality gates (**QG1 through QG7**) from Blueprint Section 9 remain the authoritative quality standard for all products. Subsystem M13 gates (`QG-C`, `QG-T`, `QG-R`, `QG-S`) are specialized domain rules that execute strictly as sub-rules under canonical QG1–QG7.

---

## 2. Canonical CPL Lifecycle Gates (G0–G10)

The product lifecycle state machine from Blueprint Section 4 is mapped to canonical gates G0–G10:

```
[G0: IDEA] -> [G1: RESEARCHING] -> [G2: VALIDATED] -> [G3: SPECIFIED] 
    -> [G4: GENERATING] -> [G5: GENERATED] -> [G6: QUALITY_CHECK]
                                                |-- FAILED -> [REVISION_REQUIRED] -> G4
                                                +-- PASSED -> [G7: APPROVED] 
    -> [G8: PUBLISHING] -> [G9: PUBLISHED] -> [G10: MONITORING] -> [OPTIMIZE / ARCHIVE]
```

### Canonical CPL Definition Matrix

| Canonical Gate | Blueprint State | Purpose & Scope | Mandatory Exit Criteria | Operational Skill Pairing |
|---|---|---|---|---|
| **G0** | **IDEA** | Inception of raw product concept or micro-niche signal | Problem statement defined; initial premise captured | Primary: `idea-refine`<br>Supporting: `brainstorming` |
| **G1** | **RESEARCHING** | Gathering traceable market evidence and buyer intent | Source URLs, quotes, and timestamps recorded | Primary: `source-driven-development`<br>Supporting: `investigate-first` |
| **G2** | **VALIDATED** | Opportunity scoring using Janzle TSD-001 formula | TSD-001 score $\ge 80$ (Prioritize) or $\ge 65$ (Investigate) | Primary: `constraint-driven-development`<br>Supporting: `doubt-driven-development` |
| **G3** | **SPECIFIED** | Drafting and approving Product Specification Document | Versioned PSD approved; pricing and formats locked | Primary: `spec-driven-development`<br>Supporting: `api-and-interface-design` |
| **G4** | **GENERATING** | AI synthesis and specialized generator execution | Raw content, raster/vector art, and layouts compiled | Primary: `pdf` (or `xlsx`)<br>Supporting: `frontend-ui-engineering` |
| **G5** | **GENERATED** | Packaging deliverables and assembling file bundles | Final file manifest complete; checksums recorded | Primary: `incremental-implementation`<br>Supporting: `lean-build` |
| **G6** | **QUALITY_CHECK** | Executing Quality Enforcement Layer (QEL) gates | 100% of mandatory platform QEL gates (QG1–QG7) pass | Primary: `verification-before-completion`<br>Supporting: `test-driven-development` |
| **G7** | **APPROVED** | Operator review, compliance waiver, and release lock | Explicit operator approval; immutable version locked | Primary: `verify-and-stop`<br>Supporting: `receiving-code-review` |
| **G8** | **PUBLISHING** | Idempotent API transmission to authorized channel | Signature verified; publish request acknowledged | Primary: `api-and-interface-design`<br>Supporting: `source-driven-development` |
| **G9** | **PUBLISHED** | Channel query and live listing status verification | Live external listing ID, URL, price, variants confirmed | Primary: `webapp-testing`<br>Supporting: `browser-testing-with-devtools` |
| **G10**| **MONITORING** | Order synchronization, finance ledger, margin audit | Orders reconciled; fees, refunds, and contribution logged | Primary: `observability-and-instrumentation`<br>Supporting: `documentation-and-adrs` |

---

## 3. Canonical QEL Platform Gates (QG1–QG7) & M13 Cross-Reference

Blueprint Section 9 defines 7 platform quality gates required before any product is eligible for publication or delivery. Subsystem M13 maps its specialized rules directly into this platform framework:

```
+----------------------------------------------------------------------------------------------------+
| CANONICAL QEL (QG1–QG7) TO SUBSYSTEM M13 EXTENSION MAPPING                                         |
|                                                                                                    |
| Canonical QG1: File Integrity      <--- M13 QG-R4 (PDF structural valid) & QG-R1 (Asset integrity) |
| Canonical QG2: Completeness        <--- M13 QG-R2 (Page count = 24) & QG-R1 (Photo slot mapping)    |
| Canonical QG3: Technical           <--- M13 QG-T1 (CSS Paged Media) & QG-T2 (Offline local fonts)   |
| Canonical QG4: Visual              <--- M13 QG-T3 (Name length clamp) & QG-T4 (WCAG AAA Contrast)   |
| Canonical QG5: Accuracy            <--- M13 QG-R3 (Sanitization & accurate customer detail mapping)|
| Canonical QG6: Rights & Policy     <--- M13 QG-S1 (EXIF scrub), QG-S2 (Tokens), QG-S3 (Rate limits) |
| Canonical QG7: Commerce Readiness  <--- M13 QG-C0 (Pre-checkout margin), QG-C1 (Paid), QG-C2 (Fulfill)|
+----------------------------------------------------------------------------------------------------+
```

### Detailed Cross-Reference Specification

| Canonical Gate ID | Canonical Gate Name (Blueprint Table 6) | Canonical Pass Requirement | M13 Subsystem Extension Gates | Subsystem Extension Invariant & Test |
|---|---|---|---|---|
| **QG1** | **File Integrity** | File exists, correct type, opens, matches manifest | `QG-R4` (PDF Integrity)<br>`QG-R1` (Asset Integrity) | Rendered PDF opens in PyMuPDF with zero repair syntax flags. All referenced user image files exist in local worker scratch path. |
| **QG2** | **Completeness** | Required content, pages, worksheets, and assets present | `QG-R2` (Page Invariant)<br>`QG-R1` (Slot Mapping) | Rendered page count strictly equals 24 (`len(pages) == 24`). Omitted optional photos gracefully render fallback quotes with zero missing pages. |
| **QG3** | **Technical** | Dimensions, resolution, formulas, links, fonts, rendering | `QG-T1` (Paged Media)<br>`QG-T2` (Local Fonts) | WeasyPrint / Chromium compiles CSS with zero syntax errors. Local system fonts embedded with zero remote HTTP calls (`http://`, `https://`). |
| **QG4** | **Visual** | Layout, clipping, readability, alignment, print areas | `QG-T3` (Layout Stress)<br>`QG-T4` (Color Contrast) | 35-character names clamped cleanly without container overflow. Text-to-background contrast on all 5 palettes exceeds WCAG AAA ($\ge 7.0:1$). |
| **QG5** | **Accuracy** | Calculations, claims, descriptions match the artifact | `QG-R3` (Text Sanitization & Injection) | Customer pet names, dates, traits, and dedication text mapped accurately into corresponding chapter slots. All HTML tags strictly escaped. |
| **QG6** | **Rights & Policy** | Asset provenance, license records, platform policies | `QG-S1` (EXIF Scrubbing)<br>`QG-S2` (Token Cryptography)<br>`QG-S3` (Rate Limiting) | Customer uploads stripped of EXIF GPS coordinates. Guest session and download tokens hashed using SHA-256 at rest. Rate limits protect worker CPU. |
| **QG7** | **Commerce Readiness**| Price, fees, margin, listing fields, channel eligibility | `QG-C0` (Pre-Checkout Margin)<br>`QG-C1` (Payment Proof)<br>`QG-C2` (Order Fulfillment)<br>`QG-C3` (Email Dispatch) | **Pre-Checkout:** List price less expected fees yields positive contribution margin. **Post-Payment:** Order status verified paid. Paid customers always receive product. |

---

## 4. Architectural Coherence Summary

* **Platform Baseline:** Canonical CPL (G0–G10) and Canonical QEL (QG1–QG7) govern all JCCF product types (static digital PDFs, spreadsheets, POD apparel, and personalized books).
* **Subsystem Modularity:** Subsystem M13 adds domain-specific depth to G4, G6, and G8 without creating parallel or competing gate structures.
* **Integrity Guarantee:** Any change to platform-level CPL or QEL requires a formal revision to JCCF Implementation Blueprint v1.0, not an ad-hoc modification during subsystem review.

