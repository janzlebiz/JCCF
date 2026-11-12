# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: PDF Render Reproducibility & Layout Verification Report

**Document ID:** `JCCF-REP-RENDER-REPRO-001`  
**Date:** 12 November 2026  
**Status:** Verification Audit Complete — Reproducibility & Fallbacks Documented  
**Author:** Antigravity Architecture Review  
**Artifact Inspected:** `D:\Antigravity\JCCF\JCCF_PetStory_Verified_Sample_24p.pdf` (211,983 bytes)  

---

## 1. Executive Summary

Empirical inspection of the generated keepsake artifact proves that modern headless Chromium compiles CSS Paged Media specifications into a valid 24-page PDF with precise 210mm x 210mm square geometry. However, critical differences between developer workstation environments (Windows) and cloud worker environments (Linux Docker) exist and must be handled before production release.

---

## 2. Page Geometry & Extraction Audit

Programmatic inspection using Python `pypdf` on `JCCF_PetStory_Verified_Sample_24p.pdf` confirmed the following physical metrics across all 24 pages:

```
====================================================================================================
PAGE-BY-PAGE MEASUREMENT EVIDENCE
====================================================================================================
Page 01: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 163 | Barnaby (Cover)
Page 02: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 444 | CERTIFICATE OF COMPANIONSHIP
Page 03: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 239 | Dedication Spread
Page 04: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 463 | CHAPTER ONE - The Day You Found Us
Page 05: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 230 | ARCHIVE SPREAD ONE - The Early Days
Page 06: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 638 | PERSONALITY PROFILE
Page 07: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 447 | CHAPTER TWO - Daily Adventures
Page 08: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 221 | ARCHIVE SPREAD TWO - Caught in the Act
Page 09: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 466 | HABITS & QUIRKS
Page 10: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 224 | ARCHIVE SPREAD THREE - Peaceful Serenity
Page 11: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 383 | CHAPTER THREE - Milestones
Page 12: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 443 | THE INNER CIRCLE - Pack Members
Page 13: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 244 | ARCHIVE SPREAD FOUR - Together with Family
Page 14: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 534 | DAILY CHRONICLES - Routine & Rituals
Page 15: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 252 | ARCHIVE SPREAD FIVE - Exploration
Page 16: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 489 | LIFE LESSONS - Wisdom & Love
Page 17: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 238 | ARCHIVE SPREAD SIX - Unforgettable
Page 18: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 469 | WORDS OF DEVOTION - Family Letter
Page 19: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 275 | PHYSICAL KEEPSAKE - Archival Paw Stamp
Page 20: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 447 | REGISTRY OF LOVES - Favorites
Page 21: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 233 | REFLECTION - Unconditional Bond
Page 22: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 123 | CANDID GALLERY - Good Life Snapshots
Page 23: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 391 | ARCHIVAL RECORD - Colophon
Page 24: width=595.0pt (209.9mm), height=595.0pt (209.9mm), chars= 147 | BACK COVER - Keepsake Catalog Stamp
====================================================================================================
```

---

## 3. Image Rendering & Fallback Findings

* **Observation:** `pypdf` image stream extraction revealed that **0 raster images are embedded** in `JCCF_PetStory_Verified_Sample_24p.pdf`.
* **Root Cause & Behavior:** The test context passed empty strings for `photos.p1` through `photos.p6`.
* **Verified Behavior:** The Jinja2 template and CSS handled missing images gracefully:
  ```html
  {% if photos.p1 %}
      <img src="{{ photos.p1 }}" alt="The Early Days">
  {% else %}
      <div class="photo-fallback-quote">
          “You stepped into our home, and suddenly every room had warmth.”
      </div>
  {% endif %}
  ```
  Instead of broken `<img>` icons, collapsing containers, or missing pages, full-bleed illustrated quote spreads were rendered.
* **Unresolved Limitation:** True raster image rendering (e.g. handling a 12 megapixel JPEG, orientation rotation via EXIF, and aspect ratio crop fit) has not yet been compiled to PDF in this workspace.

---

## 4. Typography & Font Embedding Reality

Inspection of font dictionary objects in the sample PDF revealed 7 embedded Type0 font subsets:
- `/DAAAAA+SegoeUI` (Body Text, Headers)
- `/CAAAAA+SegoeUI-Italic` (Subtitles, Quotes)
- `/FAAAAA+SegoeUI-Semibold` (Metadata, Labels)
- `/EAAAAA+SegoeUI-Bold` (Page Numbers, Chapter Titles)
- `/AAAAAA+Georgia-Bold` (Headings, Cover Title)
- `/GAAAAA+Georgia-Italic` (Pull Quotes)
- `/BAAAAA+SegoeUI-Semibold` (Emblem details)

### The Workstation vs Container Reproducibility Gap
1. **Workstation Proof:** On Windows 11, Google Chrome read these system fonts directly from `C:\Windows\Fonts\` and embedded the subset glyphs cleanly into the PDF stream.
2. **Container Gap:** Linux worker containers do not possess proprietary Windows fonts (`Segoe UI`). In standard Docker environments (`python:3.11-slim`), Chromium falls back to open alternatives (`DejaVu Sans`, `Liberation Sans`, or `FreeSans`).
3. **Reproducibility Guarantee Action for Phase 1:** To guarantee 100% visual parity across all environments, Phase 1 must include local TTF font files directly in `templates/petstory_v1/fonts/` (such as `Cabin-Regular.ttf` and `PlayfairDisplay-Regular.ttf`) loaded via relative `@font-face` CSS rules.

---

## 5. Layout Overflow & Clipping Analysis

* **Container Clamping:** Each page uses explicit `.page { width: 210mm; height: 210mm; max-height: 210mm; overflow: hidden; break-after: page; }`.
* **Behavior Under Extreme Input:** When a 35-character name was tested, the title text clamped cleanly inside the cover border without forcing an unintended 25th page.
* **Risk Identified:** If a user submits an excessively long dedication message (>800 characters), `overflow: hidden` will clip the bottom text rather than dynamically paginating.
* **Phase 1 Invariant Requirement:** Frontend wizard must enforce hard character limits (`maxlength="450"`) on the dedication textarea to prevent visual clipping.

---

## 6. Conclusion

The PDF template geometry and fallback behavior are robust and verified locally. Reproducibility across Linux cloud workers requires bundling explicit open font binaries during Phase 1.

