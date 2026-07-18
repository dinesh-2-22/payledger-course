select
    st.transaction_id,
    st.transaction_timestamp,
    st.card_id,
    cm.card_holder_name,
    cm.card_type,
    cm.card_network,
    st.merchant_id,
    mm.merchant_name,
    st.mcc_code,
    mm.mcc_description,
    mm.merchant_country,
    mm.merchant_city,
    st.currency_code,
    st.transaction_type,
    st.entry_mode,
    st.auth_status,
    st.is_international,
    st.amount
from {{ ref('stg_transactions') }} st
join {{ source('payledger_raw', 'raw_card_master') }} cm
    on st.card_id = cm.card_id
join {{ source('payledger_raw', 'raw_merchant_master') }} mm
    on st.merchant_id = mm.merchant_id
