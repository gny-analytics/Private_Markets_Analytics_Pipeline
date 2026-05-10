{{ config(
    materialized = 'table',
    schema = 'mart'
) }}

/*
Model: dim_fund

Purpose:
Create the conformed fund dimension for the private markets warehouse.

Why this model exists:
The raw and staging layers preserve source structure.
This dimension turns fund master data into a stable descriptive table that can
be joined to multiple fact tables.

Grain:
1 row = 1 fund

Source:
staging.stg_funds

Primary key:
fund_id
*/

SELECT

    /*
    Primary key.
    */
    fund_id,

    /*
    Alternate identifiers and descriptors.
    */
    fund_code,
    fund_name,

    /*
    Core fund attributes.
    */
    vintage_year,
    strategy,
    sub_strategy,
    geography,
    sector_focus,

    /*
    Currency and size information.
    */
    base_currency,
    reporting_currency,
    fund_size,
    fund_size_fx_date,
    fund_size_fx_rate_to_chf,
    fund_size_chf_final_close,

    /*
    Lifecycle dates.
    */
    first_close_date,
    final_close_date,
    investment_period_years,
    fund_life_years,

    /*
    Economics.
    */
    mgmt_fee_rate_ip,
    mgmt_fee_rate_post_ip,
    carry_rate,
    preferred_return_rate,

    /*
    Additional descriptors.
    */
    commitment_style,
    manager,
    domicile,
    status AS fund_status,
    esg_article

FROM {{ ref('stg_funds') }}
