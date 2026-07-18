select distinct
    currency_code
from {{ source('payledger_raw', 'raw_transactions') }}
