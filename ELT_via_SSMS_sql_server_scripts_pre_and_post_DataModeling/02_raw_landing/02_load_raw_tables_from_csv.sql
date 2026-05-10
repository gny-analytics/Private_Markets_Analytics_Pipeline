/*
03_load_raw_tables.sql

Purpose:
Load the CSV files into the raw landing tables.

>>> IMPORTANT FOR ANYONE RUNNING THIS FROM A FRESH CLONE <<<
The BULK INSERT FROM clauses below use absolute paths.
You MUST update each FROM path to wherever you cloned this repository.
The CSV files live alongside this script tree at: <REPO_ROOT>/data/csv/
Example replacement:
  FROM 'C:\Users\<you>\path\to\Private_Markets_Analytics\data\csv\funds_v7.csv'
SQL Server BULK INSERT requires absolute paths and the SQL Server service
account must have read access to that folder.

Important note:
This script uses TRUNCATE TABLE before each load.
That makes the script rerunnable without creating duplicate rows.

Important note:
This script assumes the raw tables already exist.
Run 01_create_raw_tables.sql first.
*/

USE PrivateMarkets;
GO

/*
Reload raw.funds_v7 from the CSV file.

Why TRUNCATE TABLE is used:
The goal here is a full reload of the landing table.
That is faster and cleaner than deleting row by row.
*/
TRUNCATE TABLE raw.funds_v7;
GO

BULK INSERT raw.funds_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\funds_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.investors_v7 from the CSV file.
*/
TRUNCATE TABLE raw.investors_v7;
GO

BULK INSERT raw.investors_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\investors_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.commitments_v7 from the CSV file.
*/
TRUNCATE TABLE raw.commitments_v7;
GO

BULK INSERT raw.commitments_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\commitments_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.cashflows_v7 from the CSV file.
*/
TRUNCATE TABLE raw.cashflows_v7;
GO

BULK INSERT raw.cashflows_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\cashflows_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.nav_v7 from the CSV file.
*/
TRUNCATE TABLE raw.nav_v7;
GO

BULK INSERT raw.nav_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\nav_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.date_dim_v7 from the CSV file.
*/
TRUNCATE TABLE raw.date_dim_v7;
GO

BULK INSERT raw.date_dim_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\date_dim_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.asset_master_v7 from the CSV file.
*/
TRUNCATE TABLE raw.asset_master_v7;
GO

BULK INSERT raw.asset_master_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\asset_master_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.asset_quarterly_snapshot_v7 from the CSV file.
*/
TRUNCATE TABLE raw.asset_quarterly_snapshot_v7;
GO

BULK INSERT raw.asset_quarterly_snapshot_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\asset_quarterly_snapshot_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.fx_rates_chf_v7 from the CSV file.
*/
TRUNCATE TABLE raw.fx_rates_chf_v7;
GO

BULK INSERT raw.fx_rates_chf_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\fx_rates_chf_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

/*
Reload raw.investor_cashflows_v7 from the CSV file.
*/
TRUNCATE TABLE raw.investor_cashflows_v7;
GO

BULK INSERT raw.investor_cashflows_v7
FROM 'C:\Users\sosa_\OneDrive\Desktop\MiniPE_Project\SQL_Server_2022_csv\CSV_Export\investor_cashflows_v7.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO
