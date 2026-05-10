/*
02_create_raw_tables.sql

Purpose:
Create the raw landing tables only if they do not already exist.

Design choice:
This script is non destructive.
If a raw table already exists, it is left untouched.

Important note:
Flag columns in raw.date_dim_v7 and raw.fx_rates_chf_v7
are defined as NVARCHAR(20) from the start.
This avoids the bulk load failure you hit earlier.
*/

USE PrivateMarkets;
GO

/*
Create raw.funds_v7 only if it does not already exist.

Purpose:
Store the raw fund master data exactly as exported from the CSV file.

Important note:
The raw date style columns exported from Excel are preserved as INT in this raw layer.
The DateKey columns are also kept and will be used later in the staging layer
to build proper SQL date values.
*/
IF OBJECT_ID(N'raw.funds_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.funds_v7 (
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        FundName NVARCHAR(255) NOT NULL,
        VintageYear INT NOT NULL,
        Strategy NVARCHAR(100) NOT NULL,
        SubStrategy NVARCHAR(255) NULL,
        Geography NVARCHAR(100) NULL,
        SectorFocus NVARCHAR(255) NULL,
        BaseCurrency NVARCHAR(10) NOT NULL,
        ReportingCurrency NVARCHAR(10) NOT NULL,
        FundSize DECIMAL(19,2) NOT NULL,
        FundSizeFXDateKey INT NOT NULL,
        FundSizeFXRateToCHF DECIMAL(18,6) NOT NULL,
        FundSizeCHFAtFinalClose DECIMAL(19,2) NOT NULL,
        FirstCloseDate INT NOT NULL,
        FirstCloseDateKey INT NOT NULL,
        FinalCloseDate INT NOT NULL,
        FinalCloseDateKey INT NOT NULL,
        InvestmentPeriodYears INT NOT NULL,
        FundLifeYears INT NOT NULL,
        MgmtFeeRateIP DECIMAL(10,6) NOT NULL,
        MgmtFeeRatePostIP DECIMAL(10,6) NOT NULL,
        CarryRate DECIMAL(10,6) NOT NULL,
        PreferredReturnRate DECIMAL(10,6) NOT NULL,
        CommitmentStyle NVARCHAR(100) NULL,
        Manager NVARCHAR(255) NULL,
        Domicile NVARCHAR(100) NULL,
        Status NVARCHAR(100) NULL,
        ESGArticle NVARCHAR(100) NULL
    );
END;
GO

/*
Create raw.investors_v7 only if it does not already exist.

Purpose:
Store the raw investor master data exactly as exported from the CSV file.
*/
IF OBJECT_ID(N'raw.investors_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.investors_v7 (
        InvestorID INT NOT NULL,
        InvestorCode NVARCHAR(50) NOT NULL,
        InvestorName NVARCHAR(255) NOT NULL,
        InvestorType NVARCHAR(100) NULL,
        InvestorChannel NVARCHAR(100) NULL,
        Region NVARCHAR(100) NULL,
        Country NVARCHAR(100) NULL,
        BaseCurrency NVARCHAR(10) NULL,
        CommitmentBucket NVARCHAR(100) NULL,
        RelationshipStartYear INT NULL,
        OnboardingOffice NVARCHAR(100) NULL,
        ESGPreference NVARCHAR(100) NULL,
        TaxStatus NVARCHAR(100) NULL,
        InvestorStatus NVARCHAR(100) NULL
    );
END;
GO

/*
Create raw.commitments_v7 only if it does not already exist.

Purpose:
Store raw commitment events linking investors to funds.
*/
IF OBJECT_ID(N'raw.commitments_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.commitments_v7 (
        CommitmentID INT NOT NULL,
        CommitmentRef NVARCHAR(100) NOT NULL,
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        InvestorID INT NOT NULL,
        InvestorCode NVARCHAR(50) NOT NULL,
        CommitmentDate INT NOT NULL,
        CommitmentDateKey INT NOT NULL,
        CommitmentAmount DECIMAL(19,2) NOT NULL,
        CommitmentCurrency NVARCHAR(10) NOT NULL,
        FXRateToCHF DECIMAL(18,6) NOT NULL,
        CommitmentAmountCHF DECIMAL(19,2) NOT NULL,
        CommitmentPctOfFund DECIMAL(18,10) NOT NULL,
        ClosingRound NVARCHAR(100) NULL,
        CommitmentStatus NVARCHAR(100) NULL,
        SideLetterFlag NVARCHAR(20) NULL,
        MostFavoredNationFlag NVARCHAR(20) NULL,
        CoInvestmentRightsFlag NVARCHAR(20) NULL,
        FeeTermsBucket NVARCHAR(100) NULL,
        RecordSource NVARCHAR(100) NULL
    );
