USE PrivateMarkets;
GO

/*
Purpose:
Inspect IRR input rows for one fund.

Why this matters:
We want to confirm that each valuation snapshot contains:
1. historical actual cashflows
2. one terminal NAV row
*/

SELECT TOP (10000)
    fund_id,
    fund_name,
    valuation_date,
    irr_event_date,
    irr_cashflow_amount_chf,
    irr_row_type
FROM intermediate.int_fund_irr_inputs
WHERE fund_id = 1
ORDER BY
    valuation_date,
    irr_event_date,
    irr_row_type;
GO
