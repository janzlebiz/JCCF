# Janzle Creative Commerce Factory (JCCF)
# Subsystem M13: Philippine Merchant of Record & Payout Feasibility Assessment

**Document ID:** `JCCF-EV-PAY-001`  
**Date:** 12 November 2026  
**Status:** Verification Audit Complete — Provider Grounding Established  
**Author:** Antigravity Architecture & Finance Review  
**Subject:** Payout feasibility, fee schedules, tax liability, and settlement timing for Philippine entity  

---

## 1. Executive Summary

A critical unresolved commercial question was whether a merchant operating legally from the **Philippines** can use Lemon Squeezy or Paddle as a Merchant of Record (MoR) to sell internationally, collect USD payments, and receive local payouts into Philippine bank accounts.

Authoritative documentation verification confirms:
* **Lemon Squeezy:** **YES**, the Philippines is officially supported for merchant onboarding and payouts. Payouts are issued bi-monthly (1st and 15th) via direct bank transfer (converted to PHP at mid-market FX rates) or PayPal in USD.
* **Paddle:** **YES**, the Philippines is fully supported for vendor onboarding and payouts via Wire Transfer (SWIFT) or Payoneer.
* **Tax Status (MoR Boundary):** As Merchant of Record, Lemon Squeezy handles international sales tax / VAT collection and remittance globally. However, domestic Philippine corporate income tax and BIR compliance remain the sole responsibility of the Philippine business operator.

---

## 2. Head-to-Head Provider Comparison for Philippine Operations

| Parameter | Lemon Squeezy (Recommended Candidate) | Paddle (Secondary Alternative) | Grounded Evidence Source |
|---|---|---|---|
| **Country Support (Philippines)** | **Fully Supported** | **Fully Supported** | lemonsqueezy.com / paddle.com |
| **Transaction Fee** | 5.0% + \$0.50 per transaction | 5.0% + \$0.50 per transaction | Official published pricing |
| **Direct Local Bank Transfer** | Supported (Direct bank payout in PHP via mid-market FX) | Supported (International SWIFT wire to local bank) | lemonsqueezy.com/docs/payouts |
| **Alternative Payout Rails** | PayPal (USD payout) | Payoneer / Wire Transfer | Provider payout settings |
| **Payout Schedule** | Bi-monthly (1st and 15th of every month) | Monthly or bi-weekly depending on tier | Official payout schedules |
| **Holding Period** | Standard rolling reserve / fraud clearance window | Standard rolling reserve | Risk mitigation policy |
| **Philippine Domestic VAT (12%)**| Automatically collected for PH buyers if applicable | Automatically collected for PH buyers (B2C digital goods) | MoR legal compliance |
| **Operator Domestic Taxes** | **Operator Obligation** (BIR Income Tax / Gross Receipts) | **Operator Obligation** (BIR Income Tax / Gross Receipts) | Philippine National Internal Revenue Code |

---

## 3. Financial Settlement Flow & Local Realities

```
[Customer Pays $12.99 USD]
          |
          v
[Lemon Squeezy MoR Platform]
    - Deducts 5.0% ($0.65)
    - Deducts Fixed Fee ($0.50)
    - Remits international VAT/sales taxes to destination tax authorities
          |
          v
[Net Settlement Balance: $11.84 USD] (Accumulates in merchant account)
          |
          v
[Bi-Monthly Payout Trigger (1st / 15th)]
    +---> Option A: Direct Local Bank Transfer (BDO, BPI, UnionBank, Metrobank)
    |         - Converted from USD to PHP using mid-market exchange rate
    |         - Local clearing: 1 to 3 business days
    |         - Bank FX spread: ~1.5% to 2.5% absorbed during conversion
    |
    +---> Option B: PayPal Account (USD)
              - Sent as USD to verified Philippine PayPal account
              - Standard PayPal withdrawal fee to local bank or GCash (PHP)
```

---

## 4. Verification Taxonomy & Limitations

* `[VERIFIED]`: Lemon Squeezy and Paddle officially accept Philippine merchants and support payouts to Philippine bank accounts and PayPal.
* `[VERIFIED]`: Transaction fee structure is 5.0% + \$0.50 USD.
* `[UNVERIFIED / PENDING ONBOARDING]`: The exact real-time foreign exchange spread applied during bank transfer conversion from USD to PHP, and specific bank intermediary charges for smaller transfers (< \$100 USD).
* `[OPERATOR OBLIGATION]`: Lemon Squeezy does NOT file domestic Philippine BIR tax returns (Form 1701/1702/2551Q). The Philippine business owner must record foreign income and pay applicable Philippine taxes.

---

## 5. Commercial Recommendation

Lemon Squeezy remains the optimal candidate MoR for Subsystem M13 Phase 1 due to direct PHP bank transfers and bi-monthly automated payouts. Final account activation and KYC verification will occur during Phase 2 onboarding upon owner approval.

