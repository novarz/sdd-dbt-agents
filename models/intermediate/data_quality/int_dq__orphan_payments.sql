-- Grain: one row per payment_id
-- Logic: Identifies payments that cannot be linked to a known loan.
--        These are data quality anomalies captured for auditing (CA-05).
--        Orphan payments are EXCLUDED from all metric calculations.
--        This model is for audit purposes only — not for downstream business logic.
{{
    config(
        materialized='table'
    )
}}

with payments as (

    select
        payment_id,
        loan_id,
        due_date,
        payment_date,
        amount_due,
        amount_paid,
        days_past_due,
        payment_status,
        loaded_at

    from {{ ref('stg_core_banking__loan_payments') }}

),

loans as (

    select loan_id
    from {{ ref('stg_core_banking__loans') }}

),

orphan_payments as (

    select
        p.payment_id,
        p.loan_id                   as orphan_loan_id,
        p.due_date,
        p.payment_date,
        p.amount_due,
        p.amount_paid,
        p.days_past_due,
        p.payment_status,
        p.loaded_at,
        current_timestamp           as detected_at

    from payments p
    left join loans l
        on p.loan_id = l.loan_id

    where l.loan_id is null

),

final as (

    select * from orphan_payments

)

select * from final
