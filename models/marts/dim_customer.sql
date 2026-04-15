-- Grain: one row per customer_id
-- Source: stg_core_banking__customers joined with stg_reference_data__branches
--         to enrich with branch_name, region, zone
-- Contract enforced: see _marts__models.yml
with customers as (

    select
        customer_id,
        customer_type,
        segment,
        branch_id,
        country,
        registration_date

    from {{ ref('stg_core_banking__customers') }}

),

branches as (

    select
        branch_id,
        branch_name,
        region,
        zone

    from {{ ref('stg_reference_data__branches') }}

),

enriched as (

    select
        c.customer_id,
        c.customer_type,
        c.segment,
        c.branch_id,
        b.branch_name,
        b.region,
        b.zone,
        c.country,
        c.registration_date

    from customers c
    left join branches b
        on c.branch_id = b.branch_id

),

final as (

    select * from enriched

)

select * from final
