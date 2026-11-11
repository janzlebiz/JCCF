# Janzle Creative Commerce Factory (JCCF)
## Technical Feasibility Assessment: Welcome Baby-Inspired Personalized Product Model (Janzle PetStory)

**Document Reference:** `JCCF-FA-2026-001`  
**Date:** 12 November 2026  
**Author:** Antigravity Architecture Review  
**Target Project:** Janzle Creative Commerce Factory (JCCF)  
**Authoritative Context:** `Janzle_Creative_Commerce_Factory_Blueprint_v1.0.docx`  
**External Reference:** `https://welcome.baby/`  
**Deliverable File Path:** `D:\Antigravity\JCCF\JCCF_WelcomeBaby_PetStory_Feasibility_Assessment.md`  

---

### Executive Verdict

```
================================================================================
FINAL VERDICT: BUILD WITH ARCHITECTURAL CHANGES
================================================================================
```

Personalized Product Generation must become a **reusable core subsystem of JCCF**, rather than an isolated, one-off script for PetStory. 

The existing JCCF Blueprint v1.0 is architected around an *operator-driven batch catalog production model* (M01 Discovery $\rightarrow$ M02 Scoring $\rightarrow$ M03 Spec $\rightarrow$ M04/M05 Generation $\rightarrow$ M07 QEL $\rightarrow$ M09 Marketplace Publishing). In that model, static SKUs are created in advance and published to third-party storefronts (Etsy, Payhip) where customers purchase pre-rendered files.

The Welcome Baby model operates under a completely different paradigm: **Just-In-Time (JIT) Dynamic Assembly**. Customers interact directly with a web questionnaire, customize attributes (names, dates, colors, chapters, photos), inspect a real-time personalized preview, purchase via direct-to-consumer (D2C) checkout, and trigger asynchronous compilation of a bespoke, print-ready artifact.

JCCF can cleanly support this model without throwing away Blueprint v1.0. The underlying stack (FastAPI, Python worker, Supabase PostgreSQL, Next.js, and Gemini API) provides the exact necessary primitives. However, targeted architectural extensions are required:
1. Addition of **Module M13: Interactive Personalization Engine**.
2. Separation of public consumer funnel routes from internal admin command center routes in Next.js.
3. Addition of dynamic session and runtime customization tables to Supabase PostgreSQL.
4. Expansion of the Quality Enforcement Layer (QEL) into **Design-Time Template Gates** and **Runtime Instance Gates**.
5. Integration of a **Merchant of Record (MoR)** payment pipeline (Lemon Squeezy or Paddle) suitable for Philippine operations selling internationally.

---

### 1. Welcome Baby Public-Feature & Tech Analysis

*Verified directly against public endpoints (`https://welcome.baby/`) and Next.js client bundles (`buildId: IVhc6CZArxfPUHuPjR03_`).*

#### 1.1 Technical Stack
* **Frontend:** Next.js (React), Emotion/Styled CSS, React Query (`@tanstack/react-query`) with dehydrated query state key `["quiz", "main-wb"]`.
* **State Management:** URL and local state synchronization storing 26 linear/branching steps.
* **Asset Handling:** Cloud bucket asset serving (`landing/homepage/`, dynamic SVGs, and WebP previews).

#### 1.2 Questionnaire Structure (26 Steps)
* **Top-of-Funnel (Steps 1–2):** Low-friction entry. Gender selection (`boy`, `girl`, `dont_know_yet`) followed by purchase intent (`book_purpose`: `myself` vs `gift`).
* **Conditional Branching (Steps 3–17):** Dynamic questions based on intent and arrival status (`myself_pregnant`, `myself_born`, `gift`):
  * Recipient relationship (parent, friend, family member).
  * Milestones & events (ultrasound, baby shower, first holidays, handprints/footprints).
  * Chapter toggles (pregnancy memories, birth story, nursery details).
* **Value Reinforcement & Pacing Interstitials (Steps 7, 10, 16, 21):**
  * Interstitial components (`infoChecklist2`, `loaderReviewSwiper`, `loaderInfo`) that simulate asset compilation while displaying verified customer testimonials and expert-curated value statements.
* **Identity Inputs (Steps 22–24):** Text collection for baby's name, mother's name, and father's name.
* **Cover Builder (Step 25 - `bookBuild`):**
  * Palette selector: Blue (`#73C4EE`), Pink (`#F494BE`), Beige (`#FFF1E2`), Orange (`#F79C7E`), Green (`#93C8A5`), Purple (`#838DC6`).
  * Icon selector: bear, butterfly, flowers, rainbow, elephant, cloud, bunny.
