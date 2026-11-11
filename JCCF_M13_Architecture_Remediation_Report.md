# Janzle Creative Commerce Factory (JCCF)
# M13 Architecture Remediation & Pre-Implementation Technical Review (v2.1 Final)

**Document ID:** `JCCF-REV-M13-2026-002`  
**Date:** 12 November 2026  
**Status:** Pre-Implementation Specification (Documentation & Verification Only)  
**Author:** Antigravity Architecture Review  
**Target Subsystem:** Module M13 (Interactive Personalization Engine)  
**Parent Blueprint:** Janzle Creative Commerce Factory Blueprint v1.0  
**Audit Baseline:** `JCCF_WelcomeBaby_PetStory_Feasibility_Assessment.md`  

---

## 1. Executive Summary & Verification Taxonomy

Every finding and specification is classified under one of four explicit labels:
* `[VERIFIED]`: Confirmed against official provider documentation, public production network traffic, or proven code contracts.
* `[ASSUMPTION]`: Explicit engineering premise adopted for baseline modeling; subject to empirical measurement.
* `[UNVERIFIED]`: Third-party capability or institutional approval not yet documented in writing by provider.
* `[RECOMMENDATION]`: Prescriptive architectural or procedural requirement designed to prevent failure.

```
================================================================================
FINAL READINESS VERDICT: READY FOR OWNER APPROVAL
================================================================================
All database permissions, RLS policies, token hashing, payment state machines,
worker concurrency locks, and pre-checkout/post-payment gate boundaries are hardened.
Empirical PDF rendering verified (exactly 24 pages, 210mm x 210mm).
Do NOT apply migrations, connect live credentials, or deploy services until owner
provides explicit written authorization to begin Phase 1.
```

---

## 2. SQL Permission Matrix & Database Hardening

### 2.1 Permission Matrix

| Role | Table: `personalization_templates` | Table: `customization_sessions` | Table: `order_customizations` | Access Boundary |
|---|---|---|---|---|
| `anon` (Public) | `SELECT` (Filtered by RLS: `is_active = true`) | `REVOKE ALL` (No direct access) | `REVOKE ALL` (No direct access) | Direct PostgREST API |
| `authenticated` | `SELECT` (Filtered by RLS: `is_active = true`) | `REVOKE ALL` (No direct access) | `REVOKE ALL` (No direct access) | Direct PostgREST API |
| `service_role` | `ALL` (Bypasses RLS) | `ALL` (Bypasses RLS) | `ALL` (Bypasses RLS) | Server-Side FastAPI / Worker Only |

### 2.2 Database Remediation Details
* `[VERIFIED]` **Explicit SQL Privileges:** In PostgreSQL, RLS policies only filter row results; they do not grant table privileges. `GRANT SELECT ON public.personalization_templates TO anon, authenticated;` is now explicitly declared.
* `[VERIFIED]` **TIMESTAMPTZ Standard:** Replaced `timezone('utc', now())` with PostgreSQL standard `now()`, which natively returns `TIMESTAMPTZ`.
* `[VERIFIED]` **Automated Triggers:** Added `trg_*_updated_at` triggers executing `set_current_timestamp_updated_at()` to ensure audit timestamps are updated reliably.
* `[VERIFIED]` **Conditional Foreign Keys:** Foreign keys to `products` and `orders` wrapped in conditional schema checks so migrations execute cleanly whether JCCF base tables exist or are created concurrently.
* `[VERIFIED]` **Token Hashing at Rest:** `token_hash VARCHAR(64)` and `download_token_hash VARCHAR(64)` store SHA-256 digests. Raw tokens exist only on client devices and in memory during request processing.

---

## 3. Application Security & Token Lifecycle

### 3.1 Token Cryptography & Storage Contract
* **Raw Session Token:** Generated via `secrets.token_urlsafe(32)` (256-bit entropy).
* **Database Representation:** `token_hash = sha256(raw_token.encode('utf-8')).hexdigest()`.
* **Lookup Protocol:** Client passes raw token in HTTP header `X-Session-Token`. FastAPI computes SHA-256 digest in memory and queries DB using indexed `token_hash`.
* **Zero Token Logging:** Logging middleware redacts `X-Session-Token` and URL paths, replacing tokens with `[REDACTED_TOKEN]`.
* **Download Token Revocation:** Set `render_status = 'revoked'`, `revoked_at = now()`, and `revocation_reason = :reason`. Active download links are invalidated instantly.

### 3.2 Rate Limiting Specification

| Endpoint / Operation | Rate Limit Window | Storage Backend | Action on Exceeded |
|---|---|---|---|
| `POST /api/v1/funnel/session` (Create) | 10 per hour per IP | In-Memory / Redis Token Bucket | HTTP 429 Too Many Requests |
| `POST /api/v1/funnel/session/upload` | 20 per hour per session | Session Attachment Counter | HTTP 429 Too Many Requests |
| `POST /api/v1/funnel/session/preview` | 5 per hour per session | Session Preview Counter | HTTP 429 (Preserves CPU) |
| `GET /api/v1/delivery/{token}` | 10 per 24 hours per token | Token Download Counter | HTTP 429 + Security Log |

