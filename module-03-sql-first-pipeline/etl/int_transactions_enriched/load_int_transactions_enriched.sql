/* ============================================================================
   PayLedger course - Module 3: sp_load_int_transactions_enriched
   ----------------------------------------------------------------------------
   stg_transactions + descriptive attributes from the raw masters (card,
   merchant). Full MERGE over all of stg_transactions each run -- at this
   data volume there's no need for the watermark pattern here; that's reserved
   for the raw -> staging hop where the source keeps growing daily.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE PROCEDURE sp_load_int_transactions_enriched()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_merged INTEGER DEFAULT 0;
BEGIN
    MERGE INTO int_transactions_enriched tgt
    USING (
        SELECT
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
        FROM stg_transactions st
        JOIN PAYLEDGER_RAW.raw_card_master cm ON st.card_id = cm.card_id
        JOIN PAYLEDGER_RAW.raw_merchant_master mm ON st.merchant_id = mm.merchant_id
    ) src
    ON tgt.transaction_id = src.transaction_id
    WHEN MATCHED THEN UPDATE SET
        transaction_timestamp = src.transaction_timestamp,
        card_id               = src.card_id,
        card_holder_name      = src.card_holder_name,
        card_type             = src.card_type,
        card_network          = src.card_network,
        merchant_id           = src.merchant_id,
        merchant_name         = src.merchant_name,
        mcc_code              = src.mcc_code,
        mcc_description       = src.mcc_description,
        merchant_country      = src.merchant_country,
        merchant_city         = src.merchant_city,
        currency_code         = src.currency_code,
        transaction_type      = src.transaction_type,
        entry_mode            = src.entry_mode,
        auth_status           = src.auth_status,
        is_international      = src.is_international,
        amount                = src.amount,
        dw_updated_at         = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        transaction_id, transaction_timestamp, card_id, card_holder_name, card_type, card_network,
        merchant_id, merchant_name, mcc_code, mcc_description, merchant_country, merchant_city,
        currency_code, transaction_type, entry_mode, auth_status, is_international, amount, dw_updated_at
    ) VALUES (
        src.transaction_id, src.transaction_timestamp, src.card_id, src.card_holder_name, src.card_type,
        src.card_network, src.merchant_id, src.merchant_name, src.mcc_code, src.mcc_description,
        src.merchant_country, src.merchant_city, src.currency_code, src.transaction_type, src.entry_mode,
        src.auth_status, src.is_international, src.amount, CURRENT_TIMESTAMP()
    );

    rows_merged := SQLROWCOUNT;
    RETURN 'int_transactions_enriched: merged ' || rows_merged || ' row(s)';
END;
$$;

CALL sp_load_int_transactions_enriched();

SELECT COUNT(*) AS int_transactions_enriched_rows FROM int_transactions_enriched;
