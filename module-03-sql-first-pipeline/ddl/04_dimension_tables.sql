/* ============================================================================
   PayLedger course - Module 3: Conformed dimensions (L3)
   ----------------------------------------------------------------------------
   Built straight from raw masters (see docs/lineage.md) with CREATE OR REPLACE
   TABLE ... AS SELECT. Unlike the fact table these are small, slowly-changing,
   full-refresh builds -- no watermark/MERGE needed, so there's no etl/ folder
   for them and this single script is both DDL and load.

   Run this every time you re-run generate_data.py with new merchants/cards,
   and always before (re)building fact_payment_ledger, since the fact table's
   FKs assume these are current.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE TABLE dim_merchant AS
SELECT
    merchant_id,
    merchant_name,
    merchant_country,
    merchant_city,
    onboarded_date,
    merchant_status,
    CURRENT_TIMESTAMP() AS dw_updated_at
FROM PAYLEDGER_RAW.raw_merchant_master;

CREATE OR REPLACE TABLE dim_card AS
SELECT
    card_id,
    card_holder_name,
    bin,
    last_four,
    card_type,
    card_network,
    currency_code,
    issued_date,
    card_status,
    CURRENT_TIMESTAMP() AS dw_updated_at
FROM PAYLEDGER_RAW.raw_card_master;

-- Distinct MCC codes, sourced from the merchant master (see docs/lineage.md).
CREATE OR REPLACE TABLE dim_mcc AS
SELECT DISTINCT
    mcc_code,
    mcc_description,
    CURRENT_TIMESTAMP() AS dw_updated_at
FROM PAYLEDGER_RAW.raw_merchant_master;

-- Distinct currency codes observed on transactions (see docs/lineage.md:
-- "rt -.-> distinct currency codes -.-> dcur").
CREATE OR REPLACE TABLE dim_currency AS
SELECT DISTINCT
    currency_code,
    CURRENT_TIMESTAMP() AS dw_updated_at
FROM PAYLEDGER_RAW.raw_transactions;
