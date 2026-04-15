with source as (

    select * from {{ source('reference_data', 'branches') }}

),

renamed as (

    select
        cast(branch_id as varchar)    as branch_id,
        cast(branch_name as varchar)  as branch_name,
        cast(region as varchar)       as region,
        cast(zone as varchar)         as zone,
        cast(is_active as boolean)    as is_active

    from source
    where is_active = true

),

final as (

    select * from renamed

)

select * from final
