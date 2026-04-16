-- Grain: one row per loan_id (active and restructured loans only)
-- Logic: Classifies each loan into a delinquency bucket based on max_days_past_due
--        and assigns the corresponding IFRS 9 stage.
--
-- Delinquency buckets (CA-02):
--   current  : max_days_past_due = 0
--   1_30     : 1 <= max_days_past_due <= 30
--   31_60    : 31 <= max_days_past_due <= 60
--   61_90    : 61 <= max_days_past_due <= 90
--   over_90  : max_days_past_due > 90
--
-- IFRS 9 stages:
--   Stage 1 (performing)     : current, 1_30
--   Stage 2 (underperforming): 31_60, 61_90
--   Stage 3 (non-performing) : over_90
--
-- Only loans with loan_status IN ('active', 'restructured') are included (CA-01).
{{
    config(
        materialized='ephemeral'
    )
}}

with loans as (

    select
        loan_id,
        customer_id,
        product_type,
        outstanding_balance,
        loan_status
    from {{ ref('stg_core_banking__loans') }}
    where loan_status in (
        {%- for status in var('active_loan_statuses') %}
            '{{ status }}'{% if not loop.last %},{% endif %}
        {%- endfor %}
    )

),

max_dpd as (

    select
        loan_id,
        max_days_past_due
    from {{ ref('int_loan__max_days_past_due') }}

),

classified as (

    select
        l.loan_id,
        l.customer_id,
        l.product_type,
        l.outstanding_balance,
        l.loan_status,
        m.max_days_past_due,

        case
            when m.max_days_past_due = 0             then 'current'
            when m.max_days_past_due between 1 and 30  then '1_30'
            when m.max_days_past_due between 31 and 60 then '31_60'
            when m.max_days_past_due between 61 and 90 then '61_90'
            else 'over_90'
        end                                               as delinquency_bucket,

        case
            when m.max_days_past_due between 0 and 30  then 1
            when m.max_days_past_due between 31 and 90 then 2
            else 3
        end                                               as ifrs9_stage

    from loans l
    inner join max_dpd m
        on l.loan_id = m.loan_id

),

final as (

    select * from classified

)

select * from final
