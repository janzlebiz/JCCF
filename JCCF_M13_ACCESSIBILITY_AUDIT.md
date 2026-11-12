# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Comprehensive Accessibility & Color Contrast Audit

**Document ID:** `JCCF-AUD-A11Y-001`  
**Date:** 12 November 2026  
**Status:** Verification Audit Complete — Contrast Discrepancies Cataloged  
**Author:** Antigravity Architecture Review  
**Standard Evaluated:** WCAG 2.1 Level AA (4.5:1 Normal, 3.0:1 Large) & Level AAA (7.0:1 Normal, 4.5:1 Large)  

---

## 1. Executive Summary

Previous documentation claimed that all text across all 5 color palettes satisfied WCAG AAA ($\ge 7.0:1$). A rigorous mathematical re-evaluation of every foreground-to-background color pairing across the entire template stylesheet (`templates/petstory_v1/style.css`) revealed that while **all primary cover headings and body text pass WCAG AAA**, certain **accent borders, muted running headers, and secondary captions fail WCAG AAA or Level AA**.

This report catalogs every measured ratio and provides an honest, evidence-grounded assessment.

---

## 2. Complete Contrast Measurement Table

Contrast ratios calculated using the official W3C relative luminance formula:
$$L = 0.2126 \times R_{lin} + 0.7152 \times G_{lin} + 0.0722 \times B_{lin}$$
$$CR = \frac{\max(L_1, L_2) + 0.05}{\min(L_1, L_2) + 0.05}$$

| Component / Location | Foreground (FG) | Background (BG) | Contrast Ratio | WCAG AA Status | WCAG AAA Status | Assessment & Remediation Note |
|---|---|---|---|---|---|---|
| **Cover: Sage Meadow Text** | `#FFFFFF` | `#2D4F32` | **9.23:1** | PASS | **PASS (AAA)** | Primary cover title & author text |
| **Cover: Sage Meadow Accent/Border** | `#A4C9A8` | `#2D4F32` | **5.05:1** | PASS | PASS (Large Only) | 1.5pt border and decorative emblems |
| **Cover: Terracotta Text** | `#FFFFFF` | `#84331C` | **8.50:1** | PASS | **PASS (AAA)** | Primary cover title & author text |
| **Cover: Terracotta Accent/Border** | `#F4BAAA` | `#84331C` | **5.04:1** | PASS | PASS (Large Only) | 1.5pt border and decorative emblems |
| **Cover: Midnight Navy Text** | `#FFFFFF` | `#1E2E3E` | **13.86:1**| PASS | **PASS (AAA)** | Primary cover title & author text |
| **Cover: Midnight Navy Accent/Border**| `#9ABDD8` | `#1E2E3E` | **7.02:1** | PASS | **PASS (AAA)** | Full AAA compliance across text & border |
| **Cover: Warm Sand Text** | `#2D2320` | `#F5EFEB` | **13.42:1**| PASS | **PASS (AAA)** | Deep espresso on warm pale sand |
| **Cover: Warm Sand Accent/Border** | `#8C786E` | `#F5EFEB` | **3.67:1** | FAIL (Normal)| FAIL (Normal) | Fails AAA normal text; acceptable for non-text UI borders |
| **Cover: Dusty Rose Text** | `#FFFFFF` | `#732838` | **10.05:1**| PASS | **PASS (AAA)** | Primary cover title & author text |
| **Cover: Dusty Rose Accent/Border** | `#E8A8B4` | `#732838` | **5.12:1** | PASS | PASS (Large Only) | 1.5pt border and decorative emblems |
| **Body: Chapter Headings** | `#2D2724` | `#FFFFFF` | **14.71:1**| PASS | **PASS (AAA)** | Primary book typography |
| **Body: Standard Body Text** | `#2D2724` | `#FFFFFF` | **14.71:1**| PASS | **PASS (AAA)** | Main chapter prose and paragraphs |
| **Body: Muted Text / Labels** | `#5C544E` | `#FFFFFF` | **7.41:1** | PASS | **PASS (AAA)** | Secondary labels and descriptions |
| **Body: Card Container Text** | `#2D2724` | `#FDFBF9` | **14.25:1**| PASS | **PASS (AAA)** | Text inside profile cards |
| **Body: Card Muted Text** | `#5C544E` | `#FDFBF9` | **7.18:1** | PASS | **PASS (AAA)** | Labels inside profile cards |
| **Body: Running Footer** | `#7A726D` | `#FFFFFF` | **4.71:1** | PASS | FAIL (AAA Normal)| Page numbers; passes AA, fails AAA normal |
| **Body: Running Header Title** | `#A89F98` | `#FFFFFF` | **2.60:1** | **FAIL** | **FAIL** | 6.5pt uppercase chapter tracking; fails AA |

---

## 3. Honest Accessibility Verdict

1. **What Fully Conforms to WCAG AAA:**
   - 100% of all main reading text, chapter headings, pull quotes, dedication letters, and colophons across all 5 palettes achieve contrast between **7.18:1 and 14.71:1**, easily exceeding the strict 7.0:1 AAA threshold.
   - 100% of cover titles and author credits across all 5 palettes achieve between **8.50:1 and 13.86:1**.

2. **What Does NOT Meet WCAG AAA:**
   - **Running Header (`.page-header`):** At `#A89F98` on `#FFFFFF` (2.60:1), this subtle running title was styled for low visual prominence in print. Under digital screen accessibility rules, it fails WCAG AA normal text.
   - **Warm Sand Border/Accent (`#8C786E` on `#F5EFEB`):** At 3.67:1, it passes WCAG 2.1 non-text UI contrast (which requires 3.0:1), but fails normal text AAA.
   - **Cover Accent Borders on Sage, Terracotta, and Dusty Rose:** At ~5.05:1, these exceed the 4.5:1 large-text AAA threshold and 3.0:1 non-text requirement, but do not reach 7.0:1.

---

## 4. Phase 1 Remediation Recommendations

To achieve uncompromising WCAG AAA conformance across digital preview and print without losing visual balance:
1. **Darken Running Header:** Change `.page-header` color from `#A89F98` to `#5C544E` (7.41:1, full AAA pass).
2. **Darken Running Footer:** Change `.page-footer` color from `#7A726D` to `#5A524D` (7.62:1, full AAA pass).
3. **Deepen Warm Sand Accent:** Adjust `--cover-accent` in Warm Sand from `#8C786E` to `#6E5A50` (5.25:1, large AAA pass).

All discrepancies are now accurately documented.

