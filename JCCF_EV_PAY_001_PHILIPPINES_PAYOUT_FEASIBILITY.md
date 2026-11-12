# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Philippine Merchant of Record & Payout Feasibility Assessment (v3.0)

**Document ID:** `JCCF-EV-PAY-001`  
**Version:** 3.0 (Traceable Provider Documentation Citations)  
**Date:** 12 November 2026 (Audited & Grounded)  
**Status:** Verification Audit Complete — Traceable Provider Grounding Established  
**Author:** Antigravity Architecture & Finance Review  
**Subject:** Payout feasibility, fee schedules, tax liability, and settlement timing for Philippine entities  

---

## 1. Executive Summary & Authoritative Verification

To resolve outstanding provider uncertainties, official documentation from **Lemon Squeezy** and **Paddle** was verified on **12 November 2026** regarding onboarding eligibility, supported payout rails, fee structures, and tax boundaries for entities operating from the **Philippines**.

### Key Findings
1. **Lemon Squeezy Country Support:** The Philippines is an **officially supported payout country** ([docs.lemonsqueezy.com/help/getting-started/supported-countries](https://docs.lemonsqueezy.com/help/getting-started/supported-countries)).
2. **Payout Schedule & Holding Period:** Payouts are generated **twice monthly on the 1st and 15th** of each month following a **13-day holding period** ([docs.lemonsqueezy.com/help/payouts/payout-schedule](https://docs.lemonsqueezy.com/help/payouts/payout-schedule)).
3. **Payout Rails & Fees (International):**
   - **Bank Account (Direct Transfer):** Converted to PHP using mid-market exchange rates. Fee: **1% per payout** for bank accounts outside the US ([docs.lemonsqueezy.com/help/payouts/payout-fees](https://docs.lemonsqueezy.com/help/payouts/payout-fees)).
   - **PayPal:** Sent in USD. Fee: **3% per payout** (capped at \$30 USD) for international accounts ([docs.lemonsqueezy.com/help/payouts/payout-fees](https://docs.lemonsqueezy.com/help/payouts/payout-fees)).
4. **Platform Transaction Pricing:** Base fee is **5% + $0.50 USD** per transaction. An additional **+1.5%** applies to international transactions outside the US ([docs.lemonsqueezy.com/help/getting-started/pricing](https://docs.lemonsqueezy.com/help/getting-started/pricing)).
5. **Paddle Vendor Support:** The Philippines is fully supported as a vendor destination ([paddle.com/help](https://paddle.com)) via Wire Transfer (SWIFT) or Payoneer.
6. **MoR Tax Scope:** As Merchant of Record, Lemon Squeezy and Paddle calculate, collect, and remit sales tax, VAT, and GST in customer jurisdictions globally. They do **not** file Philippine domestic income tax (BIR Form 1701/1702/2551Q). These remain external operator business obligations.

---

## 2. Traceable Provider Documentation Citations

| Documentation Item | Official Provider URL | Evidence Grounding Date | Verified Rule / Finding |
|---|---|---|---|
| **Philippines Eligibility** | `https://docs.lemonsqueezy.com/help/getting-started/supported-countries` | 2026-11-12 | Philippines explicitly listed in supported countries for payouts. |
| **Payout Timing & Schedule**| `https://docs.lemonsqueezy.com/help/payouts/payout-schedule` | 2026-11-12 | Twice monthly (1st & 15th). 13-day holding period. 1–5 business days clearing. |
| **Payout Disbursement Fees**| `https://docs.lemonsqueezy.com/help/payouts/payout-fees` | 2026-11-12 | International bank account: 1% fee. International PayPal: 3% fee (max $30). |
| **Platform E-commerce Fees**| `https://docs.lemonsqueezy.com/help/getting-started/pricing` | 2026-11-12 | 5% + $0.50 base. International non-US buyers: +1.5%. PayPal transactions: +1.5%. |
| **Paddle Vendor Eligibility**| `https://www.paddle.com/legal/terms` | 2026-11-12 | Philippines supported for vendor onboarding via Payoneer / Wire Transfer. |

---

## 3. Financial Settlement Flow & Local Operational Realities

```
[Customer Checkout: $12.99 USD]
          |
          v
[Lemon Squeezy MoR Ingestion]
    - Base platform fee: 5.0% ($0.65 USD)
    - Fixed transaction fee: $0.50 USD
    - International buyer surcharge (if applicable): +1.5% ($0.19 USD)
    - Remits destination sales tax / VAT directly to customer tax authorities
          |
          v
[Net Settlement Balance: ~$11.65 to $11.84 USD] (Accumulates in merchant account)
          |
          v
[13-Day Holding Window Cleared -> 1st or 15th Payout Trigger]
    +---> Option A: Direct Bank Transfer (Philippine Local Bank: BDO, BPI, UnionBank)
    |         - Deducts 1% international payout disbursement fee
    |         - Converted to PHP at live mid-market exchange rate
    |         - Clearing time: 1–5 business days
    |         - Bank FX spread: ~1.5% to 2.5% absorbed during conversion
    |
    +---> Option B: PayPal Account (USD Balance)
              - Deducts 3% international PayPal payout fee (capped at $30 USD)
              - Received as USD; withdrawable to GCash or local bank via PayPal rails
```

---

## 4. Reconciled Financial Assumptions (500 Orders/Month Model)

The commercial economics are classified under realistic cost assumptions incorporating international transaction fees:

| Financial Component | Basis / Formula | Monthly Amount | Classification & Transition Trigger |
|---|---|---|---|
| **Gross Sales (500 @ $12.99)** | Top-line customer revenue | **\$6,495.00 USD** | `[VERIFIED]` Customer Payments |
| **MoR Variable Base Fee (5.0%)** | 5.0% of Gross Sales | -\$324.75 USD | `[VERIFIED]` Source deduction |
| **MoR Fixed Transaction Fee** | 500 orders @ \$0.50 USD | -\$250.00 USD | `[VERIFIED]` Source deduction |
| **MoR International Surcharge (1.5%)**| Est. 50% non-US buyers ($6.495 * 1.5% * 0.5) | -\$48.71 USD | `[ASSUMPTION]` Provider international surcharge |
| **MoR Payout Disbursement Fee (1.0%)**| 1% fee on bi-monthly bank transfers | -\$58.70 USD | `[VERIFIED]` Documented international bank fee |
| **Fixed Infrastructure (Supabase Pro)**| Pro DB & Storage ($25/mo) | -\$25.00 USD | `[ASSUMPTION]` If scaled past free tier |
| **Fixed Infrastructure (Vercel Pro)** | Next.js Team Hosting ($20/mo) | -\$20.00 USD | `[ASSUMPTION]` Commercial team tier |
| **Worker VM (Cloud VPS)** | 24/7 Background Rendering | -\$5.00 USD | `[ASSUMPTION]` Fly.io / Hetzner Tier |
| **Variable Storage & Bandwidth** | Egress & Retained PDF Overages | -\$1.00 USD | `[ASSUMPTION]` CDN Mitigated |
| **Refund Allowance (2.0%)** | Estimated 2% refund rate (10 units) | -\$129.90 USD | `[ASSUMPTION]` Customer Dispute Buffer |
| **Non-Refundable Gateway Fees** | 10 refunds @ retained gateway rate | -\$11.50 USD | `[ASSUMPTION]` MoR Retained Fees |
| **Estimated Operating Contribution (EOC)**| **Gross less MoR Fees, Fixed Infra, Refunds**| **\$5,620.44 USD** | `[RECOMMENDATION]` **86.5% Contribution Margin** |

* `[CRITICAL FINANCIAL DISTINCTION]`: The **$5,620.44 USD** monthly figure is an **Estimated Operating Contribution (EOC)** prior to domestic Philippine taxes and bank FX conversion spreads.
* `[OPERATOR OBLIGATIONS]`:
  - **Philippine Taxation:** Bureau of Internal Revenue (BIR) taxes (12% VAT or 1%–3% percentage tax, plus annual income tax) are operator liabilities settled directly with the Philippine government.
  - **Bank FX Conversion:** Local bank foreign exchange spreads (USD to PHP) reduce net converted pesos by approximately 1.5% to 2.5% upon local withdrawal.

---

## 5. Commercial Feasibility Conclusion

The integration of Lemon Squeezy as the candidate Merchant of Record for JCCF's Philippine operation is **technically and commercially feasible**. Supported bank rails, automated bi-monthly settlement, and transparent fee schedules align with the zero-fixed-cost MVP architecture.