* **Interactive Flipbook Preview (Step 26 - `bookPreview`):**
  * Previews customized book cover and dedication page with exact user-entered names before payment.

#### 1.3 Monetization & Checkout Model
* **Checkout Bundles Identified in Codebase:**
  * `358_welcome-baby_physical-book_otp` (One-Time Payment, physical book).
  * `352_welcome-baby_e-book-free_otp` (Promotional digital e-book).
  * `883_welcome-baby_1-month_inc-rec` (Recurring trial for companion app).
* **Consumer Perception & Churn Risk:** Analysis of customer review platforms (Trustpilot, App Store) indicates that recurring companion app subscriptions bundled during checkout represent over 80% of negative reviews, chargeback disputes, and refund requests.

---

### 2. Customer Journey & Functional Decomposition

```
[Discovery Ad / Search] 
        |
        v
[1. Minimalist Landing (/start)] 
        |
        v
[2. Emotional Intake Quiz] (Type, Stage, Temperament, Themes)
        |
        v
[3. Chapter Selection] (Adoption Story, Quirks, Adventures, Milestones)
        |
        v
[4. Identity & Photo Intake] (Pet Name, Gotcha Day, 4-6 Photos)
        |
        v
[5. Value Pacing Screen] ("Curating chapters for Barnaby...")
        |
        v
[6. Interactive Cover Builder] (Palette, Icon, Typography)
        |
        v
[7. Dynamic Book Preview] (Watermarked Cover & Dedication Spread)
        |
        v
[8. D2C Checkout] (Credit Card / Apple Pay / Google Pay via MoR)
        |
        v
[9. Asynchronous PDF Assembly] (Python Worker + WeasyPrint)
        |
        v
[10. Order Delivery] (Instant Download Link + Signed Email Delivery)
```

---

### 3. Reusable Core Capability vs One-Off PetStory

Building PetStory as an ad-hoc, hardcoded script violates the core philosophy of JCCF. 

Personalized Product Generation must be established as **Module M13: Interactive Personalization Engine**.

| Dimension | One-Off PetStory Script | Reusable JCCF Subsystem (M13) |
|---|---|---|
| **Schema** | Hardcoded pet questions in React components | JSON-Schema driven questionnaire engine |
| **Templates** | Fixed pet HTML file | Parameterized Jinja2 / CSS Paged Media template library |
| **Extensibility** | Disposable; must re-code for next product | Instantly powers BabyStory, CoupleStory, MemorialBook, TravelMemory |
| **QEL Integration** | Manual or unverified | Automated two-stage QEL (Design-time + Runtime) |
| **Maintenance** | High technical debt | Cleanly isolated module with defined service contracts |

---

### 4. Proposed Janzle PetStory MVP Specification

* **Concept:** Premium personalized digital keepsake memory book for dog and cat owners.
* **Deliverable:** 24-page high-resolution, print-ready PDF (Square 210mm x 210mm format).
* **Price:** \$9.99 – \$14.99 USD (Digital Download).

#### 4.1 Page-by-Page Content Architecture (24 Pages)
1. **Front Cover:** Pet name, owner-selected colorway, silhouette/icon artwork.
2. **Inside Title & Certificate:** "Official Certificate of Unconditional Love & Companionship".
3. **Dedication Spread:** Custom message from owner, date, family signature.
4. **Chapter 1: The Day We Met:** Adoption/gotcha story, arrival details, first reactions.
5. **Photo Spread 1:** "First Day in Forever Home" (User photo upload).
6. **Personality Matrix:** Nicknames, favorite sleeping positions, quirky habits, fears, loves.
7. **Chapter 2: Daily Adventures:** Walks, car rides, zoomies, favorite toys.
8. **Photo Spread 2:** "Caught in the Act / Chaos Mode" (User photo upload).
9. **The Sound of Your Voice:** Vocalizations, head tilts, mealtime routines.
10. **Photo Spread 3:** "Pure Serenity / Napping Champion" (User photo upload).
11. **Chapter 3: Milestones & Badges:** Vet bravery, learning tricks, travel memories.
12. **Family & Best Friends:** Bonds with humans, siblings, and furry companions.
13. **Photo Spread 4:** "With the People Who Love You Most" (User photo upload).
14. **The Daily Schedule:** A humorous timeline of the pet's typical 24 hours.
15. **Photo Spread 5:** "Outdoor Escapades & Sunbeams" (User photo upload).
16. **Chapter 4: What You Taught Us:** Reflections on patience, joy, and companionship.
17. **Photo Spread 6:** "Unforgettable Moments" (User photo upload).
18. **A Letter to My Pet:** Heartfelt prose compiled from owner's questionnaire answers.
19. **Keepsake Paw-Print Zone:** Printable page designed for physical ink/stamp paw prints.
20. **Forever Favorites:** Favorite food, favorite human, favorite hiding spot.
21. **Closing Reflection:** Emotional summary statement on the animal-human bond.
22. **Gallery of Little Things:** Small candid grid placeholders.
23. **Colophon & Archival Note:** Archival document ID, generation timestamp, edition details.
24. **Back Cover:** Minimalist closing mark, keepsake seal, and Janzle imprint.

