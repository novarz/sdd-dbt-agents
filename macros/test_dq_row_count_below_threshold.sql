-- Custom generic test: asserts that the row count of a referenced DQ audit model
-- does not exceed a given threshold. Intended for data quality audit tables such as
-- int_dq__orphan_payments and int_dq__orphan_loans.
--
-- Usage:
--   tests:
--     - dq_row_count_below_threshold:
--         dq_model: ref('int_dq__orphan_payments')
--         threshold: 1000
--         severity: warn
--
-- Traceability: CA-05 / T-22

{% test dq_row_count_below_threshold(model, dq_model, threshold) %}

with dq_counts as (

    select count(*) as row_count
    from {{ dq_model }}

)

select row_count
from dq_counts
where row_count > {{ threshold }}

{% endtest %}
