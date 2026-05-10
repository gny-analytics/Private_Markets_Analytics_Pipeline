/*
Model: int_fund_cashflows_cumulative

Purpose:
Build a cumulative cashflow time series from the intermediate
fund cashflow model.

Why this model exists:
The prior intermediate model, int_fund_cashflows, is still at the
transaction level.
For J curve analysis, we need a time series that shows how net cashflows
evolve over time for each fund.

Business use:
This model supports:
1. J curve charts
2. cumulative net cashflow analysis
3. break even timing analysis
4. later linkage with NAV for fuller private markets performance views

Grain:
1 row = 1 fund + 1 cashflow date

Source:
intermediate.int_fund_cashflows

Important design note:
A single fund can have multiple transaction rows on the same date.
So we first aggregate transactions into one net daily cashflow per fund
before calculating the cumulative running total.

Important analytical note:
The cumulative net cashflow is calculated with a window function.
This is one of the most important techniques in analytical SQL.
*/

WITH daily_cashflows AS (

    /*
    CTE: daily_cashflows

    Purpose:
    Aggregate transaction level signed cashflows into one daily net
    cashflow per fund and per cashflow date.

    Why this is needed:
    On a given date, one fund may have several separate rows such as:
    1. investment
    2. management fee
    3. fund expense

    For a J curve, we generally want the total daily movement first,
    then the cumulative running total on top of that.
    */
    SELECT
        fund_id,
        fund_name,
        vintage_year,
        cashflow_date,

        /*
        Sum all signed transaction amounts occurring on the same date
        for the same fund.
        */
        SUM(signed_amount) AS net_cashflow_amount

    FROM {{ ref('int_fund_cashflows') }}

    GROUP BY
        fund_id,
        fund_name,
        vintage_year,
        cashflow_date

),

cumulative_cashflows AS (

    /*
    CTE: cumulative_cashflows

    Purpose:
    Calculate cumulative net cashflow through time for each fund.

    Window logic explanation:
    1. PARTITION BY fund_id
       Restart the running total separately for each fund.

    2. ORDER BY cashflow_date
       Accumulate chronologically from oldest date to newest date.

    3. ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       Running total from the first available row through the current row.
    */
    SELECT
        fund_id,
        fund_name,
        vintage_year,
        cashflow_date,
        net_cashflow_amount,

        /*
        Running cumulative net cashflow for each fund.
        */
        SUM(net_cashflow_amount) OVER (
            PARTITION BY fund_id
            ORDER BY cashflow_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_net_cashflow

    FROM daily_cashflows

)

SELECT

    /*
    Fund identifier.
    */
    fund_id,

    /*
    Fund descriptors.
    */
    fund_name,
    vintage_year,

    /*
    Time axis for the J curve.
    */
    cashflow_date,

    /*
    Net cashflow occurring on this exact date.
    */
    net_cashflow_amount,

    /*
    Running cumulative net cashflow up to this date.
    This is the core J curve series.
    */
    cumulative_net_cashflow

FROM cumulative_cashflows