END;
GO

/*
Create raw.cashflows_v7 only if it does not already exist.

Purpose:
Store raw fund level cashflow events.

Important note:
AssetID and AssetCode are nullable because some rows such as fund expenses
are not tied to a specific asset.
*/
IF OBJECT_ID(N'raw.cashflows_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.cashflows_v7 (
        CashflowID INT NOT NULL,
        CashflowRef NVARCHAR(100) NOT NULL,
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        AssetID INT NULL,
        AssetCode NVARCHAR(50) NULL,
        [Date] INT NOT NULL,
        DateKey INT NOT NULL,
        NoticeDate INT NOT NULL,
        NoticeDateKey INT NOT NULL,
        DueDate INT NOT NULL,
        DueDateKey INT NOT NULL,
        [Type] NVARCHAR(50) NOT NULL,
        CashflowCategory NVARCHAR(100) NOT NULL,
        Amount DECIMAL(19,2) NOT NULL,
        Currency NVARCHAR(10) NOT NULL,
        FXRateToCHF DECIMAL(18,6) NOT NULL,
        AmountCHF DECIMAL(19,2) NOT NULL,
        Quarter NVARCHAR(20) NULL,
        Status NVARCHAR(50) NULL,
        BatchID NVARCHAR(100) NULL
    );
END;
GO

/*
Create raw.nav_v7 only if it does not already exist.

Purpose:
Store raw fund NAV snapshots over time.
*/
IF OBJECT_ID(N'raw.nav_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.nav_v7 (
        NAVID INT NOT NULL,
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        ValuationDate INT NOT NULL,
        ValuationDateKey INT NOT NULL,
        QuarterEnd NVARCHAR(20) NULL,
        NAV DECIMAL(19,2) NOT NULL,
        Currency NVARCHAR(10) NOT NULL,
        FXRateToCHF DECIMAL(18,6) NOT NULL,
        NAVCHF DECIMAL(19,2) NOT NULL,
        UnfundedCommitment DECIMAL(19,2) NOT NULL,
        UnfundedCommitmentCHF DECIMAL(19,2) NOT NULL,
        ValuationStatus NVARCHAR(100) NULL,
        QuarterSequence INT NULL
    );
END;
GO

/*
Create raw.date_dim_v7 only if it does not already exist.

Purpose:
Store the raw date dimension exactly as exported from the CSV file.

Important note:
The flag columns are stored as NVARCHAR(20) in the raw layer.
This preserves the source values safely and avoids bulk load conversion errors.
*/
IF OBJECT_ID(N'raw.date_dim_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.date_dim_v7 (
        DateKey INT NOT NULL,
        [Date] INT NOT NULL,
        DayNumber INT NOT NULL,
        DayName NVARCHAR(20) NOT NULL,
        DayOfWeekISO INT NOT NULL,
        WeekOfYear INT NOT NULL,
        [Month] INT NOT NULL,
        MonthName NVARCHAR(20) NOT NULL,
        MonthShort NVARCHAR(10) NOT NULL,
        Quarter NVARCHAR(20) NOT NULL,
        QuarterNum INT NOT NULL,
        [Year] INT NOT NULL,
        YearQuarter NVARCHAR(20) NOT NULL,
        YearMonth NVARCHAR(20) NOT NULL,
        MonthStartFlag NVARCHAR(20) NOT NULL,
        MonthEndFlag NVARCHAR(20) NOT NULL,
        QuarterStartFlag NVARCHAR(20) NOT NULL,
        QuarterEndFlag NVARCHAR(20) NOT NULL,
        YearStartFlag NVARCHAR(20) NOT NULL,
        YearEndFlag NVARCHAR(20) NOT NULL,
        IsWeekendFlag NVARCHAR(20) NOT NULL
    );
END;
GO

