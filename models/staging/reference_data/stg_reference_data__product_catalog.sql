with source as (

    select * from {{ source('reference_data', 'product_catalog') }}

),

renamed as (

    select
        cast(product_type as string)      as product_type,
        cast(product_name as string)      as product_name,
        cast(product_category as string)  as product_category,
        cast(max_ltv as double)           as max_ltv,
        cast(min_interest_rate as double) as min_interest_rate,
        cast(max_term_months as integer)   as max_term_months

    from source

),

final as (

    select * from renamed

)

select * from final
