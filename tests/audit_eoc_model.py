import math

gross_sales = 6495.00 # 500 units @ $12.99
units = 500
retail_price = 12.99

# 1. Base MoR Platform Fee: 5.0% of Gross
mor_base_fee = round(gross_sales * 0.05, 2) # 324.75

# 2. Fixed Transaction Fee: $0.50 per unit
mor_fixed_fee = round(units * 0.50, 2) # 250.00

# 3. Buyer-Country Mix & International Surcharge:
# Assumption: 50% US buyers (0.0% surcharge), 50% non-US international buyers (+1.5% surcharge)
intl_volume = gross_sales * 0.50 # $3,247.50
mor_intl_surcharge = round(intl_volume * 0.015, 2) # $48.71

# Net sales settling into merchant balance prior to bank payout
net_sales_settled = gross_sales - mor_base_fee - mor_fixed_fee - mor_intl_surcharge # $5,871.54

# 4. Payout Disbursement Fee:
# Lemon Squeezy official fee: 1.0% on international bank transfers (outside US)
# Calculated on the net disbursed balance ($5,871.54 * 0.01 = $58.7154 -> $58.72)
# If using conservative truncation or rounded schedule: $58.70 to $58.72
payout_disbursement_fee = round(net_sales_settled * 0.01, 2) # $58.72

# 5. Infrastructure Fixed Costs (Scaled 500 Orders/Mo):
infra_supabase = 25.00  # Pro DB & Storage tier past 500MB
infra_vercel = 20.00    # Next.js Team / Pro hosting
infra_vps = 5.00        # Fly.io / Hetzner 24/7 worker
infra_storage = 1.00    # CDN cached asset egress
total_infra = infra_supabase + infra_vercel + infra_vps + infra_storage # $51.00

# 6. Refund Buffer & Retained Gateway Fees:
# Assumption: 2.0% refund rate (10 units refunded)
refund_reserve = round(10 * retail_price, 2) # $129.90
# Lemon Squeezy retains original processing fees on refunded transactions:
# 10 orders * ($12.99 * 5% + $0.50) = 10 * ($0.65 + $0.50) = $11.50
retained_gateway_fees = 11.50
total_refund_cost = refund_reserve + retained_gateway_fees # $141.40

# Total Deductions & EOC
total_deductions_exact = mor_base_fee + mor_fixed_fee + mor_intl_surcharge + payout_disbursement_fee + total_infra + total_refund_cost
eoc_exact = round(gross_sales - total_deductions_exact, 2)

total_deductions_5870 = mor_base_fee + mor_fixed_fee + mor_intl_surcharge + 58.70 + total_infra + total_refund_cost
eoc_5870 = round(gross_sales - total_deductions_5870, 2)

print("="*75)
print("REPRODUCIBLE EOC FINANCIAL MODEL AUDIT (500 UNITS/MO)")
print("="*75)
print(f"Gross Top-Line Sales (500 @ $12.99):           +${gross_sales:8.2f}")
print(f"MoR Base Variable Fee (5.0%):                  -${mor_base_fee:8.2f}")
print(f"MoR Fixed Transaction Fee ($0.50/unit):        -${mor_fixed_fee:8.2f}")
print(f"MoR International Non-US Surcharge (+1.5%):    -${mor_intl_surcharge:8.2f} (50% intl mix: $3,247.50 * 1.5%)")
print(f"Net Settled Merchant Balance:                  +${net_sales_settled:8.2f}")
print(f"MoR Bank Payout Fee (1.0% of Net Settled):     -${payout_disbursement_fee:8.2f} ($58.72 exact vs $58.70 rounded)")
print(f"Fixed Infrastructure (Supabase, Vercel, VPS):  -${total_infra:8.2f}")
print(f"Refund Allowance (2.0% rate, 10 units):        -${refund_reserve:8.2f}")
print(f"Non-Refundable Gateway Fees Retained on 10 ref: -${retained_gateway_fees:8.2f}")
print("-" * 75)
print(f"Calculated EOC with Exact Payout Fee ($58.72):   +${eoc_exact:8.2f} (Margin: {eoc_exact/gross_sales*100:.2f}%)")
print(f"Calculated EOC with Rounded Payout Fee ($58.70): +${eoc_5870:8.2f} (Margin: {eoc_5870/gross_sales*100:.2f}%)")
print("="*75)
