/* ============================================================================
   PayLedger course - Module 3: Staging tables (L1)
   ----------------------------------------------------------------------------
   1:1 shape with their raw source, just renamed/typed for downstream use.
   Loaded incrementally in etl/stg_transactions and etl/stg_gateway_log via
   the etl_watermark table, so these carry a PK for MERGE + dw audit columns.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE TABLE IF NOT EXISTS stg_transactions (
    transaction_id        STRING NOT NULL,
    card_id               STRING,
    merchant_id           STRING,
    transaction_type      STRING,
    amount                NUMBER(12,2),
    currency_code         STRING,
    transaction_timestamp TIMESTAMP_NTZ,
    auth_status           STRING,
    mcc_code              STRING,
    entry_mode            STRING,
    is_international      BOOLEAN,
    source_loaded_at      TIMESTAMP_NTZ,   -- raw_transactions._loaded_at, kept for lineage
    dw_inserted_at        TIMESTAMP_NTZ,
    dw_updated_at         TIMESTAMP_NTZ,
    PRIMARY KEY (transaction_id)
);

CREATE TABLE IF NOT EXISTS stg_gateway_log (
    gateway_log_id    STRING NOT NULL,
    transaction_id    STRING,
    gateway_name      STRING,
    auth_code         STRING,
    response_code     STRING,
    response_message  STRING,
    gateway_timestamp TIMESTAMP_NTZ,
    settlement_amount NUMBER(12,2),
    interchange_fee   NUMBER(12,4),
    scheme_fee        NUMBER(12,4),
    source_loaded_at  TIMESTAMP_NTZ,       -- raw_gateway_log._loaded_at, kept for lineage
    dw_inserted_at    TIMESTAMP_NTZ,
    dw_updated_at     TIMESTAMP_NTZ,
    PRIMARY KEY (gateway_log_id)
);
