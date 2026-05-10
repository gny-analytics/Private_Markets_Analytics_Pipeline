/*
Model: mart_fund_quarterly_performance

Purpose:
Create the first reporting mart that combines cumulative fund cashflows and
NAV snapshots into standard private markets performance ratios.

Why this model exists:
This is the first real reporting mart for the project.
It turns intermediate snapshot inputs into the canonical quarter end
performance view that Power BI can use directly.

Business use:
1. DPI trend
2. RVPI trend
3. TVPI trend
4. quarter end NAV tracking
5. break even analysis
6. latest fund scorecard views

Grain:
1 row = 1 fund + 1 quarter end valuation snapshot

Source:
intermediate.int_fund_performance_snapshots

Important financial note:
The ratio fields in this mart use CHF reporting values by default.
That is consistent with the wider Geneva CHF reporting logic already locked in
for this dataset.
*/

SELECT

    /*
    Snapshot identifiers.
    */
    nav_id,
    fund_id,
    fund_code,
    valuation_date_key,
    valuation_date,
    quarter_end,
    quarter_sequence,

    /*
    Fund descriptors.
    */
    fund_name,
    vintage_year,
    strategy,
    sub_strategy,
    geography,
    manager,
    fund_status,

    /*
    Native currency reference fields.
    */
    currency,
    fund_size,
    nav_amount,
    unfunded_commitment,
    cumulative_paid_in,
    cumulative_distributions,
    cumulative_net_cashflow,

    /*
    CHF reporting fields.
    */
    fund_size_chf_final_close,
    fx_rate_to_chf,
    nav_amount_chf,
    unfunded_commitment_chf,
    cumulative_paid_in_chf,
    cumulative_distributions_chf,
    cumulative_net_cashflow_chf,

    /*
    Core total value field in CHF.
    */
    nav_amount_chf + cumulative_distributions_chf AS total_value_chf,

    /*
    Standard private markets multiples in CHF.

    Definitions used:
    DPI  = cumulative distributions divided by cumulative paid in
    RVPI = residual value divided by cumulative paid in
    TVPI = total value divided by cumulative paid in

    Guardrail:
    Return NULL when cumulative paid in is zero to avoid invalid ratios.
    */
    CASE
        WHEN cumulative_paid_in_chf = 0 THEN NULL
        ELSE cumulative_distributions_chf / cumulative_paid_in_chf
    END AS dpi,

    CASE
        WHEN cumulative_paid_in_chf = 0 THEN NULL
        ELSE nav_amount_chf / cumulative_paid_in_chf
    END AS rvpi,

    CASE
        WHEN cumulative_paid_in_chf = 0 THEN NULL
        ELSE (nav_amount_chf + cumulative_distributions_chf) / cumulative_paid_in_chf
    END AS tvpi,

    /*
    Helpful operational and storytelling metrics.
    */
    CASE
        WHEN cumulative_paid_in_chf = 0 THEN NULL
        ELSE nav_amount_chf + cumulative_distributions_chf - cumulative_paid_in_chf
    END AS value_creation_chf,

    CASE
        WHEN nav_amount_chf + cumulative_distributions_chf >= cumulative_paid_in_chf
             AND cumulative_paid_in_chf > 0
        THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS break_even_flag,

    CASE
        WHEN fund_size_chf_final_close = 0 THEN NULL
        ELSE cumulative_paid_in_chf / fund_size_chf_final_close
    END AS paid_in_pct_of_fund_size_chf,

    CASE
        WHEN fund_size_chf_final_close = 0 THEN NULL
        ELSE nav_amount_chf / fund_size_chf_final_close
    END AS nav_pct_of_fund_size_chf,

    valuation_status

FROM {{ ref('int_fund_performance_snapshots') }}
