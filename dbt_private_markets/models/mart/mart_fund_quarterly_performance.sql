/*
Model: mart_fund_quarterly_performance

Purpose:
Create the final quarterly fund performance mart on top of the formal
fact and dimension tables.

Why this model exists:
The project originally produced a quarterly performance mart directly from the
intermediate layer.
That was useful as a first reporting draft, but it bypassed the dimensional
modeling step.

This rewritten mart now uses the proper warehouse backbone:
1. fact_nav for quarter end valuation snapshots
2. fact_cashflows for cumulative paid in and distributions
3. dim_fund for descriptive fund attributes
4. dim_date for conformed calendar attributes

Business use:
This is the final reporting layer for:
1. fund scorecards
2. DPI, RVPI, and TVPI reporting
3. break even analysis
4. J curve companion visuals
5. Power BI semantic and visual consumption

Grain:
1 row = 1 fund + 1 valuation snapshot date

Design choice:
This model intentionally stays in the mart folder and therefore uses the
project default materialization for mart models.
In your current dbt_project.yml, that means a SQL Server view unless you later
choose to override it.

Important financial note:
The core performance ratios in this mart are calculated from the CHF reporting
measures, not the native currency measures.
That matches the project's Switzerland oriented reporting framework and the
existing validation logic used earlier in the project.
*/

WITH fact_nav AS (

    /*
    Quarter end fund valuation snapshots.
    This is the anchor grain of the mart.
    */
    SELECT *
    FROM {{ ref('fact_nav') }}

),

fact_cashflows AS (

    /*
    Fund cashflow fact table containing both signed values and helper fields
    such as paid in and distribution amounts.
    */
    SELECT *
    FROM {{ ref('fact_cashflows') }}

),

dim_fund AS (

    /*
    Conformed fund dimension.
    */
    SELECT *
    FROM {{ ref('dim_fund') }}

),

dim_date AS (

    /*
    Conformed date dimension.
    */
    SELECT *
    FROM {{ ref('dim_date') }}

),

cashflow_rollup_by_snapshot AS (

    /*
    Purpose:
    For each quarter end NAV snapshot, accumulate all fund cashflows that took
    place on or before that valuation date.

    Why this approach is correct:
    NAV is a stock measure observed at quarter end.
    Paid in capital and distributions are flow measures that must be summed
    through time up to that quarter end date.
    */
    SELECT
        nav.nav_id,

        /*
        Native currency cumulative measures.
        */
        COALESCE(SUM(cashflow.paid_in_amount), 0) AS cumulative_paid_in,
        COALESCE(SUM(cashflow.distribution_amount), 0) AS cumulative_distributions,
        COALESCE(SUM(cashflow.signed_amount), 0) AS cumulative_net_cashflow,

        /*
        CHF reporting cumulative measures.
        */
        COALESCE(SUM(cashflow.paid_in_amount_chf), 0) AS cumulative_paid_in_chf,
        COALESCE(SUM(cashflow.distribution_amount_chf), 0) AS cumulative_distributions_chf,
        COALESCE(SUM(cashflow.signed_amount_chf), 0) AS cumulative_net_cashflow_chf

    FROM fact_nav AS nav

    LEFT JOIN fact_cashflows AS cashflow
        ON nav.fund_id = cashflow.fund_id
       AND cashflow.date_id <= nav.date_id

    GROUP BY
        nav.nav_id

),

