with source as (

    select * from {{ source('core_banking', 'loans') }}

),

renamed as (

    select
        cast(loan_id as string)             as loan_id,
        cast(customer_id as string)         as customer_id,
        cast(account_id as string)          as account_id,
        cast(product_type as string)        as product_type,
        cast(origination_date as date)       as origination_date,
        cast(maturity_date as date)          as maturity_date,
        cast(original_amount as numeric)     as original_amount,
        cast(outstanding_balance as numeric) as outstanding_balance,
        cast(interest_rate as numeric)       as interest_rate,
        cast(collateral_value as numeric)    as collateral_value,
        cast(loan_status as string)         as loan_status,
        cast(risk_rating as string)         as risk_rating,
        cast(loaded_at as timestamp)         as loaded_at,

        -- Loan-to-value: meaningful only for mortgages with collateral
        cast(outstanding_balance as numeric)
            / nullif(cast(collateral_value as numeric), 0) as loan_to_value

    from source
    where loan_status is not null

),

final as (

    select * from renamed

)

select * from final
