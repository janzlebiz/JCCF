# Janzle Creative Commerce Factory (JCCF)
# M13 Artifact Consistency & Data Contract Report

**Document ID:** `JCCF-REP-CONSISTENCY-001`  
**Date:** 12 November 2026  
**Status:** Canonical Data Contract Specification  
**Governs:** `petstory_v1_schema.json`, `template.html`, `style.css`, and FastAPI Contracts  

---

## 1. Canonical Questionnaire-to-Template Data Contract

This document establishes the single source of truth linking questionnaire responses (`customization_sessions.answers`) and asset uploads (`customization_sessions.uploaded_assets`) to the Jinja2 template rendering context (`answers` and `photos`).

```
+----------------------------------------------------------------------------------------------------+
| CANONICAL DATA MAPPING PIPELINE                                                                    |
|                                                                                                    |
| [Questionnaire Step]       [Schema Field]          [Template Context Slot]    [Rendered Page]      |
| Step 1: Pet Type --------> pet_type -------------> answers.pet_type --------> Pages 7, 14, 20      |
| Step 2: Book Purpose ----> book_purpose ---------> answers.book_purpose ----> Dedication Tone      |
| Step 3: Life Stage ------> life_stage -----------> answers.life_stage ------> Pages 1, 4, 11, 21   |
| Step 4: Origin Story ----> origin_type ----------> answers.origin_type -----> Page 4 (Ch. 1)       |
| Step 5: Pet Identity ----> pet_name -------------> answers.pet_name --------> Pages 1-24 Header    |
|                            nicknames ------------> answers.nicknames -------> Page 2 (Certificate) |
|                            gotcha_date ----------> answers.gotcha_date -----> Page 2 (Certificate) |
|                            breed_description ----> answers.breed_description> Page 2 (Certificate) |
| Step 6: Traits ----------> personality_traits ---> answers.personality_traits Page 6 (Matrix)     |
| Step 7: Quirks ----------> quirks ---------------> answers.quirks ----------> Page 9 (Quirks)      |
| Step 9: Owner Names -----> owner_names ----------> answers.owner_names -----> Pages 1, 3, 12, 13, 20|
|                            home_city ------------> answers.home_city -------> Page 2 (Certificate) |
| Step 10: Dedication -----> dedication_text ------> answers.dedication_text -> Page 3 (Spread)      |
| Step 11: Photo Upload ---> uploaded_photos ------> photos.p1 - photos.p6 ---> Pages 5, 8, 10, 13,   |
|                                                                               15, 17, 22           |
| Step 12: Cover Builder --> palette_id -----------> answers.palette_id ------> CSS Body Class      |
|                            icon_id --------------> answers.icon_id ---------> Cover Emblem SVG    |
+----------------------------------------------------------------------------------------------------+
```

---

## 2. Field-by-Field Mapping & Conditional Logic Matrix

| Questionnaire Field | Data Type | Mandatory / Fallback | Template Usage & Conditional Effect |
|---|---|---|---|
| `pet_name` | `string(30)` | **Mandatory** (`'Our Companion'`) | Front cover title, colophon, and running page headers across all 24 pages. |
| `pet_type` | `enum('dog','cat')`| **Mandatory** (`'dog'`) | Dynamically adjusts nouns/verbs: dog ("tail wags", "walks", "zoomies", "muddy paws") vs cat ("purrs", "headbutts", "sunbeam naps", "soft paws") on Pages 7, 14, 20. |
| `life_stage` | `enum('young','adult','senior','memorial')` | **Mandatory** (`'adult'`) | Governs narrative arc. If `'memorial'`, shifts tone across Chapters 1, 3, and Page 21 into memorial tribute ("Forever Our Guiding Star"). If `'young'`, focuses on puppy/kitten early days. |
| `origin_type` | `enum('rescue','breeder','serendipity','family_gift')` | **Mandatory** (`'rescue'`) | Determines Chapter 1 (Page 4) story and heading: "The Day You Found Us (Rescue)" vs "Bringing You Home (Breeder)" vs "An Unexpected Blessing (Serendipity)" vs "The Greatest Gift". |
| `nicknames` | `string(60)` | Optional (`null`) | Displayed on Page 2 (Official Certificate of Companionship). Omitted gracefully if blank. |
| `gotcha_date` | `date` | **Mandatory** (`'A Day Blessed by Fate'`) | Displayed on Certificate (Page 2) and archival records. |
| `breed_description` | `string(40)` | Optional (`null`) | Included on Certificate (Page 2) if provided; omitted gracefully if empty. |
| `personality_traits` | `array[1..4]` | **Mandatory** (4 defaults) | Dynamically populates the 4-card Personality Matrix grid on Page 6. |
| `quirks` | `array[1..3]` | **Mandatory** (2 defaults) | Dynamically populates the Signature Quirks card grid on Page 9. |
| `owner_names` | `string(50)` | **Mandatory** (`'Your Family'`) | Displayed on Front Cover footer (Page 1), Dedication byline (Page 3), Inner Circle (Page 12), and Favorites (Page 20). |
| `home_city` | `string(40)` | Optional (`null`) | Appended to Certificate seal (Page 2). |
| `dedication_text` | `string(350)` | **Mandatory** (Default provided) | Rendered as central quote on Dedication Spread (Page 3). Character limits prevent vertical box overflow. |
| `palette_id` | `enum` | **Mandatory** (`'sage_meadow'`) | Injected as `.palette-{{ id }}` on `<body>`, setting CSS custom properties `--cover-bg`, `--cover-text`, and `--card-accent`. |
| `icon_id` | `enum` | **Mandatory** (`'paw_classic'`) | Renders corresponding SVG vector graphic on Cover (Page 1) and Back Cover (Page 24). |

