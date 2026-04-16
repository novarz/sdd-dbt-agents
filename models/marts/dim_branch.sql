-- Grain: one row per branch_id
-- Source: stg_reference_data__branches (active branches only)
-- Contract enforced: see _marts__models.yml
with branches as (

    select
        branch_id,
        branch_name,
        region,
        zone

    from {{ ref('stg_reference_data__branches') }}

),

final as (

    select * from branches

)

select * from final