assembled AS (

    /*
    Purpose:
    Join the quarter end NAV snapshots with the cumulative cashflow rollups,
    fund descriptors, and conformed date attributes.
    */
    SELECT

        /*
        Snapshot identifiers.
        */
        nav.nav_id,
        nav.fund_id,
        nav.date_id AS valuation_date_key,
        nav.valuation_date,
        nav.quarter_end,
        nav.quarter_sequence,

        /*
        Conformed date descriptors for quarter end reporting.
        */
        date_dimension.calendar_year,
        date_dimension.quarter_label,
        date_dimension.quarter_number,
        date_dimension.year_quarter,
        date_dimension.year_month,
        date_dimension.month_number,
        date_dimension.month_name,

        /*
        Fund descriptors.
        */
        fund.fund_code,
        fund.fund_name,
        fund.vintage_year,
        fund.strategy,
        fund.sub_strategy,
        fund.geography,
        fund.sector_focus,
        fund.manager,
        fund.domicile,
        fund.fund_status,
        fund.base_currency,
        fund.reporting_currency,
        fund.fund_size,
        fund.fund_size_chf_final_close,
        fund.first_close_date,
        fund.final_close_date,
        fund.investment_period_years,
        fund.fund_life_years,

        /*
        Native currency quarter end stock measures.
        */
        nav.currency,
        nav.nav_amount,
        nav.unfunded_commitment,

        /*
        Native currency cumulative flow measures.
        */
        rollup.cumulative_paid_in,
        rollup.cumulative_distributions,
        rollup.cumulative_net_cashflow,

        /*
        Native currency combined value measures.
        */
        nav.nav_amount + rollup.cumulative_distributions AS total_value,
        (nav.nav_amount + rollup.cumulative_distributions) - rollup.cumulative_paid_in AS value_creation,

        /*
        CHF reporting stock measures.
        */
        nav.fx_rate_to_chf,
        nav.nav_amount_chf,
        nav.unfunded_commitment_chf,

        /*
        CHF reporting cumulative flow measures.
        */
        rollup.cumulative_paid_in_chf,
        rollup.cumulative_distributions_chf,
        rollup.cumulative_net_cashflow_chf,

        /*
        CHF reporting combined value measures.
        */
        nav.nav_amount_chf + rollup.cumulative_distributions_chf AS total_value_chf,
        (nav.nav_amount_chf + rollup.cumulative_distributions_chf) - rollup.cumulative_paid_in_chf AS value_creation_chf,

        /*
        Percentage helper measures.
        */
        CASE
            WHEN fund.fund_size = 0 THEN NULL
            ELSE CAST(rollup.cumulative_paid_in AS decimal(38,10)) / NULLIF(CAST(fund.fund_size AS decimal(38,10)), 0)
        END AS paid_in_pct_of_fund_size,

        CASE
            WHEN fund.fund_size_chf_final_close = 0 THEN NULL
            ELSE CAST(rollup.cumulative_paid_in_chf AS decimal(38,10)) / NULLIF(CAST(fund.fund_size_chf_final_close AS decimal(38,10)), 0)
        END AS paid_in_pct_of_fund_size_chf,

        CASE
            WHEN fund.fund_size = 0 THEN NULL
            ELSE CAST(nav.nav_amount AS decimal(38,10)) / NULLIF(CAST(fund.fund_size AS decimal(38,10)), 0)
        END AS nav_pct_of_fund_size,

        CASE
            WHEN fund.fund_size_chf_final_close = 0 THEN NULL
            ELSE CAST(nav.nav_amount_chf AS decimal(38,10)) / NULLIF(CAST(fund.fund_size_chf_final_close AS decimal(38,10)), 0)
        END AS nav_pct_of_fund_size_chf,

        CASE
            WHEN fund.fund_size = 0 THEN NULL
            ELSE CAST(nav.unfunded_commitment AS decimal(38,10)) / NULLIF(CAST(fund.fund_size AS decimal(38,10)), 0)
        END AS unfunded_pct_of_fund_size,

        CASE
            WHEN fund.fund_size_chf_final_close = 0 THEN NULL
            ELSE CAST(nav.unfunded_commitment_chf AS decimal(38,10)) / NULLIF(CAST(fund.fund_size_chf_final_close AS decimal(38,10)), 0)
        END AS unfunded_pct_of_fund_size_chf,

        CASE
            WHEN fund.fund_size = 0 THEN NULL
            ELSE CAST(nav.nav_amount + rollup.cumulative_distributions AS decimal(38,10)) / NULLIF(CAST(fund.fund_size AS decimal(38,10)), 0)
        END AS total_value_pct_of_fund_size,

        CASE
            WHEN fund.fund_size_chf_final_close = 0 THEN NULL
            ELSE CAST(nav.nav_amount_chf + rollup.cumulative_distributions_chf AS decimal(38,10)) / NULLIF(CAST(fund.fund_size_chf_final_close AS decimal(38,10)), 0)
        END AS total_value_pct_of_fund_size_chf,


        /*
        Core private markets multiples.
        These are deliberately based on the CHF reporting layer.
        */
        CASE
            WHEN rollup.cumulative_paid_in_chf = 0 THEN NULL
            ELSE CAST(rollup.cumulative_distributions_chf AS decimal(38,10))
                 / NULLIF(CAST(rollup.cumulative_paid_in_chf AS decimal(38,10)), 0)
        END AS dpi,

        CASE
            WHEN rollup.cumulative_paid_in_chf = 0 THEN NULL
            ELSE CAST(nav.nav_amount_chf AS decimal(38,10))
                 / NULLIF(CAST(rollup.cumulative_paid_in_chf AS decimal(38,10)), 0)
        END AS rvpi,

        CASE
            WHEN rollup.cumulative_paid_in_chf = 0 THEN NULL
            ELSE CAST(nav.nav_amount_chf + rollup.cumulative_distributions_chf AS decimal(38,10))
                 / NULLIF(CAST(rollup.cumulative_paid_in_chf AS decimal(38,10)), 0)
        END AS tvpi,

        /*
        Break even helper.
        A fund is marked as having broken even once total value is at least as
        large as cumulative paid in capital in CHF terms.
        */
        CASE
            WHEN rollup.cumulative_paid_in_chf > 0
             AND nav.nav_amount_chf + rollup.cumulative_distributions_chf >= rollup.cumulative_paid_in_chf
                THEN 1
            ELSE 0
        END AS break_even_flag,

        /*
        Metadata.
        */
        nav.valuation_status

    FROM fact_nav AS nav

    LEFT JOIN cashflow_rollup_by_snapshot AS rollup
        ON nav.nav_id = rollup.nav_id

    LEFT JOIN dim_fund AS fund
        ON nav.fund_id = fund.fund_id

    LEFT JOIN dim_date AS date_dimension
        ON nav.date_id = date_dimension.date_id

)