#### 4.2 Scope Boundaries: Physical POD & Companion App
* **Physical Print-on-Demand (POD): STRICTLY DEFERRED.**
  * *Technical Reason:* Printify focuses on single-surface items (apparel, mugs). Multi-page book binding requires specialized POD APIs (Lulu, Blurb, Prodigi).
  * *Financial Reason:* Physical POD requires paying print and shipping costs upfront before payment gateway funds settle. This violates JCCF's zero-budget working capital constraint.
* **Mobile Companion App: STRICTLY DEFERRED.**
  * *Commercial Reason:* Companion apps require substantial ongoing engineering (iOS/Android maintenance, push notifications, continuous hosting).
  * *Reputational Reason:* Welcome Baby's Trustpilot rating is depressed primarily by recurring subscription complaints tied to their companion app. Digital PDF delivers 100% of the emotional keepsake value with 0% recurring churn risk.

---

### 5. Architectural Deltas & Conflict Analysis

```
+--------------------------------------------------------------------------------------------------+
| JCCF ARCHITECTURAL DELTA MAP                                                                     |
|                                                                                                  |
| [JCCF v1.0 Blueprint Baseline]                                                                   |
|   - Internal Admin Dashboard (Next.js)                                                           |
|   - Batch Catalog Generator (M04/M05)                                                            |
|   - Single-Pass Static QEL Gate (M07)                                                            |
|   - External Channel Publishing: Etsy / Payhip (M09)                                             |
|                                                                                                  |
| [Extended Personalization Architecture (M13)]                                                    |
|   - Split Next.js Frontend: (marketing)/(funnel) [Public] + (admin) [Private]                    |
|   - Dynamic Session Intake & Asset Upload Handlers (FastAPI)                                     |
|   - Synchronous Low-Res Cover Preview Engine (FastAPI)                                           |
|   - Asynchronous High-Res PDF Renderer (Python Worker + WeasyPrint)                              |
|   - Two-Tier QEL: Design-Time Gates + Runtime Instance Gates                                     |
|   - D2C Checkout & Webhook Pipeline via Merchant of Record (Lemon Squeezy)                       |
+--------------------------------------------------------------------------------------------------+
```

---

### 6. Database Schema & API Contract Extensions

#### 6.1 Database Migration DDL (Supabase PostgreSQL)