---

## 3. Photo Upload Slot Contract (`photos.p1` – `photos.p6`)

The application backend maps items from `uploaded_photos` by `slot_id` into a flattened dictionary `photos: Dict[str, str]`:

```python
photos = {
    "p1": "file:///tmp/worker/session_123/p1.jpg", # The Early Days (Mandatory)
    "p2": "file:///tmp/worker/session_123/p2.jpg", # Caught in the Act (Mandatory)
    "p3": "file:///tmp/worker/session_123/p3.jpg", # Peaceful Serenity (Mandatory)
    "p4": "file:///tmp/worker/session_123/p4.jpg", # With Family (Mandatory)
    "p5": "file:///tmp/worker/session_123/p5.jpg", # Outdoor Escapades (Optional)
    "p6": "file:///tmp/worker/session_123/p6.jpg"  # Unforgettable Moments (Optional)
}
```

### Invariant: Fixed Page Count (Strictly 24 Pages)
If optional photo `p5` or `p6` is omitted by the customer, the template **does not collapse the page or leave blank space**. Jinja2 renders an elegant full-page typographic quote container:
```html
{% if photos.p5 %}
    <img src="{{ photos.p5 }}" alt="Outdoors">
{% else %}
    <div class="photo-fallback-quote">
        “Exploring the wide world with boundless wonder in your eyes.”
    </div>
{% endif %}
```
This guarantees that the document layout invariant ($N = 24$) is preserved regardless of upload count.

---

## 4. Palette Alignment & Contrast Audit

All palette identifiers are unified across `petstory_v1_schema.json`, `template.html`, and `style.css`.

### Contrast Ratio Verification (Calculated via WCAG 2.1 Formula)

$$\text{Contrast Ratio} = \frac{L_1 + 0.05}{L_2 + 0.05}$$

| Canonical Palette ID | Display Name | Background Hex | Text Hex | Accent Hex | Contrast Ratio | WCAG AAA ($\ge 7.0:1$) |
|---|---|---|---|---|---|---|
| `sage_meadow` | Sage Meadow (Deep Forest) | `#2D4F32` | `#FFFFFF` | `#A4C9A8` | **9.23:1** | **PASS** |
| `terracotta` | Warm Terracotta (Deep Rust) | `#84331C` | `#FFFFFF` | `#F4BAAA` | **8.50:1** | **PASS** |
| `midnight_navy` | Midnight Navy | `#1E2E3E` | `#FFFFFF` | `#9ABDD8` | **13.86:1** | **PASS** |
| `warm_sand` | Warm Sand | `#F5EFEB` | `#2D2320` | `#8C786E` | **13.42:1** | **PASS** |
| `dusty_rose` | Dusty Rose (Deep Berry) | `#732838` | `#FFFFFF` | `#E8A8B4` | **10.05:1** | **PASS** |

* `[VERIFIED]` Every selectable palette exceeds the 7.0:1 normal text contrast ratio required by WCAG AAA standards.
* `[VERIFIED]` Zero external network dependencies. Standard system TrueType serif (`Playfair Display`, `Georgia`) and sans-serif (`Cabin`, `Segoe UI`, `Arial`) fallbacks ensure 100% offline rendering.

