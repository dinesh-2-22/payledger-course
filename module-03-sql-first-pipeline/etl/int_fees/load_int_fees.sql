/* ============================================================================
   PayLedger course - Module 3: sp_load_int_fees
   ----------------------------------------------------------------------------
   Same "final gateway event per transaction" derivation as int_settlements
   (see etl/int_settlements/load_int_settlements.sql) -- kept as its own model
   because it answers a different business question (fee attribution vs.
   settlement netting), matching the separate nodes in docs/lineage.md.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE PROCEDURE sp_load_int_fees()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_merged INTEGER DEFAULT 0;
BEGIN
    MERGE INTO int_fees tgt
    USING (
        SELECT transaction_id, interchange_fee, scheme_fee
        FROM (
            SELECT
                transaction_id,
                interchange_fee,
                scheme_fee,
                settlement_amount,
                ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY gateway_timestamp DESC) AS rn
            FROM stg_gateway_log
        )
        WHERE rn = 1 AND settlement_amount IS NOT NULL   -- fees only assessed on settled transactions
    ) src
    ON tgt.transaction_id = src.transaction_id
    WHEN MATCHED THEN UPDATE SET
        interchange_fee = src.interchange_fee,
        scheme_fee      = src.scheme_fee,
        dw_updated_at   = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (transaction_id, interchange_fee, scheme_fee, dw_updated_at)
        VALUES (src.transaction_id, src.interchange_fee, src.scheme_fee, CURRENT_TIMESTAMP());

    rows_merged := SQLROWCOUNT;
    RETURN 'int_fees: merged ' || rows_merged || ' row(s)';
END;
$$;

CALL sp_load_int_fees();

SELECT COUNT(*) AS int_fees_rows FROM int_fees;
