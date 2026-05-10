USE PrivateMarkets;
GO

WITH ranked AS (

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
        break_even_flag,
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
