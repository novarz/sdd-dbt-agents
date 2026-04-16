with source as (

    select * from {{ source('reference_data', 'product_catalog') }}

),

renamed as (

    select
        cast(product_type as varchar)      as product_type,
        cast(product_name as varchar)      as product_name,
        cast(product_category as varchar)  as product_category,
        cast(max_ltv as numeric)           as max_ltv,
        cast(min_interest_rate as numeric) as min_interest_rate,
        cast(max_term_months as integer)   as max_term_months

    from source

),

final as (

    select * from renamed

)

select * from final