SELECT
    nav_id,
    fund_id,
    valuation_date_key,
    valuation_date,
    quarter_end,
    quarter_sequence,
    calendar_year,
    quarter_label,
    quarter_number,
    year_quarter,
    year_month,
    month_number,
    month_name,
    fund_code,
    fund_name,
    vintage_year,
    strategy,
    sub_strategy,
    geography,
    sector_focus,
    manager,
    domicile,
    fund_status,
    base_currency,
    reporting_currency,
    fund_size,
    fund_size_chf_final_close,
    first_close_date,
    final_close_date,
    investment_period_years,
    fund_life_years,
    currency,
    nav_amount,
    unfunded_commitment,
    cumulative_paid_in,
    cumulative_distributions,
    cumulative_net_cashflow,
    total_value,
    value_creation,
    fx_rate_to_chf,
    nav_amount_chf,
    unfunded_commitment_chf,
    cumulative_paid_in_chf,
    cumulative_distributions_chf,
    cumulative_net_cashflow_chf,
    total_value_chf,
    value_creation_chf,
    paid_in_pct_of_fund_size,
    paid_in_pct_of_fund_size_chf,
    nav_pct_of_fund_size,
    nav_pct_of_fund_size_chf,
    unfunded_pct_of_fund_size,
    unfunded_pct_of_fund_size_chf,
    total_value_pct_of_fund_size,
    total_value_pct_of_fund_size_chf,
    dpi,
    rvpi,
    tvpi,
    break_even_flag,
    valuation_status
FROM assembled;
