USE PrivateMarkets;
GO

/*
Purpose:
Inspect the first rows of the quarterly performance mart.
Values are rounded to 2 decimal places for cleaner readability
in SSMS and for direct comparison against the deck.

Why this matters:
This is the first real business output of the new NAV plus performance layer.

Key fields to inspect (all displayed to 2 decimal places):
1. cumulative_paid_in_chf
2. cumulative_distributions_chf
3. nav_amount_chf
4. dpi
5. rvpi
6. tvpi
7. break_even_flag

Rounding note:
CAST to decimal(n,2) truncates the display precision and rounds
using round-half-away-from-zero, which is SQL Server's default.
The underlying mart columns remain at decimal(38,10) precision.
*/

SELECT TOP (1000)
    fund_id,
    fund_name,
    valuation_date,
    CAST(cumulative_paid_in_chf        AS decimal(18,2)) AS cumulative_paid_in_chf,
    CAST(cumulative_distributions_chf  AS decimal(18,2)) AS cumulative_distributions_chf,
    CAST(nav_amount_chf                AS decimal(18,2)) AS nav_amount_chf,
    CAST(dpi                           AS decimal(10,2)) AS dpi,
    CAST(rvpi                          AS decimal(10,2)) AS rvpi,
    CAST(tvpi                          AS decimal(10,2)) AS tvpi,
    break_even_flag
FROM mart.mart_fund_quarterly_performance
ORDER BY fund_id, valuation_date;
GO
