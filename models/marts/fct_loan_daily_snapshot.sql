-- Grain: one row per loan_id per snapshot_date
-- Implements CA-01 (NPL), CA-02 (delinquency buckets), CA-03 (daily snapshot), CA-04 (provisions)
-- Only includes loans with loan_status IN ('active', 'restructured')
-- Incremental strategy: delete+insert by unique_key [loan_id, snapshot_date]
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['loan_id', 'snapshot_date'],
        on_schema_change='append_new_columns'
    )
}}

with provisions as (

    select
        loan_id,
        customer_id,
        product_type,
        outstanding_balance,
        loan_status,
        max_days_past_due,
        delinquency_bucket,
        ifrs9_stage,
        provision_rate,
        provision_amount

    from {{ ref('int_loan__provisions') }}

),

dim_customer as (

    select
        customer_id,
        branch_id,
        segment

    from {{ ref('dim_customer') }}

),

snapshot_base as (

    select
        p.loan_id,
        cast(current_date as date)              as snapshot_date,
        p.customer_id,
        dc.branch_id,
        p.product_type,
        dc.segment,
        p.outstanding_balance,
        cast(p.max_days_past_due as integer)    as max_days_past_due,
        p.delinquency_bucket,
        cast(p.ifrs9_stage as integer)          as ifrs9_stage,
        p.provision_rate,
        p.provision_amount,
        case
            when p.delinquency_bucket = 'over_90' then true
            else false
        end                                     as is_npl

    from provisions p
    left join dim_customer dc
        on p.customer_id = dc.customer_id

    {% if is_incremental() %}
    -- In incremental mode, only process loans whose snapshot_date equals today.
    -- The delete+insert strategy removes today's existing rows before re-inserting.
    where cast(current_date as date) >= (select max(snapshot_date) from {{ this }})
    {% endif %}

),

final as (

    select * from snapshot_base

)

select * from final
