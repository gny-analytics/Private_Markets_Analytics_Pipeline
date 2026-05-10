USE PrivateMarkets;
GO

/*
Purpose:
Inspect the first rows of the quarterly performance mart.

Why this matters:
This is the first real business output of the new NAV plus performance layer.

Key fields to inspect:
1. cumulative_paid_in_chf
2. cumulative_distributions_chf
3. nav_amount_chf
4. dpi
5. rvpi
6. tvpi
7. break_even_flag
*/

SELECT TOP (1000)
    fund_id,
    fund_name,
    valuation_date,
    cumulative_paid_in_chf,
    cumulative_distributions_chf,
    nav_amount_chf,
    dpi,
    rvpi,
    tvpi,
    break_even_flag
FROM mart.mart_fund_quarterly_performance
ORDER BY fund_id, valuation_date;
GO
