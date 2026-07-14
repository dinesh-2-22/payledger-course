/* ============================================================================
   PayLedger course - Module 3: sp_load_int_settlements
   ----------------------------------------------------------------------------
   Nets gateway retries: generate_data.py writes a retry gateway_log row for
   ~15% of declined transactions, so a transaction can have >1 event. The
   final event per transaction_id (latest gateway_timestamp) is authoritative;
   we only keep it when it actually settled (settlement_amount IS NOT NULL) --
   that's what makes this table's rows == "settled transactions", which is
   what fact_payment_ledger's grain is built from.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE PROCEDURE sp_load_int_settlements()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_merged INTEGER DEFAULT 0;
BEGIN
    MERGE INTO int_settlements tgt
    USING (
        SELECT transaction_id, settlement_amount, gateway_timestamp AS settled_at
        FROM (
            SELECT
                transaction_id,
                settlement_amount,
                gateway_timestamp,
                ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY gateway_timestamp DESC) AS rn
            FROM stg_gateway_log
        )
        WHERE rn = 1 AND settlement_amount IS NOT NULL
    ) src
    ON tgt.transaction_id = src.transaction_id
    WHEN MATCHED THEN UPDATE SET
        settlement_amount = src.settlement_amount,
        settled_at        = src.settled_at,
        dw_updated_at     = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (transaction_id, settlement_amount, settled_at, dw_updated_at)
        VALUES (src.transaction_id, src.settlement_amount, src.settled_at, CURRENT_TIMESTAMP());

    rows_merged := SQLROWCOUNT;
    RETURN 'int_settlements: merged ' || rows_merged || ' row(s)';
END;
$$;

CALL sp_load_int_settlements();

SELECT COUNT(*) AS int_settlements_rows FROM int_settlements;
