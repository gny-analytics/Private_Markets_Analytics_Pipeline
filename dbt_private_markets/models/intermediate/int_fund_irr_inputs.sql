/*
Model: int_fund_irr_inputs

Purpose:
Prepare the cashflow set required for later IRR or XIRR calculation at each
fund valuation snapshot.

Why this model exists:
IRR is different from DPI, RVPI, and TVPI.
Those multiples can be calculated directly from cumulative paid in,
distributions, and NAV.
IRR instead needs a dated cashflow stream plus a terminal NAV inserted as a
synthetic positive cashflow at the valuation date.

This model does not calculate IRR itself.
It prepares the exact dated rows that a later SQL routine or a Power BI XIRR
measure can consume.

Grain:
1 row = 1 IRR event row for 1 fund snapshot

Sources:
1. staging.stg_nav
2. staging.stg_cashflows
3. staging.stg_funds

Important note:
For each valuation snapshot, this model returns:
1. all actual historical cashflows up to that snapshot date
2. one synthetic terminal NAV row at that same snapshot date
*/

WITH nav AS (

    SELECT *
    FROM {{ ref('stg_nav') }}

),

funds AS (

    SELECT *
    FROM {{ ref('stg_funds') }}

),

actual_cashflows AS (

    SELECT
        n.nav_id,
        n.fund_id,
        n.valuation_date,
        n.quarter_sequence,
        f.fund_name,
        f.vintage_year,
        c.cashflow_date AS irr_event_date,
        c.amount_chf AS irr_cashflow_amount_chf,
        CAST('ACTUAL_CASHFLOW' AS nvarchar(30)) AS irr_row_type

    FROM nav AS n

    INNER JOIN {{ ref('stg_cashflows') }} AS c
        ON n.fund_id = c.fund_id
       AND c.cashflow_date <= n.valuation_date

    LEFT JOIN funds AS f
        ON n.fund_id = f.fund_id

),

terminal_nav AS (

    SELECT
        n.nav_id,
        n.fund_id,
        n.valuation_date,
        n.quarter_sequence,
        f.fund_name,
        f.vintage_year,
        n.valuation_date AS irr_event_date,
        n.nav_amount_chf AS irr_cashflow_amount_chf,
        CAST('TERMINAL_NAV' AS nvarchar(30)) AS irr_row_type

    FROM nav AS n

    LEFT JOIN funds AS f
        ON n.fund_id = f.fund_id

)

SELECT
    nav_id,
    fund_id,
    fund_name,
    vintage_year,
    valuation_date,
    quarter_sequence,
    irr_event_date,
    irr_cashflow_amount_chf,
    irr_row_type
FROM actual_cashflows

UNION ALL

SELECT
    nav_id,
    fund_id,
    fund_name,
    vintage_year,
    valuation_date,
    quarter_sequence,
    irr_event_date,
    irr_cashflow_amount_chf,
    irr_row_type
FROM terminal_nav
