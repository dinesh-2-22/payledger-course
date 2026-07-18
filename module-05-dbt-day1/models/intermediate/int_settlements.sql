-- dbt version of Module 3's int_settlements: nets gateway retries by keeping
-- only the final (latest) gateway event per transaction_id.

with ranked as (
    select
        transaction_id,
        settlement_amount,
        gateway_timestamp,
        row_number() over (
            partition by transaction_id
            order by gateway_timestamp desc
        ) as rn
    from {{ ref('stg_gateway_log') }}
)

select
    transaction_id,
    settlement_amount,
    gateway_timestamp as settled_at
from ranked
where rn = 1
  and settlement_amount is not null
