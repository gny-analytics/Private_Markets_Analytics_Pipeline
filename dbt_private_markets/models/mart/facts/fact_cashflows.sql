{{ config(
    materialized = 'table',
    schema = 'mart'
) }}

/*
Model: fact_cashflows

Purpose:
Create the fund cashflow fact table.

Why this model exists:
This is the core transaction fact of the warehouse.
It supports J curve analysis, cumulative paid in, cumulative distributions,
and IRR preparation.

Grain:
1 row = 1 fund cashflow event

Source:
staging.stg_cashflows

Primary key:
cashflow_id

Foreign keys:
fund_id        -> dim_fund.fund_id
date_id        -> dim_date.date_id
notice_date_id -> dim_date.date_id
due_date_id    -> dim_date.date_id
*/

SELECT

    /*
    Primary key.
    */
    cashflow_id,

    /*
    Alternate reference.
    */
    cashflow_ref,

    /*
    Foreign keys.
    */
    fund_id,
    cashflow_date_key AS date_id,
    notice_date_key AS notice_date_id,
    due_date_key AS due_date_id,

    /*
    Optional degenerate asset references.
    You can later normalize these into dim_asset if you want a richer galaxy
    schema.
    */
    asset_id,
    asset_code,

    /*
    Event dates.
    */
    cashflow_date,
    notice_date,
    due_date,

    /*
    Classification.
    */
    cashflow_type,
    cashflow_category,

    /*
    Native currency and CHF economics.
    */
    amount,
    currency,
    fx_rate_to_chf,
    amount_chf,

    /*
    Analytical helper fields.
    Negative source amounts are recast into positive paid in.
    Positive source amounts are distributions.
    */
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

    /*
    Keep original signed fields too.
    */
    amount AS signed_amount,
    amount_chf AS signed_amount_chf,

    /*
    Metadata.
    */
    quarter,
    status,
    batch_id

FROM {{ ref('stg_cashflows') }}