/*
Create raw.asset_master_v7 only if it does not already exist.

Purpose:
Store the raw asset master information for the underlying investments.
*/
IF OBJECT_ID(N'raw.asset_master_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.asset_master_v7 (
        AssetID INT NOT NULL,
        AssetCode NVARCHAR(50) NOT NULL,
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        AssetName NVARCHAR(255) NOT NULL,
        AssetType NVARCHAR(100) NULL,
        InvestmentType NVARCHAR(100) NULL,
        Sector NVARCHAR(100) NULL,
        SubSector NVARCHAR(100) NULL,
        Region NVARCHAR(100) NULL,
        Country NVARCHAR(100) NULL,
        Currency NVARCHAR(10) NOT NULL,
        EntryDate INT NOT NULL,
        EntryDateKey INT NOT NULL,
        EntryFXRateToCHF DECIMAL(18,6) NOT NULL,
        EntryCost DECIMAL(19,2) NOT NULL,
        EntryCostCHF DECIMAL(19,2) NOT NULL,
        ReservedFollowOn DECIMAL(19,2) NULL,
        ExitDate INT NULL,
        ExitDateKey INT NULL,
        RealizationStatus NVARCHAR(100) NULL,
        GrossMOICTarget2025 DECIMAL(18,6) NULL,
        ESGTheme NVARCHAR(100) NULL,
        SponsorType NVARCHAR(100) NULL
    );
END;
GO

/*
Create raw.asset_quarterly_snapshot_v7 only if it does not already exist.

Purpose:
Store raw quarterly asset valuation and cumulative movement information.
*/
IF OBJECT_ID(N'raw.asset_quarterly_snapshot_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.asset_quarterly_snapshot_v7 (
        AssetSnapshotID INT NOT NULL,
        AssetID INT NOT NULL,
        AssetCode NVARCHAR(50) NOT NULL,
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        ValuationDate INT NOT NULL,
        ValuationDateKey INT NOT NULL,
        QuarterEnd NVARCHAR(20) NULL,
        AssetStatus NVARCHAR(100) NULL,
        CumulativeInvested DECIMAL(19,2) NOT NULL,
        CumulativeInvestedCHF DECIMAL(19,2) NOT NULL,
        CumulativeProceeds DECIMAL(19,2) NOT NULL,
        CumulativeProceedsCHF DECIMAL(19,2) NOT NULL,
        FairValue DECIMAL(19,2) NOT NULL,
        FairValueCHF DECIMAL(19,2) NOT NULL,
        Currency NVARCHAR(10) NOT NULL,
        FXRateToCHF DECIMAL(18,6) NOT NULL,
        GrossMOIC DECIMAL(18,6) NULL
    );
END;
GO

/*
Create raw.fx_rates_chf_v7 only if it does not already exist.

Purpose:
Store raw CHF foreign exchange reference rates.

Important note:
The flag columns are stored as NVARCHAR(20) in the raw layer
to preserve the source values safely.
*/
IF OBJECT_ID(N'raw.fx_rates_chf_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.fx_rates_chf_v7 (
        FXRateID INT NOT NULL,
        DateKey INT NOT NULL,
        [Date] INT NOT NULL,
        FromCurrency NVARCHAR(10) NOT NULL,
        ToCurrency NVARCHAR(10) NOT NULL,
        FXRateType NVARCHAR(50) NULL,
        FXRate DECIMAL(18,6) NOT NULL,
        InverseRate DECIMAL(18,10) NOT NULL,
        MonthEndFlag NVARCHAR(20) NOT NULL,
        QuarterEndFlag NVARCHAR(20) NOT NULL,
        SourceNote NVARCHAR(255) NULL
    );
END;
GO

/*
Create raw.investor_cashflows_v7 only if it does not already exist.

Purpose:
Store raw investor level allocations of fund cashflow events.
*/
IF OBJECT_ID(N'raw.investor_cashflows_v7', N'U') IS NULL
BEGIN
    CREATE TABLE raw.investor_cashflows_v7 (
        InvestorCashflowID INT NOT NULL,
        InvestorCashflowRef NVARCHAR(100) NOT NULL,
        CashflowID INT NOT NULL,
        CashflowRef NVARCHAR(100) NOT NULL,
        FundID INT NOT NULL,
        FundCode NVARCHAR(50) NOT NULL,
        InvestorID INT NOT NULL,
        InvestorCode NVARCHAR(50) NOT NULL,
        [Date] INT NOT NULL,
        DateKey INT NOT NULL,
        [Type] NVARCHAR(50) NOT NULL,
        CashflowCategory NVARCHAR(100) NOT NULL,
        Amount DECIMAL(19,2) NOT NULL,
        Currency NVARCHAR(10) NOT NULL,
        FXRateToCHF DECIMAL(18,6) NOT NULL,
        AmountCHF DECIMAL(19,2) NOT NULL,
        CommitmentSharePct DECIMAL(18,10) NOT NULL,
        Status NVARCHAR(50) NULL,
        AllocationMethod NVARCHAR(255) NULL
    );
END;
GO

/*
Verification query.

Expected result:
The result set should contain exactly ten raw tables.
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
