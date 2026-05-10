{{ config(
    materialized = 'table',
    schema = 'mart'
) }}

/*
Model: dim_investor

Purpose:
Create the conformed investor dimension.

Why this model exists:
Commitments and investor cashflow allocations need a clean investor lookup
table with one row per investor.

Grain:
1 row = 1 investor

Source:
raw.investors_v7

Primary key:
investor_id
*/

SELECT

    /*
    Primary key.
    */
    InvestorID AS investor_id,

    /*
    Alternate identifier.
    */
    InvestorCode AS investor_code,

    /*
    Descriptive attributes.
    */
    InvestorName AS investor_name,
    InvestorType AS investor_type,
    InvestorChannel AS investor_channel,
    Region AS region,
    Country AS country,
    BaseCurrency AS base_currency,
    CommitmentBucket AS commitment_bucket,
    RelationshipStartYear AS relationship_start_year,
    OnboardingOffice AS onboarding_office,
    ESGPreference AS esg_preference,
    TaxStatus AS tax_status,
    InvestorStatus AS investor_status

FROM raw.investors_v7
