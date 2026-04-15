with source as (

    select * from {{ source('core_banking', 'customers') }}

),

renamed as (

    select
        cast(customer_id as varchar)        as customer_id,
        cast(customer_type as varchar)      as customer_type,
        cast(segment as varchar)            as segment,
        cast(branch_id as varchar)          as branch_id,
        cast(country as varchar)            as country,
        cast(registration_date as date)     as registration_date,
        cast(is_active as boolean)          as is_active,
        cast(loaded_at as timestamp)        as loaded_at

    from source
    where is_active = true

),

final as (

    select * from renamed

)

select * from final
