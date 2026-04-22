with source as (

    select * from {{ source('reference_data', 'branches') }}

),

renamed as (

    select
        cast(branch_id as string)    as branch_id,
        cast(branch_name as string)  as branch_name,
        cast(region as string)       as region,
        cast(zone as string)         as zone,
        cast(is_active as boolean)    as is_active

    from source
    where is_active = true

),

final as (

    select * from renamed

)

select * from final
