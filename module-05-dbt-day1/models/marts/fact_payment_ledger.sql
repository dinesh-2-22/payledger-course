-- dbt version of Module 3's fact_payment_ledger. Grain: one row per settled
-- transaction. The inner joins to int_settlements and int_fees *are* the
-- grain filter, same as the hand-written version.

select
    hash(ite.transaction_id) as payment_ledger_key,
    ite.transaction_id,
    ite.transaction_timestamp as transaction_ts,
    ite.card_id,
    ite.merchant_id,
    ite.mcc_code,
    ite.currency_code,
    ite.transaction_type,
    ite.entry_mode,
    ite.auth_status,
    ite.is_international,
    iff(ite.transaction_type ilike '%REFUND%', -abs(ite.amount), abs(ite.amount)) as gross_amount,
    ist.settlement_amount,
    ifz.interchange_fee,
    ifz.scheme_fee,
    ist.settlement_amount - ifz.interchange_fee - ifz.scheme_fee as net_amount,
    iff(dm.transaction_id is not null, true, false) as is_disputed,
    current_timestamp() as dw_load_timestamp
from {{ ref('int_transactions_enriched') }} ite
join {{ ref('int_settlements') }} ist
    on ite.transaction_id = ist.transaction_id
join {{ ref('int_fees') }} ifz
    on ite.transaction_id = ifz.transaction_id
left join {{ source('payledger_raw', 'dispute_memos') }} dm
    on ite.transaction_id = dm.transaction_id
