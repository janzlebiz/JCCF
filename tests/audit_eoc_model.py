"""
Janzle Creative Commerce Factory (JCCF) - Subsystem M13
Reproducible Estimated Operating Contribution (EOC) Model & Independent Verification Script

This script validates every individual deduction and the final net contribution for the
500 units/month scaled volume scenario. All scenario inputs and assumptions are labeled.
Independent programmatic assertions verify each mathematical step.

REFUND ACCOUNTING CORRECTION:
- Platform fees (5% base + $0.50 fixed + 1.5% intl surcharge) on all 500 orders ($623.46)
  are already accounted for in initial fee deductions.
- Per Lemon Squeezy policy (docs.lemonsqueezy.com/help/payments/refunds-and-chargebacks),
  retained platform fees ($11.50 across 10 refunds) are kept by the provider and not returned.
- Therefore, the refund deduction applied against payout balance is:
  Refund Payout Adjustment = Customer Refund ($129.90) - Retained Platform Fee ($11.50) = $118.40.
- Retained fees ($11.50) are NOT deducted a second time.
- Timeline: Modeled under Lemon Squeezy's 13-day holding cycle, where refunds within the cycle
  are reconciled prior to the semi-monthly bank payout disbursement calculation.
"""

def test_reproducible_eoc_model():
    # =========================================================================
    # 1. SCENARIO INPUTS & ASSUMPTIONS (EXPLICITLY LABELED)
    # =========================================================================
    RETAIL_PRICE_USD = 12.99               # Scenario Input: Target unit retail price
    MONTHLY_ORDER_VOLUME = 500             # Scenario Input: 500 orders/month scaled milestone
    INTL_BUYER_RATIO = 0.50                # Assumption: 50% US buyers, 50% international buyers
    REFUND_RATE_RATIO = 0.02               # Assumption: 2.0% customer refund rate (10 units)
    
    # Provider Pricing Parameters (Documented Lemon Squeezy Rates as of Nov 2026):
    MOR_BASE_FEE_RATE = 0.05               # 5.0% base platform fee
    MOR_FIXED_FEE_USD = 0.50               # $0.50 fixed transaction fee per unit
    MOR_INTL_SURCHARGE_RATE = 0.015        # +1.5% surcharge on international non-US transactions
    MOR_PAYOUT_FEE_RATE = 0.01             # 1.0% fee on international bank transfer disbursements
    
    # Provider Refund Policy Parameters (docs.lemonsqueezy.com/help/payments/refunds-and-chargebacks):
    # Lemon Squeezy retains initial platform processing fees upon refund.
    # Platform fee on a $12.99 sale = ($12.99 * 5.0% = $0.65) + $0.50 = $1.15 per unit.
    RETAINED_FEE_PER_REFUND_USD = 1.15     # Retained fee per refunded unit
    
    # Fixed Infrastructure Cost Parameters (Scaled Past Free Tier):
    INFRA_SUPABASE_PRO_USD = 25.00         # Supabase Pro DB & Storage (>500MB DB, >1GB storage)
    INFRA_VERCEL_PRO_USD = 20.00           # Vercel Team / Pro serverless hosting
    INFRA_CLOUD_VPS_USD = 5.00             # Fly.io / Hetzner 24/7 background worker VM
    INFRA_STORAGE_EGRESS_USD = 1.00        # CDN egress & retained artifact overages
    
    # =========================================================================
    # 2. STEP-BY-STEP MATHEMATICAL DEDUCTIONS
    # =========================================================================
    
    # Step A: Gross Top-Line Revenue
    gross_sales = round(MONTHLY_ORDER_VOLUME * RETAIL_PRICE_USD, 2)
    assert gross_sales == 6495.00, f"Gross sales mismatch: expected 6495.00, got {gross_sales}"
    
    # Step B: MoR Base Variable Fee (5.0% across all 500 orders)
    mor_base_fee = round(gross_sales * MOR_BASE_FEE_RATE, 2)
    assert mor_base_fee == 324.75, f"Base fee mismatch: expected 324.75, got {mor_base_fee}"
    
    # Step C: MoR Fixed Fee ($0.50 per order across all 500 orders)
    mor_fixed_fee = round(MONTHLY_ORDER_VOLUME * MOR_FIXED_FEE_USD, 2)
    assert mor_fixed_fee == 250.00, f"Fixed fee mismatch: expected 250.00, got {mor_fixed_fee}"
    
    # Step D: International Buyer Surcharge (+1.5% on non-US volume)
    intl_gross_volume = gross_sales * INTL_BUYER_RATIO
    mor_intl_surcharge = round(intl_gross_volume * MOR_INTL_SURCHARGE_RATE, 2)
    assert mor_intl_surcharge == 48.71, f"Intl surcharge mismatch: expected 48.71, got {mor_intl_surcharge}"
    
    total_initial_mor_fees = round(mor_base_fee + mor_fixed_fee + mor_intl_surcharge, 2)
    assert total_initial_mor_fees == 623.46, f"Initial MoR fees mismatch: expected 623.46, got {total_initial_mor_fees}"
    
    # Step E: Refund Payout Adjustment (Policy-Accurate & Non-Double-Counted)
    # 10 orders refunded out of 500:
    refund_units = int(MONTHLY_ORDER_VOLUME * REFUND_RATE_RATIO)
    assert refund_units == 10, f"Refund units mismatch: expected 10, got {refund_units}"
    
    customer_refund_gross = round(refund_units * RETAIL_PRICE_USD, 2)
    assert customer_refund_gross == 129.90, f"Customer refund gross mismatch: expected 129.90, got {customer_refund_gross}"
    
    retained_platform_fees = round(refund_units * RETAINED_FEE_PER_REFUND_USD, 2)
    assert retained_platform_fees == 11.50, f"Retained platform fees mismatch: expected 11.50, got {retained_platform_fees}"
    
    # Lemon Squeezy official refund deduction rule:
    # "the refunded amount minus Lemon Squeezy's platform fee is deducted from your next payout"
    refund_payout_deduction = round(customer_refund_gross - retained_platform_fees, 2)
    assert refund_payout_deduction == 118.40, f"Refund payout deduction mismatch: expected 118.40, got {refund_payout_deduction}"
    
    # Step F: Net Payout Balance (Pre-Disbursement Payout Pool)
    # Timeline: Refunds occur within the 13-day holding cycle prior to semi-monthly payout calculation
    net_payout_balance = round(gross_sales - total_initial_mor_fees - refund_payout_deduction, 2)
    assert net_payout_balance == 5753.14, f"Net payout balance mismatch: expected 5753.14, got {net_payout_balance}"
    
    # Step G: Bank Payout Disbursement Fee (1.0% of Net Payout Balance)
    # Lemon Squeezy assesses 1.0% on the actual balance disbursed via international bank transfer
    payout_disbursement_fee = round(net_payout_balance * MOR_PAYOUT_FEE_RATE, 2)
    assert payout_disbursement_fee == 57.53, f"Payout fee mismatch: expected 57.53, got {payout_disbursement_fee}"
    
    # Step H: Fixed Infrastructure Overhead
    total_infra_cost = round(INFRA_SUPABASE_PRO_USD + INFRA_VERCEL_PRO_USD + INFRA_CLOUD_VPS_USD + INFRA_STORAGE_EGRESS_USD, 2)
    assert total_infra_cost == 51.00, f"Infra overhead mismatch: expected 51.00, got {total_infra_cost}"
    
    # =========================================================================
    # 3. FINAL ESTIMATED OPERATING CONTRIBUTION (EOC) & ASSERTIONS
    # =========================================================================
    # EOC = Net Payout Balance - Bank Payout Disbursement Fee - Fixed Infrastructure Overhead
    estimated_operating_contribution = round(net_payout_balance - payout_disbursement_fee - total_infra_cost, 2)
    assert estimated_operating_contribution == 5644.61, (
        f"EOC calculation mismatch: expected 5644.61, got {estimated_operating_contribution}"
    )
    
    contribution_margin_pct = round((estimated_operating_contribution / gross_sales) * 100, 2)
    assert contribution_margin_pct == 86.91, (
        f"Contribution margin mismatch: expected 86.91%, got {contribution_margin_pct}%"
    )
    
    # Verification of Total Realized Deductions (for reconciling with gross revenue):
    total_realized_deductions = round(gross_sales - estimated_operating_contribution, 2)
    assert total_realized_deductions == 850.39, (
        f"Total realized deductions mismatch: expected 850.39, got {total_realized_deductions}"
    )
    # Check that deductions equal: Initial MoR Fees ($623.46) + Net Refund Adjustment ($118.40) + Payout Fee ($57.53) + Infra ($51.00) = $850.39
    assert total_realized_deductions == round(total_initial_mor_fees + refund_payout_deduction + payout_disbursement_fee + total_infra_cost, 2)
    
    # Print formatted audit trail
    print("="*80)
    print("JCCF SUBSYSTEM M13 - RECONCILED EOC FINANCIAL AUDIT VERIFICATION")
    print("="*80)
    print(f"Top-Line Gross Sales (500 units @ $12.99):                +${gross_sales:8.2f}  [VERIFIED: Scenario Input]")
    print(f"MoR Base Variable Fee (5.0% of Gross):                    -${mor_base_fee:8.2f}  [VERIFIED: 5.0% on 500 units]")
    print(f"MoR Fixed Transaction Fee ($0.50/unit):                   -${mor_fixed_fee:8.2f}  [VERIFIED: $0.50 on 500 units]")
    print(f"MoR International Surcharge (1.5% on 50% non-US mix):     -${mor_intl_surcharge:8.2f}  [ASSUMPTION: 50% non-US]")
    print(f"--------------------------------------------------------------------------------")
    print(f"Total Initial Platform Fees (All 500 Orders):             -${total_initial_mor_fees:8.2f}  [ACCOUNTED UPFRONT]")
    print(f"Refund Payout Adjustment (Gross $129.90 - Retained $11.50):-${refund_payout_deduction:8.2f}  [POLICY-ACCURATE: Net deduction]")
    print(f"  * Note: Retained fees ($11.50) are NOT double-counted; already in initial fees.")
    print(f"  * Assumption: 10 refunded units modeled under base US rate (conservative for payout).")
    print(f"--------------------------------------------------------------------------------")
    print(f"Net Payout Balance (Pre-Disbursement Payout Pool):        +${net_payout_balance:8.2f}  [DISBURSED POOL]")
    print(f"MoR International Bank Payout Fee (1.0% of Net Payout):   -${payout_disbursement_fee:8.2f}  [VERIFIED: 1.0% on actual payout]")
    print(f"Fixed Infrastructure Overhead (Supabase, Vercel, VPS):    -${total_infra_cost:8.2f}  [ASSUMPTION: Scaled Pro Tier]")
    print(f"================================================================================")
    print(f"Total Realized Deductions:                                -${total_realized_deductions:8.2f}")
    print(f"ESTIMATED OPERATING CONTRIBUTION (EOC):                   +${estimated_operating_contribution:8.2f}  [ASSERTION PASSED]")
    print(f"CONTRIBUTION MARGIN PERCENTAGE:                              {contribution_margin_pct:6.2f}%  [ASSERTION PASSED]")
    print("="*80)
    print("AUDIT STATUS: ALL 16 INDEPENDENT ASSERTIONS PASSED (100% MATHEMATICAL INTEGRITY)")
    print("="*80)

if __name__ == "__main__":
    test_reproducible_eoc_model()
