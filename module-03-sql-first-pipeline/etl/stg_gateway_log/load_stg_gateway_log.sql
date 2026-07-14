/* ============================================================================
   PayLedger course - Module 3: sp_load_stg_gateway_log
   ----------------------------------------------------------------------------
   Same watermark/MERGE pattern as sp_load_stg_transactions (see
   etl/stg_transactions/load_stg_transactions.sql), applied to raw_gateway_log.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE PROCEDURE sp_load_stg_gateway_log()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    wm TIMESTAMP_NTZ;
    rows_merged INTEGER DEFAULT 0;
BEGIN
    SELECT last_loaded_at INTO :wm FROM etl_watermark WHERE source_table = 'raw_gateway_log';

    MERGE INTO stg_gateway_log tgt
    USING (
        SELECT gateway_log_id, transaction_id, gateway_name, auth_code, response_code,
               response_message, gateway_timestamp, settlement_amount, interchange_fee,
               scheme_fee, _loaded_at
        FROM PAYLEDGER_RAW.raw_gateway_log
        WHERE _loaded_at > :wm
    ) src
    ON tgt.gateway_log_id = src.gateway_log_id
    WHEN MATCHED THEN UPDATE SET
        transaction_id    = src.transaction_id,
        gateway_name      = src.gateway_name,
        auth_code         = src.auth_code,
        response_code     = src.response_code,
        response_message  = src.response_message,
        gateway_timestamp = src.gateway_timestamp,
        settlement_amount = src.settlement_amount,
        interchange_fee   = src.interchange_fee,
        scheme_fee        = src.scheme_fee,
        source_loaded_at  = src._loaded_at,
        dw_updated_at     = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        gateway_log_id, transaction_id, gateway_name, auth_code, response_code,
        response_message, gateway_timestamp, settlement_amount, interchange_fee, scheme_fee,
        source_loaded_at, dw_inserted_at, dw_updated_at
    ) VALUES (
        src.gateway_log_id, src.transaction_id, src.gateway_name, src.auth_code, src.response_code,
        src.response_message, src.gateway_timestamp, src.settlement_amount, src.interchange_fee,
        src.scheme_fee, src._loaded_at, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );

    rows_merged := SQLROWCOUNT;

    UPDATE etl_watermark
    SET last_loaded_at = (SELECT MAX(_loaded_at) FROM PAYLEDGER_RAW.raw_gateway_log),
        updated_at     = CURRENT_TIMESTAMP()
    WHERE source_table = 'raw_gateway_log';

    RETURN 'stg_gateway_log: merged ' || rows_merged || ' row(s), watermark was ' || wm;
END;
$$;

CALL sp_load_stg_gateway_log();

SELECT COUNT(*) AS stg_gateway_log_rows FROM stg_gateway_log;
