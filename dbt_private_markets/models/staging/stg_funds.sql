/*
Model: stg_funds

Purpose:
Clean and standardize raw fund master data.

Key responsibilities:
- Rename columns to snake_case
- Convert date keys into proper SQL dates
- Keep 1 row = 1 fund (no aggregation)

Grain:
1 row = 1 fund

Source:
raw.funds_v7

Design choice:
We enforce snake_case naming here so all downstream models
use consistent column names.
*/

SELECT

    -- Primary identifiers
    FundID                          AS fund_id,
    FundCode                        AS fund_code,
    FundName                        AS fund_name,

    -- Fund attributes
    VintageYear                     AS vintage_year,
    Strategy                        AS strategy,
    SubStrategy                     AS sub_strategy,
    Geography                       AS geography,
    SectorFocus                     AS sector_focus,

    -- Currency information
    BaseCurrency                    AS base_currency,
    ReportingCurrency               AS reporting_currency,

    -- Fund size metrics
    FundSize                        AS fund_size,

    -- Convert date key to SQL date
    TRY_CONVERT(date, CONVERT(char(8), FundSizeFXDateKey), 112)
                                    AS fund_size_fx_date,

    FundSizeFXRateToCHF             AS fund_size_fx_rate_to_chf,
    FundSizeCHFAtFinalClose         AS fund_size_chf_final_close,

    -- Lifecycle dates
    TRY_CONVERT(date, CONVERT(char(8), FirstCloseDateKey), 112)
                                    AS first_close_date,

    TRY_CONVERT(date, CONVERT(char(8), FinalCloseDateKey), 112)
                                    AS final_close_date,

    -- Duration
    InvestmentPeriodYears           AS investment_period_years,
    FundLifeYears                   AS fund_life_years,

    -- Economics
    MgmtFeeRateIP                  AS mgmt_fee_rate_ip,
    MgmtFeeRatePostIP              AS mgmt_fee_rate_post_ip,
    CarryRate                       AS carry_rate,
    PreferredReturnRate             AS preferred_return_rate,

    -- Metadata
    CommitmentStyle                 AS commitment_style,
    Manager                         AS manager,
    Domicile                        AS domicile,
    Status                          AS status,
    ESGArticle                      AS esg_article

FROM raw.funds_v7