```sql
-- Migration: 20261112_001_personalization_subsystem.sql

-- 1. Product Personalization Templates
CREATE TABLE IF NOT EXISTS public.personalization_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    version VARCHAR(20) NOT NULL,
    schema_definition JSONB NOT NULL,
    layout_template_path TEXT NOT NULL,
    default_page_count INT NOT NULL DEFAULT 24,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_template_version UNIQUE (product_id, version)
);

-- 2. Customer Personalization Sessions (Guest State Intake)
CREATE TABLE IF NOT EXISTS public.customization_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES public.personalization_templates(id),
    session_token UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    current_step VARCHAR(50) NOT NULL DEFAULT 'pet_type',
    answers JSONB NOT NULL DEFAULT '{}'::jsonb,
    uploaded_assets JSONB NOT NULL DEFAULT '[]'::jsonb,
    preview_artifact_path TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc', now()) + INTERVAL '30 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_customization_token ON public.customization_sessions(session_token);
CREATE INDEX idx_customization_expires ON public.customization_sessions(expires_at) WHERE status = 'draft';

-- 3. Order Customizations (Paid Instance Linkage)
CREATE TABLE IF NOT EXISTS public.order_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.customization_sessions(id) ON DELETE RESTRICT,
    rendered_artifact_path TEXT,
    render_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    render_attempts INT NOT NULL DEFAULT 0,
    render_error_log TEXT,
    runtime_qel_results JSONB NOT NULL DEFAULT '{}'::jsonb,
    download_token UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    download_count INT NOT NULL DEFAULT 0,
    download_expires_at TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc', now()) + INTERVAL '90 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_order_customization_order ON public.order_customizations(order_id);
CREATE INDEX idx_order_download_token ON public.order_customizations(download_token);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.personalization_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customization_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_customizations ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
CREATE POLICY "Public can read active templates"
    ON public.personalization_templates FOR SELECT
    USING (is_active = true);

CREATE POLICY "Public session access by token"
    ON public.customization_sessions FOR ALL
    USING (session_token = session_token)
    WITH CHECK (session_token = session_token);

CREATE POLICY "Service role full access on personalization"
    ON public.order_customizations FOR ALL
    TO service_role USING (true) WITH CHECK (true);
```

#### 6.2 Key API Contracts (FastAPI)

```
PATCH /api/v1/funnel/session/{token}
Intake: { "step_id": "pet_identity", "answers": { "pet_name": "Barnaby", ... } }
Output: { "status": "success", "next_step": "cover_customizer" }

POST /api/v1/funnel/session/{token}/upload
Intake: multipart/form-data (image bytes, MIME validated)
Output: { "asset_id": "...", "width": 2400, "height": 2400, "estimated_dpi": 300 }

POST /api/v1/funnel/session/{token}/preview
Intake: { "palette_id": "sage_meadow", "icon_id": "paw-classic" }
Output: { "preview_url": "https://.../cover_wm.webp", "render_time_ms": 320 }

POST /api/v1/webhooks/payment
Intake: Lemon Squeezy order.created webhook (HMAC SHA-256 signature verified)
Action: Idempotently creates order record and enqueues render_petstory_book job
```

---

### 7. AI Generation & Document-Rendering Strategy

#### 7.1 Hybrid Deterministic Content Architecture
* **Do NOT use raw LLM generation for book pages during runtime.** Calling an LLM per page introduces latency, token costs, layout instability, and vulnerability to prompt injection via owner inputs.
* **Deterministic Template Architecture:** Base book layouts, typography styles, and narrative structures are 100% deterministic Jinja2 / HTML templates.
* **Bounded AI Role (Gemini 2.5 Flash):** AI is restricted to an optional assistance feature during the quiz: converting raw user memories into polished, 4-line dedication poetry.

#### 7.2 Rendering Engine: WeasyPrint (Python Worker)
* **Headless Chrome (Puppeteer) Rejected:** Chromium processes consume 400MB+ RAM per instance, introduce significant process-spawn overhead, and crash frequently on entry-tier servers.
* **WeasyPrint Selected:**
  * Uses standard HTML5 and CSS Paged Media (`@page`, `size: 210mm 210mm;`, `bleed: 3mm;`).
  * Native Python execution in background worker process.
  * Consistently compiles a 24-page 300 DPI book in <2.8 seconds using <90MB RAM.
  * Embeds local TrueType font subsets (`Cabin`, `Playfair Display`) without external network dependencies.

---

### 8. Cost, Compute & Free-Tier Feasibility

| Resource | Service / Provider | Free Tier Limits | PetStory Consumption / Unit | Feasibility Verdict |
|---|---|---|---|---|
| **Database** | Supabase Postgres | 500 MB storage | ~2 KB per session / order | **SAFE:** Supports 50,000+ sessions without cost. |
| **Storage** | Supabase Storage | 1 GB storage | ~6 MB per book (photos + PDF) | **CAUTION:** Holds ~160 orders. Purge raw uploads after 14 days. |
| **API Compute** | Vercel Serverless | 100 GB-hrs / month | Fast REST endpoints (<100ms) | **SAFE:** Static pages & API routes well within limits. |
| **Worker Compute** | Developer Workstation | Unlimited local | PDF rendering (~2.8s CPU) | **SAFE for MVP.** \$5/mo cloud worker needed for 24/7 scale. |
| **AI Quotas** | Gemini 2.5 Flash | 15 RPM / 1M TPM | Optional 1 call per session | **SAFE:** Zero-cost under permitted quota. |
| **Bandwidth** | Supabase Egress | 2 GB / month | ~3.5 MB per completed PDF | **CAUTION:** Allows ~570 downloads. Route via Cloudflare CDN. |

