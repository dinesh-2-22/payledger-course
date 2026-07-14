/* ============================================================================
   PayLedger course - Module 3: fact_payment_ledger (L3)
   ----------------------------------------------------------------------------
   Grain: one row per SETTLED transaction. Columns match the column-level
   lineage table in docs/lineage.md exactly -- keep the two in sync if you
   change this DDL.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE TABLE IF NOT EXISTS fact_payment_ledger (
    payment_ledger_key NUMBER(38,0) NOT NULL,   -- HASH(transaction_id)
    transaction_id     STRING NOT NULL,
    transaction_ts     TIMESTAMP_NTZ,
    card_id            STRING,                  -- FK -> dim_card
    merchant_id        STRING,                  -- FK -> dim_merchant
    mcc_code           STRING,                  -- FK -> dim_mcc
    currency_code      STRING,                  -- FK -> dim_currency
    transaction_type   STRING,
    entry_mode         STRING,
    auth_status        STRING,
    is_international   BOOLEAN,
    gross_amount       NUMBER(12,2),             -- amount, signed by transaction_type
    settlement_amount  NUMBER(12,2),
    interchange_fee    NUMBER(12,4),
    scheme_fee         NUMBER(12,4),
    net_amount         NUMBER(12,2),             -- settlement_amount - interchange_fee - scheme_fee
    is_disputed        BOOLEAN,                  -- EXISTS in dispute_memos
    dw_load_timestamp  TIMESTAMP_NTZ,             -- audit: when this row was last written
    PRIMARY KEY (transaction_id)
);
