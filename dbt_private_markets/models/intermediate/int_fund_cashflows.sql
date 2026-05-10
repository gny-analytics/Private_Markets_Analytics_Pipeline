/*
Model: int_fund_cashflows

Purpose:
Combine staged cashflows with staged fund attributes
to produce a clean transaction-level analytical layer.

Why this model exists:
The staging layer standardizes each source table independently.
This intermediate layer starts to apply business logic across tables.

Business use:
This model is the foundation for:
1. cumulative net cashflows
2. J-curve analysis
3. later performance models

Grain:
1 row = 1 fund cashflow event

Sources:
- staging.stg_cashflows
- staging.stg_funds

Important design note:
This model uses ref() so dbt can:
1. understand dependencies
2. build in the correct order
3. resolve object names safely

Important financial note:
The raw dataset already appears to store calls as negative amounts.
So this model should preserve that economic direction instead of flipping it again.
*/

WITH cashflows AS (

    /*
    Pull cleaned cashflow transactions from the staging layer.
    */
    SELECT *
    FROM {{ ref('stg_cashflows') }}

),

funds AS (

    /*
    Pull cleaned fund master data from the staging layer.
    */
    SELECT *
    FROM {{ ref('stg_funds') }}

)

SELECT

    /*
    Transaction identifier.
    */
    cf.cashflow_id,

    /*
    Fund identifier.
    */
    cf.fund_id,

    /*
    Fund descriptive attributes added from the fund master.
    */
    f.fund_name,
    f.vintage_year,

    /*
    Core economic date of the transaction.
    */
    cf.cashflow_date,

    /*
    Business classification of the cashflow.
    */
    cf.cashflow_type,

    /*
    Signed amount used for cumulative cashflow analysis.

    Important:
    We preserve the economic sign already present in the source.

    Why:
    The raw source appears to already represent:
    - calls as negative
    - distributions as positive

    So the cleanest approach is to keep the amount as-is.
    */
    cf.amount AS signed_amount

FROM cashflows AS cf

/*
Join fund descriptors onto each cashflow.
*/
LEFT JOIN funds AS f
    ON cf.fund_id = f.fund_id