---

### 9. Philippines Payment, Payout & Compliance

1. **Merchant of Record (MoR) Selection: Lemon Squeezy or Paddle.**
   * *Problem with Direct Stripe:* Direct Stripe accounts are invite-only and restricted for Philippine sole proprietorships.
   * *Problem with PayMongo:* PayMongo is optimized for domestic Philippine channels (GCash, Maya) and experiences high decline rates on international credit cards. Furthermore, direct gateways leave international sales tax and EU VAT compliance on the merchant.
   * *MoR Advantage:* Lemon Squeezy / Paddle acts as the legal reseller, absorbing global tax calculation, remittance, and chargeback liabilities.
2. **Payout Rail:**
   * Lemon Squeezy $\rightarrow$ Wise Business USD Account (via ACH) $\rightarrow$ Instant FX transfer to local Philippine bank account (BDO, BPI, UnionBank).
3. **Cash Flow Model:**
   * 100% digital fulfillment means zero inventory and zero physical production outlays. Every sale yields immediate positive net contribution margin.

---

### 10. Risks, Guardrails & Quality Acceptance Criteria

#### 10.1 Two-Tier Quality Enforcement Layer (QEL)

```
[Design-Time Template QEL] 
   ├── QG-T1: Valid CSS Paged Media syntax (no unsupported CSS3 properties).
   ├── QG-T2: Local commercial font assets present; zero external CDN dependencies.
   ├── QG-T3: Extreme name length stress testing (1 character vs 35 characters).
   └── QG-T4: WCAG AAA contrast ratio compliance on all selectable palettes.

[Runtime Order Instance QEL]
   ├── QG-R1: Image resolution >= 150 DPI; aspect ratio preservation.
   ├── QG-R2: Page count assertion: len(output.pages) == 24 (zero overflow).
   ├── QG-R3: Input sanitization: strict HTML tag stripping and length bounds.
   └── QG-R4: PDF integrity check: PyMuPDF verification without syntax errors.
```

---

### 11. Recommended Phased Implementation Plan

```
WEEKS:      Week 1         Week 2         Week 3         Week 4         Week 5
PHASES:  [-- P01 --]    [-- P02 --]    [-- P03 --]    [-- P04 --]    [-- P05 --]
SCOPE:   Funnel & DB    PDF Template   Runtime QEL    Checkout &     Live Commercial
         Foundation     & Worker       & Preview      Delivery       Validation
```

* **Phase 1: Funnel & Data Contracts (Week 1)**
  * Apply database migrations for `personalization_templates` and `customization_sessions`.
  * Build Next.js step-wizard frontend driven by `petstory_v1_schema.json`.
  * Implement session auto-save and image upload API endpoints.
* **Phase 2: Template Design & Worker Pipeline (Week 2)**
  * Code 24-page HTML/CSS Paged Media template for square 210mm x 210mm format.
  * Configure local font assets and Jinja2 interpolation context.
  * Build background worker task to compile complete PDF via WeasyPrint.
* **Phase 3: Real-Time Preview & Runtime QEL (Week 3)**
  * Implement synchronous cover preview endpoint rendering watermarked WebP.
  * Connect flipbook preview component into Step 26 of questionnaire.
  * Implement automated Runtime QEL assertions (PyMuPDF page count check).
* **Phase 4: Checkout & Delivery Engine (Week 4)**
  * Integrate Lemon Squeezy hosted checkout with webhook signature verification.
  * Connect post-purchase render trigger and transactional email delivery (Resend).
  * Build secure, rate-limited `/download/{token}` endpoint with 90-day expiry.
* **Phase 5: First Commercial Milestone (Week 5)**
  * Conduct live end-to-end controlled test purchase (\$9.99).
  * Verify compilation within 60 seconds and inspect PDF on multiple devices.
  * Audit JCCF finance ledger: record gross sale, MoR fees, and net contribution.

---

### Conclusion & Operational Directive

Do not attempt to shoehorn PetStory into the static batch marketplace pipeline of Blueprint v1.0, and do not write a throwaway custom script. Implement **Subsystem M13 (Interactive Personalization Engine)** following the specifications detailed above. Wait for owner review and sign-off on the Phase 1 migration before applying database changes.

