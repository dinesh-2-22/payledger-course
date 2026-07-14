/* ============================================================================
   PayLedger course - Module 3: sp_load_stg_transactions
   ----------------------------------------------------------------------------
   Incremental load: pulls only raw_transactions rows with _loaded_at greater
   than the watermark, MERGEs them into stg_transactions (idempotent - safe to
   re-run), then advances the watermark. On a re-run with no new raw data,
   this MERGEs 0 rows -- that's the expected, correct behavior of a Δ load.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE PROCEDURE sp_load_stg_transactions()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    wm TIMESTAMP_NTZ;
    rows_merged INTEGER DEFAULT 0;
BEGIN
    SELECT last_loaded_at INTO :wm FROM etl_watermark WHERE source_table = 'raw_transactions';

    MERGE INTO stg_transactions tgt
    USING (
        SELECT transaction_id, card_id, merchant_id, transaction_type, amount, currency_code,
               transaction_timestamp, auth_status, mcc_code, entry_mode, is_international, _loaded_at
        FROM PAYLEDGER_RAW.raw_transactions
        WHERE _loaded_at > :wm
    ) src
    ON tgt.transaction_id = src.transaction_id
    WHEN MATCHED THEN UPDATE SET
        card_id               = src.card_id,
        merchant_id           = src.merchant_id,
        transaction_type      = src.transaction_type,
        amount                = src.amount,
        currency_code         = src.currency_code,
        transaction_timestamp = src.transaction_timestamp,
        auth_status           = src.auth_status,
        mcc_code              = src.mcc_code,
        entry_mode            = src.entry_mode,
        is_international      = src.is_international,
        source_loaded_at      = src._loaded_at,
        dw_updated_at         = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        transaction_id, card_id, merchant_id, transaction_type, amount, currency_code,
        transaction_timestamp, auth_status, mcc_code, entry_mode, is_international,
        source_loaded_at, dw_inserted_at, dw_updated_at
    ) VALUES (
        src.transaction_id, src.card_id, src.merchant_id, src.transaction_type, src.amount,
        src.currency_code, src.transaction_timestamp, src.auth_status, src.mcc_code,
        src.entry_mode, src.is_international, src._loaded_at, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );

    rows_merged := SQLROWCOUNT;

    UPDATE etl_watermark
    SET last_loaded_at = (SELECT MAX(_loaded_at) FROM PAYLEDGER_RAW.raw_transactions),
        updated_at     = CURRENT_TIMESTAMP()
    WHERE source_table = 'raw_transactions';

    RETURN 'stg_transactions: merged ' || rows_merged || ' row(s), watermark was ' || wm;
END;
$$;

CALL sp_load_stg_transactions();

SELECT COUNT(*) AS stg_transactions_rows FROM stg_transactions;
