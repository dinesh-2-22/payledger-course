select
    merchant_id,
    merchant_name,
    merchant_country,
    merchant_city,
    onboarded_date,
    merchant_status
from {{ source('payledger_raw', 'raw_merchant_master') }}
