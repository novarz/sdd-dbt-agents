-- Grain: one row per loan_id
-- Source: stg_core_banking__loans enriched with stg_reference_data__product_catalog
-- Contract enforced: see _marts__models.yml
with loans as (

    select
        loan_id,
        customer_id,
        account_id,
        product_type,
        origination_date,
        maturity_date,
        original_amount,
        interest_rate,
        collateral_value,
        loan_to_value,
        loan_status,
        risk_rating

    from {{ ref('stg_core_banking__loans') }}

),

product_catalog as (

    select
        product_type,
        product_name,
        product_category,
        max_ltv,
        max_term_months

    from {{ ref('stg_reference_data__product_catalog') }}

),

enriched as (

    select
        l.loan_id,
        l.customer_id,
        l.account_id,
        l.product_type,
        p.product_name,
        p.product_category,
        l.origination_date,
        l.maturity_date,
        l.original_amount,
        l.interest_rate,
        l.collateral_value,
        l.loan_to_value,
        l.loan_status,
        l.risk_rating

    from loans l
    left join product_catalog p
        on l.product_type = p.product_type

),

final as (

    select * from enriched

)

select * from final
