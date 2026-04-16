-- Grain: one row per loan_id
-- Logic: For each loan, compute the maximum days_past_due across all
--        overdue unpaid/partial installments where due_date <= today.
--        Loans with no overdue payments get max_days_past_due = 0.
--
-- This implements CA-02: "uses the highest days_past_due of overdue
-- unpaid installments" as the basis for delinquency band classification.
{{
    config(
        materialized='ephemeral'
    )
}}

with payments as (

    select
        loan_id,
        days_past_due
    from {{ ref('stg_core_banking__loan_payments') }}
    where
        payment_status in ('unpaid', 'partial')
        and due_date <= current_date

),

loans as (

    select loan_id
    from {{ ref('stg_core_banking__loans') }}

),

max_dpd_per_loan as (

    select
        l.loan_id,
        coalesce(max(p.days_past_due), 0) as max_days_past_due

    from loans l
    left join payments p
        on l.loan_id = p.loan_id

    group by l.loan_id

),

final as (

    select * from max_dpd_per_loan

)

select * from final
