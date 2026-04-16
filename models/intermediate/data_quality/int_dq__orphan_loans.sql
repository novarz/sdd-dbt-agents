-- Grain: one row per loan_id
-- Logic: Identifies loans that cannot be linked to a known customer.
--        These are data quality anomalies captured for auditing (CA-05).
--        Orphan loans are EXCLUDED from all metric calculations.
--        This model is for audit purposes only — not for downstream business logic.
{{
    config(
        materialized='table'
    )
}}

with loans as (

    select
        loan_id,
        customer_id,
        product_type,
        origination_date,
        outstanding_balance,
        loan_status,
        loaded_at

    from {{ ref('stg_core_banking__loans') }}

),

customers as (

    select customer_id
    from {{ ref('stg_core_banking__customers') }}

),

orphan_loans as (

    select
        l.loan_id,
        l.customer_id               as orphan_customer_id,
        l.product_type,
        l.origination_date,
        l.outstanding_balance,
        l.loan_status,
        l.loaded_at,
        current_timestamp           as detected_at

    from loans l
    left join customers c
        on l.customer_id = c.customer_id

    where c.customer_id is null

),

final as (

    select * from orphan_loans

)

select * from final
