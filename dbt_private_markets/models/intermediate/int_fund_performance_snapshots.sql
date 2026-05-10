/*
Model: int_fund_performance_snapshots

Purpose:
Create one clean quarterly performance input row per fund valuation snapshot.

Why this model exists:
The project already has a daily cumulative cashflow model for J curve work.
That model is excellent for time series cashflow analysis, but it is not the
best grain for combining with NAV because NAV is a quarter end stock measure.

So this model uses the valuation snapshot dates from the NAV layer as the
anchor grain and calculates cumulative capital activity up to each valuation
snapshot.

Business use:
This model is the direct input layer for:
1. DPI
2. RVPI
3. TVPI
4. break even analysis
5. later IRR preparation

Grain:
1 row = 1 fund + 1 valuation snapshot date

Sources:
1. staging.stg_nav
2. staging.stg_cashflows
3. staging.stg_funds

Important modeling note:
We calculate cumulative paid in and cumulative distributions directly from the
transaction source up to each valuation date.
This avoids forcing a join between daily transaction grain and quarter end
stock grain.

Important financial note:
This model keeps both native currency values and CHF reporting values.
The final mart can choose the CHF fields as the canonical reporting layer.
*/

WITH nav AS (

    /*
    Clean valuation snapshots.
    */
    SELECT *
    FROM {{ ref('stg_nav') }}

),

funds AS (

    /*
    Clean fund master data.
    */
    SELECT *
    FROM {{ ref('stg_funds') }}

),

cashflows AS (

    /*
    Recast raw signed cashflows into the two cumulative buckets needed for
    private markets performance analytics.

    Convention used here:
    1. Negative cashflows are treated as paid in capital
    2. Positive cashflows are treated as distributions

    This follows the source economics already confirmed earlier in the project.
    */
    SELECT
        fund_id,
        cashflow_date,
        amount,
        amount_chf,

        CASE
            WHEN amount < 0 THEN -amount
            ELSE 0
        END AS paid_in_amount,

        CASE
            WHEN amount > 0 THEN amount
            ELSE 0
        END AS distribution_amount,

        CASE
            WHEN amount_chf < 0 THEN -amount_chf
            ELSE 0
        END AS paid_in_amount_chf,

        CASE
            WHEN amount_chf > 0 THEN amount_chf
            ELSE 0
        END AS distribution_amount_chf,

        amount AS signed_amount,
        amount_chf AS signed_amount_chf

    FROM {{ ref('stg_cashflows') }}

),

snapshot_rollup AS (

    /*
    For each NAV snapshot, accumulate all historical cashflows up to and
    including that valuation date.

    Because the dataset is small and idealized, this direct rollup approach is
    clear and robust.
    */
    SELECT
        n.nav_id,
        n.fund_id,
        n.fund_code,
        n.valuation_date_key,
        n.valuation_date,
        n.quarter_end,
        n.quarter_sequence,
        n.currency,
        n.nav_amount,
        n.nav_amount_chf,
        n.unfunded_commitment,
        n.unfunded_commitment_chf,
        n.fx_rate_to_chf,
        n.valuation_status,

        f.fund_name,
        f.vintage_year,
        f.strategy,
        f.sub_strategy,
        f.geography,
        f.manager,
        f.status AS fund_status,
        f.fund_size,
        f.fund_size_chf_final_close,

        COALESCE(SUM(cf.paid_in_amount), 0) AS cumulative_paid_in,
        COALESCE(SUM(cf.distribution_amount), 0) AS cumulative_distributions,
        COALESCE(SUM(cf.signed_amount), 0) AS cumulative_net_cashflow,

        COALESCE(SUM(cf.paid_in_amount_chf), 0) AS cumulative_paid_in_chf,
        COALESCE(SUM(cf.distribution_amount_chf), 0) AS cumulative_distributions_chf,
        COALESCE(SUM(cf.signed_amount_chf), 0) AS cumulative_net_cashflow_chf

    FROM nav AS n

    LEFT JOIN cashflows AS cf
        ON n.fund_id = cf.fund_id
       AND cf.cashflow_date <= n.valuation_date

    LEFT JOIN funds AS f
        ON n.fund_id = f.fund_id

    GROUP BY
        n.nav_id,
        n.fund_id,
        n.fund_code,
        n.valuation_date_key,
        n.valuation_date,
        n.quarter_end,
        n.quarter_sequence,
        n.currency,
        n.nav_amount,
        n.nav_amount_chf,
        n.unfunded_commitment,
        n.unfunded_commitment_chf,
        n.fx_rate_to_chf,
        n.valuation_status,
        f.fund_name,
        f.vintage_year,
        f.strategy,
        f.sub_strategy,
        f.geography,
        f.manager,
        f.status,
        f.fund_size,
        f.fund_size_chf_final_close

)

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
    Native currency valuation and cumulative movement measures.
    */
    currency,
    fund_size,
    nav_amount,
    unfunded_commitment,
    cumulative_paid_in,
    cumulative_distributions,
    cumulative_net_cashflow,

    /*
    CHF reporting measures.
    */
    fund_size_chf_final_close,
    fx_rate_to_chf,
    nav_amount_chf,
    unfunded_commitment_chf,
    cumulative_paid_in_chf,
    cumulative_distributions_chf,
    cumulative_net_cashflow_chf,

    /*
    Metadata.
    */
    valuation_status

FROM snapshot_rollup