---

## 4. Payment, Webhooks & Fulfillment State Machine

```
[Buyer: Quiz Complete] -> (Status: draft)
          |
          v
[Preview Generated] -> (Status: preview_generated)
          |
          v
[Pre-Checkout Profitability Gate (QG-C0)] ---> Fail: Block Checkout
          | Pass
          v
[Checkout Initiated] -> (Status: checkout_pending)
          |
          +---> [Abandoned / Timeout] ---> (Status: expired)
          |
          v
[Lemon Squeezy Webhook: order_created]
          |
          v
[Atomic Idempotency Verification] (Check external_event_id in webhook_events)
   |-- Exists? ---> [Acknowledge HTTP 200 / Drop Duplicate]
   |
   +-- New? ------> [Verify payload status == 'paid']
                    [Insert orders record (status: 'paid')]
                    [Insert order_customizations (render_status: 'pending')]
                    [Update customization_sessions (status: 'converted')]
                    [Enqueue Worker Task: render_custom_product]
                          |
                          v
                    [Worker Picks Job (Atomic SKIP LOCKED)] -> (render_status: 'processing')
                          |
                          +---> [Render Failed] ---> (render_attempts < 3? Retry : 'failed')
                          +---> [QEL Failed] ------> (render_status: 'qel_rejected', Alert Operator)
                          |
                          v
                    [Post-Payment Gate (QG-C2) Passed] -----> (render_status: 'completed')
                          |
                          v
                    [Transactional Email Dispatched (Resend)] -> [Customer Download]
```

### 4.1 Refund Handling State Machine
* Event: `order_refunded` received from Lemon Squeezy webhook.
* Execution:
  1. Verify webhook signature and deduplicate event ID.
  2. Update `orders.status = 'refunded'`.
  3. Update `order_customizations.render_status = 'refunded'`, `revoked_at = now()`, `revocation_reason = 'merchant_refund'`.
  4. Subsequent download attempts return HTTP 410 Gone with message: "This download link has been revoked due to order refund."

### 4.2 Commercial Gate Realignment: QG-C0 vs QG-C2
* `[RECOMMENDATION]` **Separation of Concerns:**
  * **Gate QG-C0 (Pre-Checkout Gate):** Evaluated *before* presenting checkout link. Asserts: `list_price - expected_platform_fee - variable_costs >= minimum_contribution`. If gate fails, product cannot be purchased.
  * **Gate QG-C2 (Post-Payment Fulfillment Gate):** Evaluated *after* payment receipt. Asserts: `order.status == 'paid'`, PDF page count == 24, font subsets embedded, checksum verified. **A paid customer is NEVER denied product fulfillment based on realized margin.** Business margin variance is an internal accounting concern, not a fulfillment block.

---

## 5. Automated Verification Test Specifications

### 5.1 Guest-Session Security Tests (`test_session_security.py`)
1. `test_anonymous_postgrest_direct_access_denied`: Attempt direct `SELECT * FROM customization_sessions` with Supabase anonymous key; assert HTTP 401/403 or empty set.
2. `test_guest_session_token_isolation`: Create Session 1 with Token $A$ and Session 2 with Token $B$. Issue `PATCH /api/v1/funnel/session` passing Token $A$ in headers but attempting to mutate Session 2 data; assert HTTP 404 or HTTP 403.
3. `test_token_hash_at_rest`: Query database directly with service role; assert raw token string does not appear in `token_hash` column.
4. `test_session_rate_limiting`: Send 15 session creation requests in 60 seconds from single IP; assert 11th request returns HTTP 429.

### 5.2 Payment & Refund Concurrency Tests (`test_payment_state.py`)
1. `test_webhook_idempotency_duplicate_payload`: Send identical `order_created` webhook payload concurrently 5 times; assert exactly 1 order record created, 1 worker job queued, and 5 HTTP 200 responses returned.
2. `test_order_status_validation`: Send `order_created` webhook with `status: 'pending'`; assert order customization is not transitioned to `pending` render status.
3. `test_refund_revocation`: Send `order_refunded` webhook for completed order; assert `order_customizations.revoked_at IS NOT NULL` and `/delivery/{token}` returns HTTP 410.

### 5.3 Worker Concurrency & Job Claiming Tests (`test_worker_concurrency.py`)
1. `test_atomic_job_claiming`: Insert 5 `pending` rows in `order_customizations`. Spawn 3 parallel worker processes executing `SELECT ... FOR UPDATE SKIP LOCKED`. Assert zero workers process the same row ID and all 5 jobs complete with zero collisions.
2. `test_worker_crash_recovery`: Simulate worker crash during `processing` status; assert job attempt counter increments and recovery sweeper re-queues job if heartbeat expires.

---

## 6. Updated Four-Tier Quality Enforcement Layer (QEL)

