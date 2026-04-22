with source as (

    select * from {{ source('core_banking', 'loan_payments') }}

),

renamed as (

    select
        cast(payment_id as string)                                as payment_id,
        cast(loan_id as string)                                   as loan_id,
        cast(due_date as date)                                     as due_date,
        cast(payment_date as date)                                 as payment_date,
        cast(amount_due as double)                                as amount_due,
        cast(amount_paid as double)                               as amount_paid,
        cast(principal_component as double)                       as principal_component,
        cast(interest_component as double)                        as interest_component,
        coalesce(cast(days_past_due as integer), 0)                as days_past_due,
        cast(payment_status as string)                            as payment_status,
        cast(loaded_at as timestamp)                               as loaded_at

    from source

),

final as (

    select * from renamed

)

select * from final
