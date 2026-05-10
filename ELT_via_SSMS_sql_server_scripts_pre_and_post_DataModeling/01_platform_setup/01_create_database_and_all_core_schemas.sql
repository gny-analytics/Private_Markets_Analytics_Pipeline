/*
01_platform_setup__create_database_and_all_core_schemas.sql

Purpose:
Create the PrivateMarkets database if it does not already exist.
Then switch the current query session into that database.
Then create the four core schemas used in the project:
raw, staging, intermediate, and mart.

Important behavior:
This script is rerunnable.
That means it checks whether the database or schemas already exist
before trying to create them again.
*/

/*
Create the PrivateMarkets database only if it does not already exist.

Why this matters:
A plain CREATE DATABASE statement works only the first time.
This conditional version is safer because it can be executed again later
without failing if the database is already there.
*/
IF DB_ID(N'PrivateMarkets') IS NULL
BEGIN
    CREATE DATABASE PrivateMarkets;
END;
GO

/*
Switch the current query session into the PrivateMarkets database.

Why this matters:
All schema creation statements below must run inside PrivateMarkets,
not inside master or any other database.
*/
USE PrivateMarkets;
GO

/*
Create the raw schema only if it does not already exist.

Purpose of the raw schema:
Store the raw landing tables imported directly from the CSV files
with minimal transformation.
*/
IF SCHEMA_ID(N'raw') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA raw');
END;
GO

/*
Create the staging schema only if it does not already exist.

Purpose of the staging schema:
Store cleaned and standardized views or tables built from the raw layer.
This is where source quirks get normalized before dimensional modeling.
*/
IF SCHEMA_ID(N'staging') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA staging');
END;
GO

/*
Create the intermediate schema only if it does not already exist.

Purpose of the intermediate schema:
Store the intermediate transformation layer built by dbt core.
It sits between staging and marts.
*/
IF SCHEMA_ID(N'intermediate') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA intermediate');
END;
GO

/*
Create the mart schema only if it does not already exist.

Purpose of the mart schema:
Store the final analytical layer used for reporting and business intelligence.
This is where fact tables, dimension tables, and reporting views will live.
*/
IF SCHEMA_ID(N'mart') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA mart');
END;
GO

/*
Verification query number 1.

Expected result:
CurrentDatabase should be PrivateMarkets.
*/
SELECT DB_NAME() AS CurrentDatabase;
GO

/*
Verification query number 2.

Expected result:
The result set should contain exactly these four schema names:
intermediate
mart
raw
staging
*/
SELECT
    s.name AS SchemaName
FROM sys.schemas AS s
WHERE s.name IN (N'raw', N'staging', N'intermediate', N'mart')
ORDER BY s.name;
GO
