/* ============================================================================
   PayLedger course - Module 3: Intermediate tables (L2)
   ----------------------------------------------------------------------------
   int_transactions_enriched - stg_transactions + card/merchant descriptive
                                attributes (rc, rm feed this directly - see
                                docs/lineage.md, no staging layer needed for
                                slowly-changing master data).
   int_settlements           - one row per SETTLED transaction: the final
                                gateway_log event per transaction_id (nets
                                out the ~15% of transactions that see a
                                decline followed by a successful retry).
   int_fees                  - interchange/scheme fee attribution, same
                                "final event per transaction" derivation as
                                int_settlements, kept as a separate model
                                because it answers a different business
                                question (foreshadows Module 5's dbt marts).
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE TABLE IF NOT EXISTS int_transactions_enriched (
    transaction_id        STRING NOT NULL,
    transaction_timestamp TIMESTAMP_NTZ,
    card_id               STRING,
    card_holder_name      STRING,
    card_type             STRING,
    card_network          STRING,
    merchant_id           STRING,
    merchant_name         STRING,
    mcc_code              STRING,
    mcc_description       STRING,
    merchant_country      STRING,
    merchant_city         STRING,
    currency_code         STRING,
    transaction_type      STRING,
    entry_mode            STRING,
    auth_status           STRING,
    is_international      BOOLEAN,
    amount                NUMBER(12,2),
    dw_updated_at         TIMESTAMP_NTZ,
    PRIMARY KEY (transaction_id)
);

CREATE TABLE IF NOT EXISTS int_settlements (
    transaction_id    STRING NOT NULL,
    settlement_amount NUMBER(12,2),
    settled_at        TIMESTAMP_NTZ,   -- gateway_timestamp of the final gateway event
    dw_updated_at     TIMESTAMP_NTZ,
    PRIMARY KEY (transaction_id)
);

CREATE TABLE IF NOT EXISTS int_fees (
    transaction_id  STRING NOT NULL,
    interchange_fee NUMBER(12,4),
    scheme_fee      NUMBER(12,4),
    dw_updated_at   TIMESTAMP_NTZ,
    PRIMARY KEY (transaction_id)
);