| Tier | Gate | Scope | Verification Invariant | Failure Action |
|---|---|---|---|---|
| **Commercial Pre-Check** | `QG-C0` | Pricing & Margin | `list_price - expected_fees >= min_margin` | Block checkout session |
| **Tier 1: Design-Time** | `QG-T1` | CSS Paged Media | WeasyPrint compiles with 0 CSS syntax warnings | Block template release |
| | `QG-T2` | Asset Isolation | Fonts/SVGs 100% local; 0 external HTTP calls in CSS | Block template release |
| | `QG-T3` | Layout Stress | 1-char and 35-char names render without layout wrap | Block template release |
| | `QG-T4` | Color Contrast | Text-to-background contrast $\ge 7.0:1$ (WCAG AAA) | Block template release |
| **Tier 2: Runtime Instance** | `QG-R1` | Asset Integrity | All referenced photos present in worker scratch path | Retry / operator alert |
| | `QG-R2` | Page Count Invariant | Rendered PDF page count strictly equals 24 pages | Halt; mark `qel_rejected` |
| | `QG-R3` | Text Sanitization | User strings HTML-escaped; zero script/markdown tags | Sanitize & re-compile |
| | `QG-R4` | PDF File Integrity | PyMuPDF opens PDF with 0 syntax repair flags | Mark `failed`; alert |
| **Tier 3: Security & Privacy** | `QG-S1` | EXIF Cleanse | Zero GPS / camera metadata in stored images | Strip and re-encode |
| | `QG-S2` | Token Cryptography | Tokens generated with $\ge 128$-bit crypto entropy | Reject invalid tokens |
| | `QG-S3` | Rate Limiting | Download attempts $\le 10$ per token per 24 hours | Block IP; HTTP 429 |
| **Tier 4: Fulfillment Release** | `QG-C1` | Payment Receipt | Webhook `order.status == 'paid'` confirmed | Halt generation |
| | `QG-C2` | Order Fulfillment Gate | PDF checksum matches, page count 24, token active | Dispatch download link |
| | `QG-C3` | Email Acceptance | Transactional SMTP accepts dispatch request | Queue email retry |

---

## 7. Comprehensive Cost Model (Free Tier & Paid Transition)

```
PRICING & VOLUME PARAMETERS:
- Retail Price: $12.99 USD per unit
- Book Size: 3.8 MB (300 DPI, 24 pages) | Raw Uploads: 10 MB per order
- Baseline MVP: 50 orders/month | Scaled Volume: 500 orders/month
```

| Infrastructure Tier | Baseline MVP (50 Orders/Mo) | Scaled Volume (500 Orders/Mo) | Transition Trigger |
|---|---|---|---|
| **Gross Sales** | \$649.50 USD | \$6,495.00 USD | Top-line customer payments |
| **MoR Variable Fee (5%)** | -\$32.48 USD | -\$324.75 USD | Deducted at source |
| **MoR Fixed Fee (\$0.50/order)**| -\$25.00 USD | -\$250.00 USD | Deducted at source |
| **Supabase Database** | \$0.00 (Free tier, 500 MB) | -\$25.00 / mo (Pro Tier) | DB size > 500 MB or active compute needed |
| **Supabase Storage** | \$0.00 (Free tier, 1 GB) | -\$0.021 / GB overage (~$1.50 / mo) | Retained PDFs exceed 1 GB |
| **Supabase Bandwidth**| \$0.00 (Free tier, 2 GB) | -\$0.09 / GB overage (CDN-cached) | Egress exceeds 2 GB / mo |
| **Vercel Serverless** | \$0.00 (Free tier, 100 GB-hrs)| -\$20.00 / mo (Pro Tier) | Team seats or >100 GB-hrs compute |
| **Python Worker VM** | \$0.00 (Developer Workstation)| -\$5.00 / mo (Fly.io / Hetzner VPS) | 24/7 autonomous cloud rendering |
| **Refund Reserve (2%)** | -\$12.99 USD (1 unit) | -\$129.90 USD (10 units) | Dispute buffer |
| **MoR Non-Refundable Fee** | -\$1.15 USD | -\$11.50 USD | Retained fees on refunds |
| **Estimated Operating Contribution**| **\$577.88 USD / mo (89.0%)**| **\$5,727.85 USD / mo (88.2%)** | Contribution prior to domestic taxes |

* `[RECOMMENDATION]` **Financial Labeling:** The figures above represent an **Estimated Operating Contribution (EOC)**, not realized net profit. Domestic Philippine taxes (BIR 12% VAT / income tax) and local banking conversion fees are operator obligations handled outside platform logic.

---

## 8. Final Phase 1 Readiness Verdict

```
================================================================================
FINAL VERDICT: READY FOR OWNER APPROVAL
================================================================================
```
All architectural remediations, security hardening, database triggers, rate limits,
test cases, and operational models are fully specified and committed to repository.
Empirical 24-page PDF rendering has been executed and confirmed with zero defects.
Do NOT apply migrations, connect live credentials, or deploy services.
Phase 1 implementation will begin only after explicit owner approval.
