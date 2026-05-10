# Private Markets Analytics Pipeline — Self-Study Guide

> **Project type:** Independent portfolio project · **Domain:** Private markets (PE Buyout, PE Growth, PE Infrastructure, Private Debt, Real Estate)
> **Stack:** SQL Server 2022 · dbt core + `dbt-sqlserver` adapter · Power BI Desktop · T-SQL
> **Reporting currency:** CHF (Swiss Franc, Geneva-style allocator framing)
> **Source data:** Synthetic Excel workbook (`private_markets_crystallized_v7_chf_fixed.xlsx`)
> **Models:** 3 staging · 4 intermediate · 3 dimensions · 3 facts · 1 reporting mart (11 total)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Tools & Prerequisites](#2-tools--prerequisites)
3. [Project Architecture vs Production](#3-project-architecture-vs-production)
4. [Data Format Flow](#4-data-format-flow)
5. [Star Schema Design](#5-star-schema-design)
6. [SQL Function Reference](#6-sql-function-reference)
7. [The dbt Pipeline](#7-the-dbt-pipeline)
   - [Layer 0 — Raw Sources](#layer-0--raw-sources)
   - [Layer 1 — stg_funds](#layer-1--stg_funds)
   - [Layer 2 — stg_cashflows](#layer-2--stg_cashflows)
   - [Layer 3 — stg_nav](#layer-3--stg_nav)
   - [Layer 4 — int_fund_cashflows](#layer-4--int_fund_cashflows)
   - [Layer 5 — int_fund_cashflows_cumulative](#layer-5--int_fund_cashflows_cumulative)
   - [Layer 6 — int_fund_performance_snapshots](#layer-6--int_fund_performance_snapshots)
   - [Layer 7 — int_fund_irr_inputs](#layer-7--int_fund_irr_inputs)
   - [Layer 8 — dim_fund / dim_date / dim_investor](#layer-8--dimensions)
   - [Layer 9 — fact_cashflows / fact_nav / fact_commitments](#layer-9--facts)
   - [Layer 10 — mart_fund_quarterly_performance](#layer-10--mart_fund_quarterly_performance)
8. [Business Metrics Rationale](#8-business-metrics-rationale)
9. [End-to-End Recipe](#9-end-to-end-recipe)
10. [Lexique / Glossary](#10-lexique--glossary)

---

## 1. Project Overview

The **Private Markets Analytics Pipeline (PMADP)** is an independent portfolio project that simulates the analytics infrastructure of a Geneva-style private markets allocator. It demonstrates a complete, defensible, end-to-end data-engineering workflow over a synthetic but economically coherent fund dataset.

### What this project simulates

A diversified private markets sleeve at a Swiss institutional allocator, reporting in CHF, covering five fund vintages across five strategy types. The dataset is "idealised but coherent" — it preserves PE economic sequencing (commitment before paid-in, paid-in before NAV crystallises, distributions arriving after the J-curve trough, TVPI = DPI + RVPI identity holding exactly) without simulating every operational quirk of a real-world fund-administration platform.

### The 5-fund mix

| Fund                      | Strategy           | Vintage cluster | Quarterly snapshots | Latest TVPI |
| ------------------------- | ------------------ | --------------- | ------------------- | ----------- |
| Alpha Buyout I (AB1)      | PE Buyout          | Mature          | 40                  | 1.342       |
| Beta Growth II (BG2)      | PE Growth          | Younger         | 28                  | 1.542       |
| Gamma Infra I (GI1)       | PE Infrastructure  | Mid-life        | 32                  | 1.181       |
| Delta Direct Lending I (DDL1) | Private Debt   | Mid-life        | 24                  | 1.057       |
| Epsilon Real Estate I (ER1) | Real Estate      | Mid-life        | 32                  | 1.114       |

All five funds have crossed break-even at the latest snapshot date (2024-09-30); the dataset is calibrated so that `TVPI = DPI + RVPI` holds exactly to within floating-point tolerance.

### Reporting currency — CHF

All performance ratios and combined-value measures use **CHF** as the reporting currency. This matches a Geneva-based allocator's reporting framework. FX conversion happens at the transaction date for flow measures (paid-in, distributions, cumulative cashflow) and at the valuation date for stock measures (NAV, fair value). Daily FX rates against CHF for every relevant currency are stored in `fx_rates_chf_v7` (18,265 rows over ~10 years).

### Date range

The dataset spans **10 years** (3,653 days in `date_dim_v7`), covering vintage formation, deployment, harvesting, and partial realisation across all five funds.

### Key figures (final validated state)

| Source table                  | Row count | Role                                   |
| ----------------------------- | --------- | -------------------------------------- |
| `funds_v7`                    | 5         | Fund master                            |
| `investors_v7`                | 11        | LP master                              |
| `commitments_v7`              | 55        | Commitment events (LP → fund)          |
| `cashflows_v7`                | 927       | Fund-level cashflow events             |
| `nav_v7`                      | 156       | Quarterly NAV snapshots                |
| `date_dim_v7`                 | 3,653     | Conformed date dimension               |
| `asset_master_v7`             | 30        | Underlying asset master                |
| `asset_quarterly_snapshot_v7` | 765       | Asset-level quarterly performance      |
| `fx_rates_chf_v7`             | 18,265    | Daily CHF FX rates                     |
| `investor_cashflows_v7`       | 10,004    | LP-level allocation of fund cashflows  |
| **Total**                     | **~34,000** |                                      |

### Source system — Excel workbook treated as OLTP

The "operational source system" is a synthetic Excel workbook (`private_markets_crystallized_v7_chf_fixed.xlsx`) representing what would, in production, be a fund-administration platform like eFront, Allvue, or iLEVEL. Ten operational tabs are exported as CSV and bulk-loaded into SQL Server's `raw` schema. Four documentation/QA tabs (`assumptions_v7`, `fund_kpis_v7`, `data_dictionary_v7`, `qa_checks_v7`) are excluded from the load — they're metadata, not source-of-truth.

---

## 2. Tools & Prerequisites

### Software to install locally

| Tool                       | Version | Purpose                                                          | Install                       |
| -------------------------- | ------- | ---------------------------------------------------------------- | ----------------------------- |
| **SQL Server 2022**        | Express edition is fine | Raw landing + dimensional warehouse                  | microsoft.com                 |
| **SSMS**                   | Latest  | SQL editor + execution + Object Explorer                         | microsoft.com                 |
| **Python**                 | 3.11+   | dbt runs on Python; data generation scripts                      | python.org                    |
| **dbt-core + dbt-sqlserver** | 1.8+  | SQL transformation framework + SQL Server adapter                | `pip install dbt-sqlserver`   |
| **ODBC Driver 17 for SQL Server** | Latest | Required by `dbt-sqlserver` to talk to SQL Server         | microsoft.com (Microsoft ODBC Driver) |
| **Power BI Desktop**       | Latest  | Report authoring and semantic model                              | Microsoft Store               |
| **VS Code**                | Latest  | SQL + YAML editing                                               | code.visualstudio.com         |

### Authentication

All authentication uses **Windows authentication** (`windows_login: true`) — the SQL Server instance runs locally and trusts the current Windows user. No password to manage, no service principal needed. This is the simplest setup for a local portfolio project; in production you'd use SQL auth or a service principal with a key-vault-backed secret.

### Authentication recipe

```bash
# Verify SQL Server is reachable
sqlcmd -S "SOSA\SQLEXPRESS" -E -Q "SELECT @@VERSION"

# Verify dbt is installed
dbt --version

# From the dbt project folder:
cd <repo_root>/dbt_private_markets
dbt debug      # confirms profile + connection
dbt run        # builds all 11 models
dbt test       # runs schema tests (when configured)
```

### `profiles.yml` template

`profiles.yml` lives outside the project at `C:\Users\<user>\.dbt\profiles.yml`. The template that ships with the GitHub repo:

```yaml
dbt_private_markets:
  target: dev
  outputs:
    dev:
      type: sqlserver
      driver: "ODBC Driver 17 for SQL Server"
      server: "YOUR_SERVER_NAME\\YOUR_INSTANCE"   # e.g. "SOSA\\SQLEXPRESS"
      port: 1433
      database: "PrivateMarkets"
      schema: "staging"
      windows_login: true
      encrypt: true
      trust_cert: true
```

The `trust_cert: true` line is necessary because local SQL Server uses a self-signed certificate that won't validate against any public CA.

---

## 3. Project Architecture vs Production

| Layer                  | This project (portfolio)                       | Probable enterprise version (e.g. LGT / Pictet AA / similar Swiss allocator) |
| ---------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------- |
| Source system          | Excel workbook (synthetic, 10 operational tabs) | eFront, Allvue, iLEVEL, custom GP-data feeds + bilateral data rooms          |
| Raw ingestion          | Manual CSV export + `BULK INSERT` into SQL Server | Azure Data Factory, Fivetran, or custom Python ingestion to a Lakehouse / Snowflake landing zone |
| Raw storage            | SQL Server `raw` schema                        | Snowflake / Databricks / MS Fabric Lakehouse                                 |
| Transformation         | dbt core (open source, CLI) with `dbt-sqlserver` | dbt Core or dbt Cloud against Snowflake / Databricks / Fabric                |
| Modelling style        | Kimball star schema (3 dim + 3 fact)           | Star schema or Data Vault 2.0 (Hub / Link / Satellite)                       |
| Materialisation        | Views for staging/intermediate; physical tables for dim/fact | Same, plus incremental models for high-volume facts; potentially streaming tables |
| Semantic layer         | Power BI Import mode (or local DirectQuery)    | Power BI Service / Tableau Server / dbt Semantic Layer                       |
| Reporting              | Power BI Desktop (.pbix)                       | Power BI Service — certified datasets, RLS, deployment pipelines             |
| Orchestration          | Manual `dbt run` from VS Code terminal         | Airflow / Prefect / Azure DevOps pipelines / Fabric Data Factory             |
| Version control        | Local git → public GitHub                      | Azure DevOps Repos or GitHub Enterprise + branch policies                    |
| Authentication         | Windows auth on local SQL Server               | Service principal / managed identity, secrets in Key Vault                   |
| FX rates               | Static synthetic CSV                           | Bloomberg / Refinitiv / IMF feed, refreshed daily                            |

> **Key interview insight:** the architecture pattern — raw → staging → intermediate → dimensions+facts → reporting mart → BI — is identical to enterprise versions. The differences are platform-specific (SQL Server vs Snowflake), automation level (manual vs scheduled), and authentication (local vs cloud identity). The dimensional modelling, SQL transformation logic, and finance-domain business rules are production-grade.

---

## 4. Data Format Flow

```
Excel workbook (10 tabs)        Manual CSV export      raw schema (SQL Server)
(synthetic OLTP source)  ──────────────────────►   (10 BULK INSERT'd tables)
                                                            │
                                                            ▼
                                              Staging schema (dbt views)
                                              type-safe, snake_case, date-rebuilt
                                                            │
                                                            ▼
                                          Intermediate schema (dbt views)
                                          joins, business logic, J-curve, IRR shaping
                                                            │
                                                            ▼
                                                Mart schema (dbt tables for dims/facts
                                                + view for reporting mart)
                                                            │
                                                            ▼
                                          Power BI Desktop (Import mode)
                                          DAX measures · star-schema relationships
                                                            │
                                                            ▼
                                              Power BI report pages
                                              Portfolio Overview · J-Curve & Cashflow
```

| Format                | Where it lives                                       | Why this format                                                                    |
| --------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Excel `.xlsx`**     | `OLTP_SourceDataset_as_xlsx_csv/xlsx/private_markets_crystallized_v7_chf_fixed.xlsx` | Authoring environment for the synthetic dataset; treated as the OLTP source-of-truth |
| **CSV**               | `OLTP_SourceDataset_as_xlsx_csv/csv/*.csv` (10 files)                          | Universal exchange format. Simple comma-delimited strings. No type enforcement.    |
| **SQL Server tables** | `raw.<table>_v7` (10 tables)                         | Physical, indexable, queryable. Type-cast at load time via the table DDL.          |
| **SQL Server views**  | `staging.stg_*` and `intermediate.int_*`             | dbt materialises these as views — no row duplication, recomputed on read.          |
| **SQL Server tables** | `mart.dim_*` and `mart.fact_*` (6 objects)            | dbt materialises dim and fact as physical tables for Power BI VertiPaq performance. |
| **SQL Server view**   | `mart.mart_fund_quarterly_performance`               | Final reporting layer. View, not table — recomputed each refresh, never stale.     |
| **Power BI Import**   | `.pbix` semantic model in VertiPaq                    | Data pulled into Power BI's in-memory engine. Sub-second DAX queries.              |

---

## 5. Star Schema Design

The data model follows a **Kimball star schema**: one (or several) central fact table(s) surrounded by dimension tables, joined via integer foreign keys. Standard pattern for analytical data warehouses and Power BI semantic models.

### Why not 3NF / fully normalised?

Normalised databases avoid duplication by splitting data into many tables — great for transactional systems (where update consistency matters), bad for analytics (where many joins to answer one question is the norm). Star schemas denormalise intentionally: one join per dimension, predictable query patterns, fast aggregation.

### Why not one big wide table?

A single denormalised table creates: repeated strings (fund_name duplicated on every cashflow row), no reusable date logic, no single place to update a dimension attribute, and Power BI can't optimise relationships between fact and dimension tables.

### Schema diagram

```
┌──────────────────┐       ┌──────────────────────────────────┐       ┌──────────────────┐
│    dim_date      │       │       ⭐ fact_cashflows           │       │    dim_fund      │
│──────────────────│       │──────────────────────────────────│       │──────────────────│
│ PK date_id       │◄──────│ FK fund_id     → dim_fund         │──────►│ PK fund_id       │
│    full_date     │       │ FK date_id     → dim_date         │       │    fund_name     │
│    calendar_year │       │ FK notice_date_id → dim_date      │       │    strategy      │
│    quarter_label │       │ FK due_date_id → dim_date         │       │    vintage_year  │
│    year_quarter  │       │  M amount_chf, paid_in_amount_chf │       │    fund_size     │
│    month_name    │       │  M distribution_amount_chf        │       │    manager       │
│    *_flag fields │       │  M signed_amount_chf              │       │    domicile      │
└──────────────────┘       │     ...                           │       │    ...           │
                           └──────────────────────────────────┘       └──────────────────┘

                           ┌──────────────────────────────────┐       ┌──────────────────┐
                           │       ⭐ fact_nav                 │       │   dim_investor   │
                           │──────────────────────────────────│       │──────────────────│
                           │ FK fund_id     → dim_fund         │       │ PK investor_id   │
                           │ FK date_id     → dim_date         │       │    investor_name │
                           │  M nav_amount_chf                 │       │    investor_type │
                           │  M unfunded_commitment_chf        │       │    region        │
                           │  M fx_rate_to_chf                 │       │    base_currency │
                           │     ...                           │       │    ...           │
                           └──────────────────────────────────┘       └──────────────────┘

                           ┌──────────────────────────────────┐
                           │       ⭐ fact_commitments         │
                           │──────────────────────────────────│
                           │ FK fund_id     → dim_fund         │
                           │ FK investor_id → dim_investor     │
                           │ FK date_id     → dim_date         │
                           │  M commitment_amount_chf          │
                           │  M commitment_pct_of_fund         │
                           │     ...                           │
                           └──────────────────────────────────┘

                           ┌──────────────────────────────────┐
                           │  mart_fund_quarterly_performance  │
                           │──────────────────────────────────│
                           │     fund_id, valuation_date       │
                           │     nav_amount_chf, paid_in_chf   │
                           │     dpi, rvpi, tvpi               │
                           │     break_even_flag               │
                           │   (built on top of fact_nav +     │
                           │    fact_cashflows + dim_fund)     │
                           └──────────────────────────────────┘
```

`PK` = Primary Key · `FK` = Foreign Key · `M` = Measure (additive numeric)

### The three-date-FK pattern on `fact_cashflows`

`fact_cashflows` has three foreign keys to `dim_date`: `date_id` (transaction date), `notice_date_id` (when the cashflow was announced), `due_date_id` (when payment was due). In Power BI's relationship model, only one date relationship per pair of tables can be active at a time. Convention here: `date_id` (transaction date) is the active relationship; the other two are inactive and activated in DAX with `USERELATIONSHIP()` when needed for a specific visual.

---

## 6. SQL Function Reference

| Function / pattern                                    | What it does                                                                 | Used in                                | Example                                                                                                  |
| ----------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `TRY_CONVERT(date, CONVERT(char(8), DateKey), 112)`   | Converts an integer date key like `20240331` to a SQL `date`. `TRY_CONVERT` returns NULL on failure rather than throwing. | All staging models, all date-key reconstructions | `TRY_CONVERT(date, CONVERT(char(8), 20240331), 112)` → `2024-03-31` |
| `SUM(...) OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` | Window function: running cumulative sum within each partition, ordered by a column. The "J-curve" shape comes from this on signed cashflows. | `int_fund_cashflows_cumulative` | See Layer 5 below |
| `CASE WHEN amount < 0 THEN -amount ELSE 0 END`        | Recasts a signed cashflow into a positive paid-in component (or zero).        | `int_fund_performance_snapshots`, `fact_cashflows` | Splits a signed amount into paid-in vs distribution buckets |
| `CASE WHEN amount > 0 THEN amount ELSE 0 END`         | Recasts a signed cashflow into a positive distribution component (or zero).   | Same                                   | Same                                                                                                    |
| `NULLIF(x, 0)`                                        | Returns NULL if `x = 0`, else returns `x`. Used as a divide-by-zero guard.    | All ratio calculations (DPI/RVPI/TVPI) | `cumul_distributions_chf / NULLIF(cumul_paid_in_chf, 0)` returns NULL when paid-in is zero, not an error. |
| `COALESCE(SUM(x), 0)`                                 | Returns 0 instead of NULL when the SUM is over an empty set (LEFT JOIN with no matching rows). | `int_fund_performance_snapshots`, mart aggregations | Ensures a fund with no cashflows yet shows 0, not NULL. |
| `CAST(x AS decimal(38,10))`                           | Maximum precision decimal. Used to prevent rounding drift in chained ratio arithmetic. | All ratio calculations            | `CAST(cumul_distributions_chf AS decimal(38,10)) / NULLIF(CAST(cumul_paid_in_chf AS decimal(38,10)), 0)` |
| `LEFT JOIN ... AND date_condition`                    | Conditional join that aggregates flows up to a specific snapshot date.        | `int_fund_performance_snapshots`       | `LEFT JOIN cashflows cf ON nav.fund_id = cf.fund_id AND cf.cashflow_date <= nav.valuation_date`           |
| `UNION ALL`                                           | Combines two row-compatible result sets without deduplication.                | `int_fund_irr_inputs` (combines actual cashflows + synthetic terminal NAV row) | `SELECT ... FROM actual_cashflows UNION ALL SELECT ... FROM terminal_nav` |
| `BULK INSERT ... WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001', TABLOCK)` | Fast bulk load from a CSV file directly into a SQL Server table, skipping the header row. | `02_load_raw_tables_from_csv.sql` | See Layer 0 below                                                                                    |
| `TRUNCATE TABLE`                                      | Removes all rows from a table fast (no per-row logging). Used before each `BULK INSERT` for idempotency. | All raw load scripts | `TRUNCATE TABLE raw.cashflows_v7;` |

---

## 7. The dbt Pipeline

The pipeline has 11 models in 4 logical layers. dbt resolves execution order automatically from `ref()` and `source()` calls — this is the **DAG** (Directed Acyclic Graph).

```
Excel CSV exports (10 files)
        │
        ▼  [raw layer — SQL Server tables, BULK INSERT]
raw.funds_v7 / raw.cashflows_v7 / raw.nav_v7 / raw.commitments_v7
raw.investors_v7 / raw.date_dim_v7 / raw.fx_rates_chf_v7
raw.asset_master_v7 / raw.asset_quarterly_snapshot_v7
raw.investor_cashflows_v7
        │
        ▼  [staging layer — dbt views]
stg_funds / stg_cashflows / stg_nav
        │
        ▼  [intermediate layer — dbt views]
int_fund_cashflows
int_fund_cashflows_cumulative   (J-curve backbone)
int_fund_performance_snapshots  (DPI/RVPI/TVPI inputs)
int_fund_irr_inputs             (XIRR-ready cashflow stream)
        │
        ▼  [mart layer — dbt physical tables for dim/fact + view for reporting mart]
dim_fund / dim_date / dim_investor          (3 dimensions, materialized as tables)
fact_cashflows / fact_nav / fact_commitments (3 facts, materialized as tables)
mart_fund_quarterly_performance              (1 reporting view)
        │
        ▼  [Power BI]
Portfolio Overview page · J-Curve & Cashflow page
```

> **dbt macros used:** `{{ source('raw', '<table>_v7') }}` declares an external source table that dbt does not build. `{{ ref('<model>') }}` declares a dependency on another dbt model. The custom `generate_schema_name` macro in `macros/` forces exact schema names (`staging`, `intermediate`, `mart`) instead of dbt's default `<target>_<custom>` concatenation.

---

### Layer 0 — Raw Sources

The 10 raw tables are loaded from CSV files into SQL Server's `raw` schema by the SQL scripts in `ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/02_raw_landing/`:

| Raw table                         | Row count | Role                                  |
| --------------------------------- | --------- | ------------------------------------- |
| `raw.funds_v7`                    | 5         | Fund master                           |
| `raw.investors_v7`                | 11        | LP master                             |
| `raw.commitments_v7`              | 55        | Commitment events                     |
| `raw.cashflows_v7`                | 927       | Fund-level cashflow events            |
| `raw.nav_v7`                      | 156       | Quarterly NAV snapshots               |
| `raw.date_dim_v7`                 | 3,653     | Conformed date spine                  |
| `raw.asset_master_v7`             | 30        | Underlying asset master               |
| `raw.asset_quarterly_snapshot_v7` | 765       | Asset-level quarterly performance     |
| `raw.fx_rates_chf_v7`             | 18,265    | Daily CHF FX rates                    |
| `raw.investor_cashflows_v7`       | 10,004    | LP-level cashflow allocations         |

#### `funds_v7` — input schema (representative subset)

| Column                        | Raw type           | Example                  | Notes                                 |
| ----------------------------- | ------------------ | ------------------------ | ------------------------------------- |
| `FundID`                      | INT                | 1                        | Unique fund identifier                |
| `FundCode`                    | NVARCHAR(50)       | AB1                      | Internal short code                   |
| `FundName`                    | NVARCHAR(255)      | Alpha Buyout I           | Human-readable name                   |
| `VintageYear`                 | INT                | 2014                     | Year of first close                   |
| `Strategy`                    | NVARCHAR(100)      | Buyout                   | Top-level strategy                    |
| `SubStrategy`                 | NVARCHAR(255)      | Mid-market Buyout        | Refinement                            |
| `Geography`                   | NVARCHAR(100)      | Europe                   | Primary investment region             |
| `BaseCurrency`                | NVARCHAR(10)       | EUR                      | Native fund currency                  |
| `ReportingCurrency`           | NVARCHAR(10)       | CHF                      | Reporting currency                    |
| `FundSize`                    | DECIMAL(19,2)      | 800000000.00             | Native currency final-close commitment |
| `FundSizeFXDateKey`           | INT                | 20140630                 | YYYYMMDD                              |
| `FundSizeFXRateToCHF`         | DECIMAL(18,6)      | 1.215000                 | EUR→CHF at final close                |
| `FundSizeCHFAtFinalClose`     | DECIMAL(19,2)      | 972000000.00             | Pre-computed in CHF                   |
| `FirstCloseDateKey` / `FinalCloseDateKey` | INT    | 20140131 / 20140630      | YYYYMMDD                              |
| `MgmtFeeRateIP` / `MgmtFeeRatePostIP` | DECIMAL(10,6) | 0.020000 / 0.015000  | Mgmt fee during/post investment period |
| `CarryRate`                   | DECIMAL(10,6)      | 0.200000                 | GP carried interest                   |
| `PreferredReturnRate`         | DECIMAL(10,6)      | 0.080000                 | LP hurdle rate                        |

#### `cashflows_v7` — input schema (representative subset)

| Column                | Raw type           | Example     | Notes                                          |
| --------------------- | ------------------ | ----------- | ---------------------------------------------- |
| `CashflowID`          | INT                | 1           | PK                                             |
| `FundID`              | INT                | 1           | FK to funds                                    |
| `AssetID`             | INT (NULL)         | NULL or 5   | NULL for fund-level fees/expenses              |
| `DateKey`             | INT                | 20240331    | YYYYMMDD; primary date axis                    |
| `Type`                | NVARCHAR(50)       | CALL        | CALL, DISTRIBUTION, FEE, EXPENSE, ...           |
| `Amount`              | DECIMAL(19,2)      | -1500000.00 | Signed: calls negative, distributions positive |
| `Currency`            | NVARCHAR(10)       | EUR         | Native cashflow currency                       |
| `FXRateToCHF`         | DECIMAL(18,6)      | 1.005000    | At transaction date                            |
| `AmountCHF`           | DECIMAL(19,2)      | -1507500.00 | Pre-computed CHF translation                   |

The pattern repeats for the other 8 raw tables. See `ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/02_raw_landing/01_create_raw_tables.sql` in the GitHub repo for the complete DDL of all 10.

---

### Layer 1 — `stg_funds`

**File:** `models/staging/stg_funds.sql` · **Materialisation:** view

**Purpose:** Take raw `funds_v7` and produce a clean, snake_case, type-safe fund master row. Convert integer date keys into proper SQL `date` values. No business logic, no joins, no aggregation — staging is purely about renaming + type rebuild.

**Key operations:**
- Rename PascalCase columns (`FundID`) to snake_case (`fund_id`)
- Convert integer date keys to SQL dates via `TRY_CONVERT(date, CONVERT(char(8), DateKey), 112)`
- Preserve grain: 1 row = 1 fund

```sql
SELECT
    FundID                          AS fund_id,
    FundCode                        AS fund_code,
    FundName                        AS fund_name,
    VintageYear                     AS vintage_year,
    Strategy                        AS strategy,
    SubStrategy                     AS sub_strategy,
    Geography                       AS geography,
    SectorFocus                     AS sector_focus,
    BaseCurrency                    AS base_currency,
    ReportingCurrency               AS reporting_currency,
    FundSize                        AS fund_size,
    TRY_CONVERT(date, CONVERT(char(8), FundSizeFXDateKey), 112)
                                    AS fund_size_fx_date,
    FundSizeFXRateToCHF             AS fund_size_fx_rate_to_chf,
    FundSizeCHFAtFinalClose         AS fund_size_chf_final_close,
    TRY_CONVERT(date, CONVERT(char(8), FirstCloseDateKey), 112)
                                    AS first_close_date,
    TRY_CONVERT(date, CONVERT(char(8), FinalCloseDateKey), 112)
                                    AS final_close_date,
    InvestmentPeriodYears           AS investment_period_years,
    FundLifeYears                   AS fund_life_years,
    MgmtFeeRateIP                   AS mgmt_fee_rate_ip,
    MgmtFeeRatePostIP               AS mgmt_fee_rate_post_ip,
    CarryRate                       AS carry_rate,
    PreferredReturnRate             AS preferred_return_rate,
    CommitmentStyle                 AS commitment_style,
    Manager                         AS manager,
    Domicile                        AS domicile,
    Status                          AS status,
    ESGArticle                      AS esg_article
FROM raw.funds_v7
```

**Output:** `staging.stg_funds`, view, 5 rows × ~25 columns.

---

### Layer 2 — `stg_cashflows`

**File:** `models/staging/stg_cashflows.sql` · **Materialisation:** view

**Purpose:** Type-safe cleanup of `raw.cashflows_v7`. Same pattern as `stg_funds`: snake_case rename, date-key conversion, no business logic. Preserves the original signed `amount` column (calls negative, distributions positive) — sign re-shaping happens at the intermediate layer.

**Key operations:**
- Snake_case rename
- Three date-key conversions: `cashflow_date_key` (transaction), `notice_date_key`, `due_date_key`
- Both `cashflow_date_key` AS INT (kept for FK purposes downstream) and `cashflow_date` AS proper SQL `date` (for filtering)

**Output:** `staging.stg_cashflows`, view, 927 rows.

---

### Layer 3 — `stg_nav`

**File:** `models/staging/stg_nav.sql` · **Materialisation:** view

**Purpose:** Clean and standardise quarterly NAV snapshots. One row per fund per valuation snapshot.

**Key operations:**
- Snake_case rename of NAV-related fields
- Convert `ValuationDateKey` (INT) to `valuation_date` (DATE)
- Preserve both native (`nav_amount`, `unfunded_commitment`) and CHF (`nav_amount_chf`, `unfunded_commitment_chf`) values for downstream choice

**Output:** `staging.stg_nav`, view, 156 rows.

---

### Layer 4 — `int_fund_cashflows`

**File:** `models/intermediate/int_fund_cashflows.sql` · **Materialisation:** view

**Purpose:** First analytical view that combines staging tables. Joins `stg_cashflows` to `stg_funds` to add fund descriptive attributes (fund_name, vintage_year) onto each cashflow row.

**Why this model exists:** Staging is single-source. Intermediate is the first place business logic and cross-table joins happen. This intermediate is the foundation for the cumulative cashflow series and the J-curve.

**Important financial note:** The raw dataset already stores calls as **negative** and distributions as **positive**. This model preserves that sign convention — it does NOT re-flip signs. (An earlier draft did, which made calls positive by mistake; the bug was caught and fixed during development.)

**Grain:** 1 row = 1 fund cashflow event.

**Output:** `intermediate.int_fund_cashflows`, view, 927 rows × 6 columns (`cashflow_id, fund_id, fund_name, vintage_year, cashflow_date, cashflow_type, signed_amount`).

---

### Layer 5 — `int_fund_cashflows_cumulative`

**File:** `models/intermediate/int_fund_cashflows_cumulative.sql` · **Materialisation:** view

**Purpose:** **The J-curve backbone.** Aggregates same-day transactions per fund, then computes a running cumulative net cashflow per fund chronologically.

**Why two CTEs are needed:** A single fund can have multiple transaction rows on the same date (e.g., investment + management fee + fund expense all on a quarter-end). The cumulative window function needs ONE net daily cashflow per fund per date; if you ran the window function directly over the transaction-grain table, the running total would order arbitrarily within same-date rows.

```sql
WITH daily_cashflows AS (
    SELECT
        fund_id, fund_name, vintage_year, cashflow_date,
        SUM(signed_amount) AS net_cashflow_amount
    FROM {{ ref('int_fund_cashflows') }}
    GROUP BY fund_id, fund_name, vintage_year, cashflow_date
),
cumulative_cashflows AS (
    SELECT
        fund_id, fund_name, vintage_year, cashflow_date, net_cashflow_amount,
        SUM(net_cashflow_amount) OVER (
            PARTITION BY fund_id
            ORDER BY cashflow_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_net_cashflow
    FROM daily_cashflows
)
SELECT * FROM cumulative_cashflows
```

**Window function explanation:**
- `PARTITION BY fund_id` — restart the running total separately for each fund (so funds don't bleed into each other)
- `ORDER BY cashflow_date` — accumulate chronologically from oldest to newest
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — running total from the first row through the current row

**The J-curve shape:** Cumulative net cashflow starts at zero, dips deeply negative as capital calls outpace distributions (the "trough" of the J), then climbs back as distributions arrive, eventually crossing back above zero ("break-even"). For Alpha Buyout I, the trough is around CHF -589M, and the line crosses zero around year 7 of the fund.

**Output:** `intermediate.int_fund_cashflows_cumulative`, view, ~700 rows (one per (fund, date) pair where activity occurred).

---

### Layer 6 — `int_fund_performance_snapshots`

**File:** `models/intermediate/int_fund_performance_snapshots.sql` · **Materialisation:** view

**Purpose:** Build the canonical input for DPI / RVPI / TVPI ratio calculations. Combines NAV snapshots (stock measure) with cumulative cashflows (flow measure) at a quarterly grain. Anchored on NAV's snapshot dates because NAV is a quarter-end stock measure.

**Why this model exists:** NAV is observed at quarter-end. Paid-in capital and distributions are flow measures that must be summed through time up to that quarter-end date. The model uses a `LEFT JOIN ... AND cashflow_date <= valuation_date` pattern to roll up flows per fund per snapshot.

**Cashflow recasting:**
```sql
CASE WHEN amount < 0 THEN -amount ELSE 0 END AS paid_in_amount,
CASE WHEN amount > 0 THEN amount  ELSE 0 END AS distribution_amount,
```

This converts the signed cashflow into separate positive paid-in and distribution buckets, which is what the ratio calculations need.

**Grain:** 1 row = 1 fund × 1 valuation snapshot date.

**Output:** `intermediate.int_fund_performance_snapshots`, view, 156 rows × ~25 columns (carries both native currency and CHF reporting fields).

---

### Layer 7 — `int_fund_irr_inputs`

**File:** `models/intermediate/int_fund_irr_inputs.sql` · **Materialisation:** view

**Purpose:** Prepare the dated cashflow stream needed for IRR / XIRR calculation. Different from DPI/RVPI/TVPI — those are simple ratios; IRR needs a dated cashflow series plus a synthetic "terminal NAV" row inserted at the snapshot date.

**Structure for each (fund, snapshot) pair:**
1. All actual historical cashflows up to the snapshot date (signed amounts, with their actual dates)
2. One synthetic positive cashflow row at the snapshot date equal to `nav_amount_chf` (representing the value the LP would receive if the fund were liquidated at NAV that day)

**SQL pattern:** `UNION ALL` of two queries — one over `stg_cashflows`, one over `stg_nav` with a `CAST('TERMINAL_NAV' AS nvarchar(30)) AS irr_row_type` literal.

**Why XIRR not IRR:** Plain IRR assumes evenly spaced periods. Private markets cashflows happen on irregular real dates. XIRR (date-aware IRR, available in Excel/Power BI/Python) takes a paired list of (amount, date) and computes the annualised internal rate of return over irregular intervals. This model produces exactly that paired list, ready for downstream `=XIRR(amounts, dates)` consumption.

**Output:** `intermediate.int_fund_irr_inputs`, view, ~10,000 rows (most rows are actual historical cashflows replicated per snapshot date).

---

### Layer 8 — Dimensions

Three conformed dimensions, all **materialised as physical tables** (`{{ config(materialized = 'table', schema = 'mart') }}`), placed in the `mart` schema. Physical tables (not views) because Power BI's VertiPaq engine reads them directly and benefits from columnar compression.

#### `dim_fund`

**File:** `models/mart/dimensions/dim_fund.sql` · **Materialisation:** table · **Source:** `staging.stg_funds`

One row per fund. Carries every descriptive fund attribute that downstream visuals might filter or group by: `fund_id` (PK), `fund_code`, `fund_name`, `vintage_year`, `strategy`, `sub_strategy`, `geography`, `sector_focus`, `base_currency`, `reporting_currency`, `fund_size`, `fund_size_chf_final_close`, `first_close_date`, `final_close_date`, `investment_period_years`, `fund_life_years`, `mgmt_fee_rate_ip`, `mgmt_fee_rate_post_ip`, `carry_rate`, `preferred_return_rate`, `commitment_style`, `manager`, `domicile`, `fund_status`, `esg_article`.

5 rows.

#### `dim_date`

**File:** `models/mart/dimensions/dim_date.sql` · **Materialisation:** table · **Source:** `raw.date_dim_v7`

Conformed date dimension covering the full date range of the dataset. PK is `date_id` (the integer YYYYMMDD key, e.g. `20240331`). Carries: `full_date` (proper SQL date), `day_number`, `day_name`, `day_of_week_iso`, `week_of_year`, `month_number`, `month_name`, `month_short`, `quarter_label`, `quarter_number`, `calendar_year`, `year_quarter`, `year_month`, plus boundary flags (`month_start_flag`, `month_end_flag`, `quarter_start_flag`, `quarter_end_flag`, `year_start_flag`, `year_end_flag`, `is_weekend_flag`).

3,653 rows.

#### `dim_investor`

**File:** `models/mart/dimensions/dim_investor.sql` · **Materialisation:** table · **Source:** `raw.investors_v7`

One row per LP. Carries: `investor_id` (PK), `investor_code`, `investor_name`, `investor_type`, `investor_channel`, `region`, `country`, `base_currency`, `commitment_bucket`, `relationship_start_year`, `onboarding_office`, `esg_preference`, `tax_status`, `investor_status`.

11 rows.

---

### Layer 9 — Facts

Three core fact tables, all materialised as physical tables in the `mart` schema. Facts capture the events / measurements: cashflow events (transactions), NAV snapshots (stock measure), and commitment events (LP→fund bridge).

#### `fact_cashflows`

**File:** `models/mart/facts/fact_cashflows.sql` · **Materialisation:** table · **Source:** `staging.stg_cashflows`

**Grain:** 1 row = 1 fund cashflow event.
**PK:** `cashflow_id`
**FKs:** `fund_id → dim_fund`, `date_id → dim_date` (cashflow date — active relationship), `notice_date_id → dim_date` (inactive), `due_date_id → dim_date` (inactive)

**Carries the analytical helper columns:**
- `paid_in_amount` and `paid_in_amount_chf` (CASE WHEN amount < 0 THEN -amount ELSE 0)
- `distribution_amount` and `distribution_amount_chf` (CASE WHEN amount > 0 THEN amount ELSE 0)
- `signed_amount` and `signed_amount_chf` (originals, preserved)

927 rows.

#### `fact_nav`

**File:** `models/mart/facts/fact_nav.sql` · **Materialisation:** table · **Source:** `staging.stg_nav`

**Grain:** 1 row = 1 fund × 1 valuation snapshot date.
**PK:** `nav_id`
**FKs:** `fund_id → dim_fund`, `date_id → dim_date` (the valuation date)

Carries: `valuation_date`, `quarter_end`, `quarter_sequence`, `nav_amount`, `unfunded_commitment`, `currency`, `fx_rate_to_chf`, `nav_amount_chf`, `unfunded_commitment_chf`, `valuation_status`.

156 rows.

#### `fact_commitments`

**File:** `models/mart/facts/fact_commitments.sql` · **Materialisation:** table · **Source:** `raw.commitments_v7`

**Grain:** 1 row = 1 investor commitment event into 1 fund.
**PK:** `commitment_id`
**FKs:** `fund_id → dim_fund`, `investor_id → dim_investor`, `date_id → dim_date` (the commitment date)

Carries: `commitment_date`, `commitment_amount`, `commitment_currency`, `fx_rate_to_chf`, `commitment_amount_chf`, `commitment_pct_of_fund`, `closing_round`, `commitment_status`, `side_letter_flag`, `most_favored_nation_flag`, `co_investment_rights_flag`, `fee_terms_bucket`.

55 rows.

---

### Layer 10 — `mart_fund_quarterly_performance`

**File:** `models/mart/mart_fund_quarterly_performance.sql` · **Materialisation:** view

**Purpose:** The final reporting layer. Combines fact_nav + fact_cashflows + dim_fund + dim_date and exposes pre-computed DPI / RVPI / TVPI ratios in CHF on a quarter-end grain. Power BI consumes this view directly with minimal DAX.

**Why a view (not a table):** This mart is light enough to recompute on each query. Keeping it as a view means it always reflects current dim/fact data without needing a separate refresh step. The performance hit is tolerable at this dataset size.

**Why this is the rebuilt mart:** An earlier version of this mart read directly from `int_fund_performance_snapshots` (the intermediate layer), bypassing the dim/fact backbone. That worked but was an architectural shortcut. The rewritten version (current code) reads from `fact_nav` + `fact_cashflows` + `dim_fund` + `dim_date` — proper Kimball consumption pattern. The legacy version is preserved in `analyses/legacy/mart_fund_quarterly_performance_legacy.sql` for historical reference.

**Key calculations:**

```sql
-- Cumulative paid-in / distributions per snapshot (CHF)
COALESCE(SUM(cashflow.paid_in_amount_chf), 0)        AS cumulative_paid_in_chf,
COALESCE(SUM(cashflow.distribution_amount_chf), 0)   AS cumulative_distributions_chf,

-- DPI = distributions / paid-in
CASE WHEN cumulative_paid_in_chf = 0 THEN NULL
     ELSE CAST(cumulative_distributions_chf AS decimal(38,10))
        / NULLIF(CAST(cumulative_paid_in_chf AS decimal(38,10)), 0)
END AS dpi,

-- RVPI = NAV / paid-in
CASE WHEN cumulative_paid_in_chf = 0 THEN NULL
     ELSE CAST(nav_amount_chf AS decimal(38,10))
        / NULLIF(CAST(cumulative_paid_in_chf AS decimal(38,10)), 0)
END AS rvpi,

-- TVPI = (NAV + distributions) / paid-in   ← parentheses critical
CASE WHEN cumulative_paid_in_chf = 0 THEN NULL
     ELSE CAST(nav_amount_chf + cumulative_distributions_chf AS decimal(38,10))
        / NULLIF(CAST(cumulative_paid_in_chf AS decimal(38,10)), 0)
END AS tvpi,

-- Break-even: total value >= cumulative paid-in
CASE WHEN cumulative_paid_in_chf > 0
      AND nav_amount_chf + cumulative_distributions_chf >= cumulative_paid_in_chf
     THEN 1 ELSE 0
END AS break_even_flag
```

**Output schema (selected columns):** `nav_id`, `fund_id`, `fund_name`, `vintage_year`, `strategy`, `valuation_date`, `quarter_label`, `year_quarter`, `nav_amount_chf`, `unfunded_commitment_chf`, `cumulative_paid_in_chf`, `cumulative_distributions_chf`, `cumulative_net_cashflow_chf`, `total_value_chf`, `value_creation_chf`, `dpi`, `rvpi`, `tvpi`, `break_even_flag`, `paid_in_pct_of_fund_size_chf`, `nav_pct_of_fund_size_chf`.

156 rows (one per (fund, snapshot) pair). The `TVPI = DPI + RVPI` identity holds across all rows within `1e-6` floating-point tolerance.

---

## 8. Business Metrics Rationale

### Why these specific metrics?

| Metric / output                | Business question answered                                                | Definition                                              |
| ------------------------------ | -------------------------------------------------------------------------- | ------------------------------------------------------- |
| **DPI** (Distributions to Paid-In) | How much capital have I gotten back vs put in? Realised return ratio. | `cumulative_distributions / cumulative_paid_in`         |
| **RVPI** (Residual Value to Paid-In) | What's still on the table? Unrealised remaining value ratio.         | `current_nav / cumulative_paid_in`                      |
| **TVPI** (Total Value to Paid-In) | What's the total deal economics, realised + unrealised, per CHF in?  | `(nav + cumulative_distributions) / cumulative_paid_in` |
| **Identity:** TVPI = DPI + RVPI | Sanity check. If broken, something's miscounted.                          | `(D + N) / P = D/P + N/P`                               |
| **Break-even flag**            | Has total value crossed paid-in yet?                                       | `1 if nav + distributions >= paid_in else 0`            |
| **J-curve (cumulative net cashflow)** | What's the funding shape over time? When did the fund cross zero? | `SUM(signed_amount) OVER (PARTITION BY fund_id ORDER BY date)` |
| **XIRR (computed in Power BI)** | Date-aware annualised return.                                              | `XIRR(amounts, dates)` using `int_fund_irr_inputs`      |

### Why CHF and not native currency?

The dataset frames a Geneva-based allocator. All visuals report in CHF for consistent fund-to-fund comparison. Native currency values are preserved in the warehouse (every monetary column has both a native and a `_chf` variant), so analysts can switch back if needed. The default for Power BI visuals is the CHF version.

### Why a star schema and not a flat table?

Power BI's VertiPaq engine is optimised for star schemas. Relationships between the 3 dimensions and 3 facts allow filter propagation: select a strategy in `dim_fund`, the filter automatically flows to `fact_cashflows`, `fact_nav`, and `fact_commitments`. Sub-second response on 11,000+ rows.

A flat table would: bloat with repeated strings (fund_name on every cashflow row), prevent reuse of the date dim across multiple facts, and prevent the model from distinguishing a "fund-level" measure from an "investor-level" measure cleanly.

### Why physical tables for dim/fact, but a view for the mart?

Dim and fact tables are read by Power BI on import. Materializing them as physical tables means VertiPaq imports the columnar storage directly — fast.

The reporting mart `mart_fund_quarterly_performance` is a view because it's lightweight to recompute (small row count, simple SQL) and keeping it as a view means it auto-refreshes whenever the underlying dim/fact tables change. Trading a tiny bit of query latency for always-fresh data.

### Why XIRR and not plain IRR?

Plain IRR assumes equal spacing between cashflows. Private markets cashflows happen on irregular dates: a capital call in March, a distribution in November, a follow-on call the next April. XIRR (the date-aware variant) annualises the actual time gaps. Power BI implements XIRR natively as a DAX function; the dbt pipeline pre-shapes the input via `int_fund_irr_inputs`.

---

## 9. End-to-End Recipe

Step-by-step to rebuild the entire pipeline from scratch.

### Step 1 — Install prerequisites

- SQL Server 2022 Express (download + install with default settings)
- SSMS (download + install)
- Python 3.11+
- Microsoft ODBC Driver 17 for SQL Server (required by `dbt-sqlserver`)
- Power BI Desktop
- VS Code

```bash
pip install dbt-core dbt-sqlserver
dbt --version   # confirm 1.8+
```

### Step 2 — Create the database + schemas

In SSMS, connect to your local SQL Server instance and run:

```
ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/01_platform_setup/01_create_database_and_all_core_schemas.sql
```

This creates the `PrivateMarkets` database and four schemas: `raw`, `staging`, `intermediate`, `mart`. The script is rerunnable (`IF NOT EXISTS` guards).

### Step 3 — Create the 10 raw tables

```
ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/02_raw_landing/01_create_raw_tables.sql
```

DDL for all 10 raw tables. Rerunnable. Note: `date_dim_v7` and `fx_rates_chf_v7` use `NVARCHAR(20)` for flag columns deliberately — earlier versions used `INT` and the bulk load failed because the source CSVs contain mixed-type flag values.

### Step 4 — Update the BULK INSERT paths and load the CSVs

Open `ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/02_raw_landing/02_load_raw_tables_from_csv.sql` and update each `BULK INSERT ... FROM '...'` path to point at your local clone's `OLTP_SourceDataset_as_xlsx_csv/csv/` folder. The SQL Server service account must have read permission on that folder.

Then run the script in SSMS. Expected row counts (also displayed in script 03):

| Raw table                         | Expected rows |
| --------------------------------- | ------------- |
| `raw.funds_v7`                    | 5             |
| `raw.investors_v7`                | 11            |
| `raw.commitments_v7`              | 55            |
| `raw.cashflows_v7`                | 927           |
| `raw.nav_v7`                      | 156           |
| `raw.date_dim_v7`                 | 3,653         |
| `raw.asset_master_v7`             | 30            |
| `raw.asset_quarterly_snapshot_v7` | 765           |
| `raw.fx_rates_chf_v7`             | 18,265        |
| `raw.investor_cashflows_v7`       | 10,004        |

### Step 5 — Validate the raw load

```
ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/02_raw_landing/03_validate_raw_load.sql
```

Confirms row counts, shows the first 10 rows of three key tables, and verifies the `raw` schema contains exactly 10 user tables.

### Step 6 — Configure the dbt profile

Copy `dbt_private_markets/profiles.example.yml` to `~/.dbt/profiles.yml` (Windows: `C:\Users\<you>\.dbt\profiles.yml`) and edit the `server` line for your instance. Then verify:

```bash
cd dbt_private_markets/
dbt debug
```

Expected: `All checks passed!` with `adapter type: sqlserver`, `adapter version: 1.x`, Windows authentication confirmed.

### Step 7 — Run dbt

```bash
dbt run
```

Expected: `PASS=11`. All 11 models build cleanly. The `mart` schema ends up with 3 dim tables, 3 fact tables, and 1 mart view.

### Step 8 — Validate the marts

Run the 7 scripts in `ELT_via_SSMS_sql_server_scripts_pre_and_post_DataModeling/03_post_model_validation/` in numeric order:

| Script | What it checks                                              |
| ------ | ----------------------------------------------------------- |
| 01     | `int_fund_cashflows_cumulative` — running cashflow path     |
| 02     | Confirms `mart.mart_fund_quarterly_performance` exists      |
| 03     | Latest snapshot per fund — should show 5 rows               |
| 04     | IRR input rows for one fund — actual + terminal NAV         |
| 05     | Rebuilt mart sanity check + TVPI = DPI + RVPI identity test |
| 06     | First 1000 rows of mart (full precision)                    |
| 07     | Same but with values rounded to 2 decimals for SSMS display |

### Step 9 — Connect Power BI and refresh

In Power BI Desktop: Get Data → SQL Server → enter your instance → import the relevant mart objects (`mart_fund_quarterly_performance`, `dim_fund`, `dim_date`, `fact_cashflows`, `fact_nav`, `fact_commitments`). Verify the relationships set up in the Model view (or use the existing `.pbix` file if you have it).

Build / refresh the Portfolio Overview and J-Curve & Cashflow report pages.

---

## 10. Lexique / Glossary

**LP** — Limited Partner. The investor in a private fund. Provides capital, has limited liability, doesn't manage day-to-day investment decisions.

**GP** — General Partner. The fund manager. Selects investments, manages the portfolio, charges management fee + carried interest.

**Commitment** — A binding promise by an LP to invest a specified amount of capital into a fund over the fund's investment period. Drawn down via capital calls.

**Capital Call** — A formal request by the GP for the LP to wire in a portion of their commitment. Negative cashflow from the LP perspective; "paid-in capital" once received.

**Paid-in capital (PIC)** — Cumulative capital actually contributed to the fund. Usually less than total commitment until late in the investment period.

**Unfunded commitment** — Commitment minus paid-in. Capital the LP has promised but not yet wired.

**Distribution** — A payment from the fund back to the LP. Comes from realised exits, dividends, recapitalisations, or interest payments. Positive cashflow from the LP perspective.

**NAV (Net Asset Value)** — The valuation of the fund's holdings at a point in time. Stock measure. Quarterly observed; "fair value" assessment by the GP.

**DPI** — Distributions to Paid-In. Realised return ratio. DPI = 1.0 means LP has gotten back in cash exactly what they put in. DPI > 1.0 means realised gains.

**RVPI** — Residual Value to Paid-In. Unrealised return ratio. RVPI = (current NAV) / (cumulative paid-in). RVPI = 0 at fund liquidation.

**TVPI** — Total Value to Paid-In. Combined realised + unrealised return ratio. Identity: **TVPI = DPI + RVPI**. Industry-standard headline performance metric.

**MOIC** — Multiple on Invested Capital. Similar to TVPI but typically gross (pre-fee, pre-carry) and at the deal/asset level rather than fund level. Used by GPs internally.

**IRR** — Internal Rate of Return. Annualised dollar-weighted return. Solves for the discount rate that makes NPV = 0.

**XIRR** — Date-aware IRR. Handles irregular cashflow spacing. Used in private markets because real cashflows aren't evenly spaced.

**J-curve** — The visual shape of cumulative net cashflow over a fund's life: starts at zero, dips deeply negative as calls outpace distributions, then climbs back as exits start, eventually crossing zero ("break-even") and trending positive.

**Vintage** — The year a fund holds its first close. Used for cohort comparisons (vintage 2014 buyouts vs vintage 2018 buyouts).

**eFront / Allvue / iLEVEL** — Major fund-administration platforms. Operational systems-of-record for capital activity, NAV booking, LP reporting. Not analytics platforms by design — they're where the numbers are *recorded*, not where they're *analysed*.

**Star schema** — Dimensional modelling pattern: one (or several) central fact table(s) joined to multiple dimension tables via foreign keys. Optimised for analytical queries and BI tool semantic models.

**Fact table** — Centre of a star schema. Contains measurable, additive business events (cashflows, NAV snapshots, commitments). Each row = one event. Foreign keys point to dimension tables.

**Dimension table** — Descriptive context for the fact table. Filtering / grouping / labelling attributes (fund name, strategy, vintage, region).

**Conformed dimension** — A dimension that's reusable across multiple fact tables in the same warehouse. `dim_date` is conformed: it's joined to fact_cashflows, fact_nav, AND fact_commitments using the same date_id key.

**Degenerate dimension** — A dimension attribute kept on the fact table itself rather than in a separate dim table (e.g., a transaction reference number). Used when the column has too many unique values for useful grouping.

**Grain** — The level of detail of a fact table. `fact_cashflows` has grain "1 row = 1 fund cashflow event". Always defined precisely; mixing grains breaks aggregations.

**Window function** — A SQL construct that computes values across rows related to the current row without collapsing them (unlike GROUP BY). `SUM(...) OVER (PARTITION BY ... ORDER BY ...)` is the fundamental running-total pattern.

**dbt (data build tool)** — Open-source SQL transformation framework. Write SELECT queries; dbt handles CREATE/DROP/REFRESH, dependency resolution, and documentation. Uses Jinja-SQL templating.

**DAG** — Directed Acyclic Graph. In dbt, the dependency graph of all models. dbt resolves execution order from `ref()` calls. No circular dependencies allowed.

**CTE** — Common Table Expression. Named temporary result set defined with `WITH`. Makes long SQL readable by breaking it into named steps.

**`ref()` / `source()`** — dbt Jinja macros. `ref('model_name')` declares a dependency on another dbt model. `source('schema', 'table')` declares a dependency on an external source table outside dbt's build scope. Both build the DAG.

**Materialisation** — How a dbt model is persisted in the database. Options: `view` (no data stored, recomputed on query), `table` (rows physically stored), `incremental` (append new rows only), `ephemeral` (CTE inlined into downstream models, no DB object created).

**`generate_schema_name` macro** — Custom Jinja macro that overrides dbt's default schema-naming. Without it, dbt concatenates `<target_schema>_<custom_schema>` (e.g., `staging_intermediate`). With it, exact schema names are used.

**SQL Server `BULK INSERT`** — Fast bulk load command. Loads a delimited file directly into a table without per-row logging. Typically 10–100× faster than row-by-row INSERTs.

**`TRUNCATE TABLE`** — Removes all rows from a table without per-row logging or generating undo records. Used before each `BULK INSERT` for idempotent reloads. Cannot be filtered (no WHERE).

**`TRY_CONVERT(...)`** — T-SQL function. Like `CONVERT` but returns NULL on conversion failure rather than throwing an error. Essential when raw source data has mixed types.

**Power BI Import mode** — Power BI loads data into VertiPaq (its in-memory columnar engine) at refresh time. Fast for queries; requires periodic refresh. Alternative: DirectQuery (queries hit SQL Server live, no import).

**VertiPaq** — Power BI's in-memory columnar database engine. Stores imported data. Optimised for star-schema queries and DAX measures.

**DAX** — Data Analysis Expressions. Power BI's formula language for calculated measures, columns, and table functions. Analogous to Excel formulas but for analytical data models.

**`USERELATIONSHIP()`** — DAX function that activates an inactive relationship for the duration of a measure's calculation. Used when a fact table has multiple FKs to the same dim (e.g., fact_cashflows has three date FKs to dim_date).

**Idempotent script** — A script that produces the same end state regardless of how many times it's run. The raw-load scripts use `TRUNCATE + BULK INSERT` so reloading the same CSV doesn't create duplicates.

**OLTP vs OLAP** — Online Transaction Processing vs Online Analytical Processing. OLTP is row-oriented, optimised for many small writes (the source platforms). OLAP is column-oriented, optimised for large analytical reads (the warehouse). The pipeline in this project is the bridge: OLTP-style source (Excel) → OLAP-style warehouse (star schema in SQL Server) → BI consumption (Power BI).

---

*Private Markets Analytics Pipeline · Self-Study Guide · Built May 2026 · Independent portfolio project · For interview preparation and project documentation*
