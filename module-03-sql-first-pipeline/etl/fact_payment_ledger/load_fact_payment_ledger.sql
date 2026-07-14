/* ============================================================================
   PayLedger course - Module 3: sp_load_fact_payment_ledger
   ----------------------------------------------------------------------------
   Grain: one row per settled transaction. The INNER JOINs to int_settlements
   and int_fees *are* the grain filter -- a transaction with no settlement row
   never produces a fact row. Column derivations match docs/lineage.md.

   Run order: this depends on int_transactions_enriched, int_settlements,
   int_fees, and the dim_* tables all being current -- see
   orchestration/run_pipeline.sql for the full dependency graph.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE PROCEDURE sp_load_fact_payment_ledger()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_merged INTEGER DEFAULT 0;
BEGIN
    MERGE INTO fact_payment_ledger tgt
    USING (
        SELECT
            HASH(ite.transaction_id)                                       AS payment_ledger_key,
            ite.transaction_id,
            ite.transaction_timestamp                                      AS transaction_ts,
            ite.card_id,
            ite.merchant_id,
            ite.mcc_code,
            ite.currency_code,
            ite.transaction_type,
            ite.entry_mode,
            ite.auth_status,
            ite.is_international,
            IFF(ite.transaction_type ILIKE '%REFUND%', -ABS(ite.amount), ABS(ite.amount)) AS gross_amount,
            ist.settlement_amount,
            ifz.interchange_fee,
            ifz.scheme_fee,
            ist.settlement_amount - ifz.interchange_fee - ifz.scheme_fee   AS net_amount,
            IFF(dm.transaction_id IS NOT NULL, TRUE, FALSE)                AS is_disputed
        FROM int_transactions_enriched ite
        JOIN int_settlements ist ON ite.transaction_id = ist.transaction_id
        JOIN int_fees ifz        ON ite.transaction_id = ifz.transaction_id
        LEFT JOIN PAYLEDGER_RAW.dispute_memos dm ON ite.transaction_id = dm.transaction_id
    ) src
    ON tgt.transaction_id = src.transaction_id
    WHEN MATCHED THEN UPDATE SET
        payment_ledger_key = src.payment_ledger_key,
        transaction_ts     = src.transaction_ts,
        card_id            = src.card_id,
        merchant_id        = src.merchant_id,
        mcc_code           = src.mcc_code,
        currency_code      = src.currency_code,
        transaction_type   = src.transaction_type,
        entry_mode         = src.entry_mode,
        auth_status        = src.auth_status,
        is_international   = src.is_international,
        gross_amount       = src.gross_amount,
        settlement_amount  = src.settlement_amount,
        interchange_fee    = src.interchange_fee,
        scheme_fee         = src.scheme_fee,
        net_amount         = src.net_amount,
        is_disputed        = src.is_disputed,
        dw_load_timestamp  = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        payment_ledger_key, transaction_id, transaction_ts, card_id, merchant_id, mcc_code,
        currency_code, transaction_type, entry_mode, auth_status, is_international, gross_amount,
        settlement_amount, interchange_fee, scheme_fee, net_amount, is_disputed, dw_load_timestamp
    ) VALUES (
        src.payment_ledger_key, src.transaction_id, src.transaction_ts, src.card_id, src.merchant_id,
        src.mcc_code, src.currency_code, src.transaction_type, src.entry_mode, src.auth_status,
        src.is_international, src.gross_amount, src.settlement_amount, src.interchange_fee,
        src.scheme_fee, src.net_amount, src.is_disputed, CURRENT_TIMESTAMP()
    );

    rows_merged := SQLROWCOUNT;
    RETURN 'fact_payment_ledger: merged ' || rows_merged || ' row(s)';
END;
$$;

CALL sp_load_fact_payment_ledger();

-- Checkpoint queries
SELECT COUNT(*) AS fact_payment_ledger_rows FROM fact_payment_ledger;

SELECT
    COUNT(*)                                   AS total_rows,
    SUM(IFF(is_disputed, 1, 0))                AS disputed_rows,
    ROUND(SUM(net_amount), 2)                  AS total_net_amount,
    COUNT(DISTINCT currency_code)              AS distinct_currencies
FROM fact_payment_ledger;
