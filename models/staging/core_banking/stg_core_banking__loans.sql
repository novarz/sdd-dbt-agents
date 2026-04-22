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
        cast(original_amount as double)     as original_amount,
        cast(outstanding_balance as double) as outstanding_balance,
        cast(interest_rate as double)       as interest_rate,
        cast(collateral_value as double)    as collateral_value,
        cast(loan_status as string)         as loan_status,
        cast(risk_rating as string)         as risk_rating,
        cast(loaded_at as timestamp)         as loaded_at,

        -- Loan-to-value: meaningful only for mortgages with collateral
        cast(outstanding_balance as double)
            / nullif(cast(collateral_value as double), 0) as loan_to_value

    from source
    where loan_status is not null

),

final as (

    select * from renamed

)

select * from final
