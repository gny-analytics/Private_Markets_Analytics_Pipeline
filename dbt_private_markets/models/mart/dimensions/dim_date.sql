{{ config(
    materialized = 'table',
    schema = 'mart'
) }}

/*
Model: dim_date

Purpose:
Create the conformed date dimension.

Why this model exists:
Cashflows, commitments, NAV snapshots, and later investor cashflows all need a
shared analytical calendar.

Grain:
1 row = 1 calendar date

Source:
raw.date_dim_v7

Primary key:
date_id
*/

SELECT

    /*
    Primary key.
    */
    DateKey AS date_id,

    /*
    Full calendar date.
    */
    TRY_CONVERT(date, CONVERT(char(8), DateKey), 112) AS full_date,

    /*
    Day attributes.
    */
    DayNumber AS day_number,
    DayName AS day_name,
    DayOfWeekISO AS day_of_week_iso,
    WeekOfYear AS week_of_year,

    /*
    Month attributes.
    */
    [Month] AS month_number,
    MonthName AS month_name,
    MonthShort AS month_short,

    /*
    Quarter and year attributes.
    */
    Quarter AS quarter_label,
    QuarterNum AS quarter_number,
    [Year] AS calendar_year,
    YearQuarter AS year_quarter,
    YearMonth AS year_month,

    /*
    Period boundary flags.
    */
    MonthStartFlag AS month_start_flag,
    MonthEndFlag AS month_end_flag,
    QuarterStartFlag AS quarter_start_flag,
    QuarterEndFlag AS quarter_end_flag,
    YearStartFlag AS year_start_flag,
    YearEndFlag AS year_end_flag,
    IsWeekendFlag AS is_weekend_flag

FROM raw.date_dim_v7
