{{ config(
    materialized = 'table',
    schema = 'mart'
) }}

/*
Model: fact_nav

Purpose:
Create the quarterly NAV snapshot fact table.

Why this model exists:
This is the stock measure fact table of the warehouse.
It captures quarter end NAV and unfunded commitment at each valuation date.

Grain:
1 row = 1 fund + 1 valuation snapshot date

Source:
staging.stg_nav

Primary key:
nav_id

Foreign keys:
fund_id -> dim_fund.fund_id
date_id -> dim_date.date_id
*/

SELECT

    /*
    Primary key.
    */
    nav_id,

    /*
    Foreign keys.
    */
    fund_id,
    valuation_date_key AS date_id,

    /*
    Snapshot date.
    */
    valuation_date,

    /*
    Period labeling.
    */
    quarter_end,
    quarter_sequence,

    /*
    Valuation economics in native currency.
    */
    nav_amount,
    unfunded_commitment,
    currency,

    /*
    CHF reporting values.
    */
    fx_rate_to_chf,
    nav_amount_chf,
    unfunded_commitment_chf,

    /*
    Metadata.
    */
    valuation_status

FROM {{ ref('stg_nav') }}
