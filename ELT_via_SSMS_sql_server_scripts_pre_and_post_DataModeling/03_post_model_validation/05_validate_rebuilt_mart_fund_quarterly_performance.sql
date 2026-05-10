USE PrivateMarkets;
GO

/*
Purpose:
Validate the rebuilt mart_fund_quarterly_performance model after it has been
rewritten on top of the star schema.

What this script checks:
1. the mart object exists
2. the first rows look sensible
3. the latest row per fund looks sensible
4. TVPI still equals DPI + RVPI within a tiny tolerance
*/

/*
Check that the mart object exists.
Expected result:
One row in schema mart with object name mart_fund_quarterly_performance.
*/
SELECT
    s.name AS schema_name,
    v.name AS object_name,
    'VIEW' AS object_type
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'mart'
  AND v.name = N'mart_fund_quarterly_performance';
GO

/*
Inspect the first rows.
*/
SELECT TOP (50)
    fund_id,
    fund_name,
    valuation_date,
    cumulative_paid_in_chf,
    cumulative_distributions_chf,
    nav_amount_chf,
    total_value_chf,
    dpi,
    rvpi,
    tvpi,
    break_even_flag
FROM mart.mart_fund_quarterly_performance
ORDER BY fund_id, valuation_date;
GO

/*
Inspect only the latest row per fund.
*/
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY fund_id
            ORDER BY valuation_date DESC
        ) AS row_num_latest_snapshot
    FROM mart.mart_fund_quarterly_performance
)
SELECT
    fund_id,
    fund_name,
    valuation_date,
    cumulative_paid_in_chf,
    cumulative_distributions_chf,
    nav_amount_chf,
    total_value_chf,
    dpi,
    rvpi,
    tvpi,
    break_even_flag
FROM ranked
WHERE row_num_latest_snapshot = 1
ORDER BY fund_id;
GO

/*
Sanity check the identity TVPI = DPI + RVPI.
Small floating point style tolerances are allowed.
*/
SELECT
    fund_id,
    fund_name,
    valuation_date,
    dpi,
    rvpi,
    tvpi,
    ABS(tvpi - (dpi + rvpi)) AS tvpi_identity_gap
FROM mart.mart_fund_quarterly_performance
WHERE ABS(tvpi - (dpi + rvpi)) > 0.000001
ORDER BY fund_id, valuation_date;
GO
