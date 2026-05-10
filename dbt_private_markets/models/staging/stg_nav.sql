/*
Model: stg_nav

Purpose:
Clean and standardize raw fund NAV snapshots.

Key responsibilities:
1. Rename columns to snake_case
2. Convert valuation date keys into proper SQL dates
3. Preserve one row per raw NAV snapshot
4. Keep both native currency and CHF reporting amounts

Grain:
1 row = 1 fund + 1 valuation snapshot

Source:
raw.nav_v7

Design note:
This model is the clean valuation layer that will later be joined
with cumulative cashflow information at each snapshot date.
*/

SELECT

    /*
    Primary identifier for the raw NAV snapshot row.
    */
    NAVID                            AS nav_id,

    /*
    Fund identifiers.
    */
    FundID                           AS fund_id,
    FundCode                         AS fund_code,

    /*
    Raw valuation date key kept for lineage and debugging.
    */
    ValuationDateKey                 AS valuation_date_key,

    /*
    Proper SQL valuation date rebuilt from the date key.
    */
    TRY_CONVERT(date, CONVERT(char(8), ValuationDateKey), 112)
                                     AS valuation_date,

    /*
    Quarter labeling fields from the source.
    */
    QuarterEnd                       AS quarter_end,
    QuarterSequence                  AS quarter_sequence,

    /*
    Native currency valuation fields.
    */
    NAV                              AS nav_amount,
    UnfundedCommitment               AS unfunded_commitment,
    Currency                         AS currency,

    /*
    CHF reporting fields.
    */
    FXRateToCHF                      AS fx_rate_to_chf,
    NAVCHF                           AS nav_amount_chf,
    UnfundedCommitmentCHF            AS unfunded_commitment_chf,

    /*
    Metadata.
    */
    ValuationStatus                  AS valuation_status

FROM raw.nav_v7
