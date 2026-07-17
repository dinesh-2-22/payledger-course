-- dbt version of Module 3's stg_gateway_log: same shape, just declared as a
-- dbt model instead of a hand-written CREATE TABLE + MERGE stored procedure.

select
    gateway_log_id,
    transaction_id,
    gateway_name,
    auth_code,
    response_code,
    response_message,
    gateway_timestamp,
    settlement_amount,
    interchange_fee,
    scheme_fee,
    _loaded_at as source_loaded_at
from {{ source('payledger_raw', 'raw_gateway_log') }}
