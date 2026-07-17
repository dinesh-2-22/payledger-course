-- dbt version of Module 3's stg_transactions: same shape, just declared as a
-- dbt model instead of a hand-written CREATE TABLE + MERGE stored procedure.

select
    transaction_id,
    card_id,
    merchant_id,
    transaction_type,
    amount,
    currency_code,
    transaction_timestamp,
    auth_status,
    mcc_code,
    entry_mode,
    is_international,
    _loaded_at as source_loaded_at
from {{ source('payledger_raw', 'raw_transactions') }}
