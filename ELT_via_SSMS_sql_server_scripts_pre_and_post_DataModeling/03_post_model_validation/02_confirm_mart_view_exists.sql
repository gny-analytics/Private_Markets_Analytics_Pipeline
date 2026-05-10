USE PrivateMarkets;
GO

/*
Purpose:
Confirm that the mart object exists as a SQL Server view.

Why this matters:
Your dbt model was configured as a view model.
So the first validation should check sys.views, not a long mixed script.

Expected result:
One row with:
schema_name = mart
object_name = mart_fund_quarterly_performance
*/

SELECT
    s.name AS schema_name,
    v.name AS object_name
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON v.schema_id = s.schema_id
WHERE s.name = N'mart'
  AND v.name = N'mart_fund_quarterly_performance';
GO
