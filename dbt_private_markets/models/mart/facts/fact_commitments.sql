{{ config(
    materialized = 'table',
    schema = 'mart'
) }}

/*
Model: fact_commitments

Purpose:
Create the commitment fact table at investor commitment event grain.

Why this model exists:
This is the bridge between LPs and funds.
It supports fundraising analysis, investor concentration analysis, and later
commitment pacing work.

Grain:
1 row = 1 investor commitment event into 1 fund

Source:
raw.commitments_v7

Primary key:
commitment_id

Foreign keys:
fund_id      -> dim_fund.fund_id
investor_id  -> dim_investor.investor_id
date_id      -> dim_date.date_id
*/

SELECT

    /*
    Primary key.
    */
    CommitmentID AS commitment_id,

    /*
    Alternate reference.
    */
    CommitmentRef AS commitment_ref,

    /*
    Foreign keys.
    */
    FundID AS fund_id,
    InvestorID AS investor_id,
    CommitmentDateKey AS date_id,

    /*
    Event date rebuilt from the authoritative date key.
    */
    TRY_CONVERT(date, CONVERT(char(8), CommitmentDateKey), 112) AS commitment_date,

    /*
    Commitment economics.
    */
    CommitmentAmount AS commitment_amount,
    CommitmentCurrency AS commitment_currency,
    FXRateToCHF AS fx_rate_to_chf,
    CommitmentAmountCHF AS commitment_amount_chf,
    CommitmentPctOfFund AS commitment_pct_of_fund,

    /*
    Event descriptors.
    */
    ClosingRound AS closing_round,
    CommitmentStatus AS commitment_status,

    /*
    Investor rights and commercial terms.
    */
    SideLetterFlag AS side_letter_flag,
    MostFavoredNationFlag AS most_favored_nation_flag,
    CoInvestmentRightsFlag AS co_investment_rights_flag,
    FeeTermsBucket AS fee_terms_bucket,

    /*
    Metadata.
    */
    RecordSource AS record_source

FROM raw.commitments_v7
