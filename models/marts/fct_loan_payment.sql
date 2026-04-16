-- Grain: one row per payment_id
-- Implements CA-05: excludes orphan payments (payments without a matching loan)
-- Incremental strategy: delete+insert by unique_key payment_id
-- Incremental filter: loaded_at > max(loaded_at) in existing table
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='payment_id',
        on_schema_change='append_new_columns'
    )
}}

{% if is_incremental() %}
with incremental_cutoff as (
    select max(loaded_at) as max_loaded_at from {{ this }}
),
{% else %}
with
{% endif %}

payments as (

    select
        payment_id,
        loan_id,
        due_date,
        payment_date,
        amount_due,
        amount_paid,
        principal_component,
        interest_component,
        days_past_due,
        payment_status,
        loaded_at

    from {{ ref('stg_core_banking__loan_payments') }}

    {% if is_incremental() %}
    where loaded_at > (select max_loaded_at from incremental_cutoff)
    {% endif %}

),

-- Exclude orphan payments (CA-05): payments with no matching loan in the loans table
orphan_payment_ids as (

    select payment_id
    from {{ ref('int_dq__orphan_payments') }}

),

valid_payments as (

    select p.*
    from payments p
    where p.payment_id not in (select payment_id from orphan_payment_ids)

),

enriched as (

    select
        payment_id,
        loan_id,
        due_date,
        payment_date,
        amount_due,
        amount_paid,
        principal_component,
        interest_component,
        days_past_due,
        payment_status,
        case
            when days_past_due > 0 then true
            else false
        end as is_overdue

    from valid_payments

),

final as (

    select * from enriched

)

select * from final
