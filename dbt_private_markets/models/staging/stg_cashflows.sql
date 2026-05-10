/*
Model: stg_cashflows

Purpose:
Clean and standardize raw cashflow transactions.

Key responsibilities:
- Rename columns to snake_case
- Convert date keys into SQL dates
- Preserve transaction-level granularity

Grain:
1 row = 1 cashflow event

Source:
raw.cashflows_v7

Design note:
This model prepares data for financial analytics (J-curve, IRR).
*/

SELECT

    -- Primary identifiers
    CashflowID              AS cashflow_id,
    CashflowRef             AS cashflow_ref,
    FundID                  AS fund_id,
    FundCode                AS fund_code,

    AssetID                 AS asset_id,
    AssetCode               AS asset_code,

    -- Date fields
    DateKey                 AS cashflow_date_key,
    TRY_CONVERT(date, CONVERT(char(8), DateKey), 112)
                            AS cashflow_date,

    NoticeDateKey           AS notice_date_key,
    TRY_CONVERT(date, CONVERT(char(8), NoticeDateKey), 112)
                            AS notice_date,

    DueDateKey              AS due_date_key,
    TRY_CONVERT(date, CONVERT(char(8), DueDateKey), 112)
                            AS due_date,

    -- Classification
    [Type]                  AS cashflow_type,
    CashflowCategory        AS cashflow_category,

    -- Financials
    Amount                  AS amount,
    Currency                AS currency,
    FXRateToCHF             AS fx_rate_to_chf,
    AmountCHF               AS amount_chf,

    -- Metadata
    Quarter                 AS quarter,
    Status                  AS status,
    BatchID                 AS batch_id

FROM raw.cashflows_v7
