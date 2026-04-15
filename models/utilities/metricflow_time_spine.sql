-- MetricFlow time spine required by the Semantic Layer for all metric time operations.
-- Covers from 2022-01-01 (start of Temenos data per requirements) through current date.
-- Uses DuckDB native generate_series for day-level granularity.
{{
    config(
        materialized='table'
    )
}}

select
    cast(generate_series as date) as date_day
from generate_series(
    cast('2022-01-01' as date),
    cast(current_date as date),
    interval '1 day'
)
