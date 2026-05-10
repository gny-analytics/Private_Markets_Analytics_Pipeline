/*
04_validate_raw_load.sql

Purpose:
Validate that the raw landing tables were loaded correctly.

This script does three things:
1. It returns one row count per raw table.
2. It shows the first few rows from three important raw tables.
3. It helps confirm that the import pipeline is working before any staging work begins.

Important note:
This script is read only.
It does not modify data.
*/

USE PrivateMarkets;
GO

/*
Validation query number 1.

Purpose:
Return one row count per raw table so that the loaded row counts can be compared
against the expected source row counts.

Expected results:
raw.funds_v7                       5
raw.investors_v7                  11
raw.commitments_v7                55
raw.cashflows_v7                 927
raw.nav_v7                       156
raw.date_dim_v7                 3653
raw.asset_master_v7               30
raw.asset_quarterly_snapshot_v7  765
raw.fx_rates_chf_v7            18265
raw.investor_cashflows_v7      10004
*/
SELECT N'raw.funds_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.funds_v7

UNION ALL

SELECT N'raw.investors_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.investors_v7

UNION ALL

SELECT N'raw.commitments_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.commitments_v7

UNION ALL

SELECT N'raw.cashflows_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.cashflows_v7

UNION ALL

SELECT N'raw.nav_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.nav_v7

UNION ALL

SELECT N'raw.date_dim_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.date_dim_v7

UNION ALL

SELECT N'raw.asset_master_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.asset_master_v7

UNION ALL

SELECT N'raw.asset_quarterly_snapshot_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.asset_quarterly_snapshot_v7

UNION ALL

SELECT N'raw.fx_rates_chf_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.fx_rates_chf_v7

UNION ALL

SELECT N'raw.investor_cashflows_v7' AS TableName, COUNT(*) AS ActualRowCount
FROM raw.investor_cashflows_v7

ORDER BY TableName;
GO

/*
Validation query number 2.

Purpose:
Show the first 10 rows from raw.funds_v7.

Why this matters:
This is a small master table, so it is easy to inspect visually.
It helps confirm that text, numeric, and date key fields loaded as expected.
*/
SELECT TOP (10) *
FROM raw.funds_v7;
GO

/*
Validation query number 3.

Purpose:
Show the first 10 rows from raw.cashflows_v7.

Why this matters:
This is one of the most important raw fact style tables.
It helps confirm that amounts, currencies, date keys, and nullable asset fields
loaded correctly.
*/
SELECT TOP (10) *
FROM raw.cashflows_v7;
GO

/*
Validation query number 4.

Purpose:
Show the first 10 rows from raw.investor_cashflows_v7.

Why this matters:
This is the investor allocation layer and one of the larger raw tables.
It helps confirm that the fan out from fund cashflows to investor cashflows
loaded correctly.
*/
SELECT TOP (10) *
FROM raw.investor_cashflows_v7;
GO

/*
Validation query number 5.

Purpose:
Confirm that the raw schema currently contains exactly ten user tables.

Why this matters:
This is a quick structural check before moving on to the staging layer.
*/
SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name = N'raw'
ORDER BY t.name;
GO
