-- CI test trigger #2: harmless comment, no logic change
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
