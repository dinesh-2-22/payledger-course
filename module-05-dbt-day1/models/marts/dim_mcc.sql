select distinct
    mcc_code,
    mcc_description
from {{ source('payledger_raw', 'raw_merchant_master') }}
