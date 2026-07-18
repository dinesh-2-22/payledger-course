-- dbt version of Module 3's int_fees: same final-event-per-transaction
-- derivation as int_settlements, kept separate because it answers a
-- different business question (fee attribution vs. settlement amount).

with ranked as (
    select
        transaction_id,
        interchange_fee,
        scheme_fee,
        gateway_timestamp,
        row_number() over (
            partition by transaction_id
            order by gateway_timestamp desc
        ) as rn
    from {{ ref('stg_gateway_log') }}
)

select
    transaction_id,
    interchange_fee,
    scheme_fee
from ranked
where rn = 1
