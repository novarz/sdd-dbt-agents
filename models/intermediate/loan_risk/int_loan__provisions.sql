-- Grain: one row per loan_id
-- Logic: Joins each loan's delinquency bucket with the IFRS 9 provision rates seed
--        to calculate provision_amount = outstanding_balance * provision_rate.
--        Provision rates are NOT hardcoded — they come from the ifrs9_provision_rates seed (CA-04).
{{
    config(
        materialized='ephemeral'
    )
}}

with delinquency_bands as (

    select
        loan_id,
        customer_id,
        product_type,
        outstanding_balance,
        loan_status,
        max_days_past_due,
        delinquency_bucket,
        ifrs9_stage

    from {{ ref('int_loan__delinquency_bands') }}

),

provision_rates as (

    select
        delinquency_bucket,
        provision_rate

    from {{ ref('ifrs9_provision_rates') }}

),

provisioned as (

    select
        d.loan_id,
        d.customer_id,
        d.product_type,
        d.outstanding_balance,
        d.loan_status,
        d.max_days_past_due,
        d.delinquency_bucket,
        d.ifrs9_stage,
        p.provision_rate,
        d.outstanding_balance * p.provision_rate as provision_amount

    from delinquency_bands d
    inner join provision_rates p
        on d.delinquency_bucket = p.delinquency_bucket

),

final as (

    select * from provisioned

)

select * from final
