select
    card_id,
    card_holder_name,
    bin,
    last_four,
    card_type,
    card_network,
    currency_code,
    issued_date,
    card_status
from {{ source('payledger_raw', 'raw_card_master') }}
