-- MetricFlow time spine required by the Semantic Layer for all metric time operations.
-- Covers from 2022-01-01 (start of Temenos data per requirements) through 2030-12-31.
-- Uses dbt_utils.date_spine for cross-warehouse portability (BigQuery, Snowflake, Databricks, Redshift, DuckDB).
{{ config(materialized='table') }}

{{
  dbt_utils.date_spine(
    datepart="day",
    start_date="cast('2022-01-01' as date)",
    end_date="cast('2030-12-31' as date)"
  )
}}
