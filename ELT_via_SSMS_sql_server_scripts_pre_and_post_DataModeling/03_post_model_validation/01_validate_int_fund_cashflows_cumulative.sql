/*
Validation query.

Purpose:
Inspect the cumulative cashflow model and confirm that the running
cashflow path is being calculated correctly.

Expected result:
1. One row per fund and cashflow date
2. net_cashflow_amount reflects the daily sum
3. cumulative_net_cashflow starts negative for PE style funds
4. cumulative_net_cashflow evolves over time in chronological order
*/
SELECT TOP (1000) *
FROM intermediate.int_fund_cashflows_cumulative
ORDER BY fund_id, cashflow_date;
