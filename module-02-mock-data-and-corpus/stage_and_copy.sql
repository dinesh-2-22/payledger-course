/* ============================================================================
   PayLedger course - Module 2: Land raw files into Snowflake
   ----------------------------------------------------------------------------
   Prerequisites (from Module 1):
     - Database  PAYLEDGER
     - Schema    PAYLEDGER.PAYLEDGER_RAW
     - Warehouse PAYLEDGER_WH (XS)
     - Role with USAGE/CREATE on the above

   What this script does:
     1. Sets context (role / warehouse / schema)
     2. Creates a CSV file format and an internal stage
     3. (Run PUTs in SnowSQL OR upload via Snowsight) loads local CSVs to the stage
     4. Creates the 5 raw tables (columns match generate_data.py exactly)
     5. COPY INTO each table
     6. Validates row counts + shows the watermark you'll use in Module 3

   NOTE on uploading files:
     `PUT` is a client-side command. It works in SnowSQL and the VS Code
     Snowflake extension, but NOT in the Snowsight SQL worksheet. If you are in
     Snowsight, use  Data > Databases > ... > Load Data  to upload the CSVs into
     the @PAYLEDGER_RAW_STAGE, then skip straight to the COPY INTO statements.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;            -- created in Module 1
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_RAW;

-- ---------------------------------------------------------------------------
-- 1. File format + internal stage
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT ff_csv
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'   -- memo_text contains commas
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE;

CREATE OR REPLACE STAGE PAYLEDGER_RAW_STAGE
    FILE_FORMAT = ff_csv
    COMMENT = 'Landing stage for Module 2 raw CSVs';

-- ---------------------------------------------------------------------------
-- 2. Upload local files to the stage  (SnowSQL / VS Code only -- see note above)
--    Adjust the path to wherever you ran generate_data.py.
-- ---------------------------------------------------------------------------
-- PUT file://./data/raw_merchant_master.csv  @PAYLEDGER_RAW_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
-- PUT file://./data/raw_card_master.csv       @PAYLEDGER_RAW_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
-- PUT file://./data/raw_transactions.csv      @PAYLEDGER_RAW_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
-- PUT file://./data/raw_gateway_log.csv       @PAYLEDGER_RAW_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
-- PUT file://./data/dispute_memos.csv         @PAYLEDGER_RAW_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;

LIST @PAYLEDGER_RAW_STAGE;   -- confirm 5 files are staged

-- ---------------------------------------------------------------------------
-- 3. Raw table DDL  (1:1 with the CSV headers from generate_data.py)
--    Raw layer keeps everything permissive -- we clean/cast in staging (Module 3).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw_merchant_master (
    merchant_id       STRING,
    merchant_name     STRING,
    mcc_code          STRING,
    mcc_description   STRING,
    merchant_country  STRING,
    merchant_city     STRING,
    onboarded_date    DATE,
    merchant_status   STRING,
    _loaded_at        TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE raw_card_master (
    card_id           STRING,
    card_holder_name  STRING,
    bin               STRING,
    last_four         STRING,
    card_type         STRING,
    card_network      STRING,
    currency_code     STRING,
    issued_date       DATE,
    card_status       STRING,
    _loaded_at        TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE raw_transactions (
    transaction_id        STRING,
    card_id               STRING,
    merchant_id           STRING,
    transaction_type      STRING,
    amount                NUMBER(12,2),
    currency_code         STRING,
    transaction_timestamp TIMESTAMP_NTZ,
    auth_status           STRING,
    mcc_code              STRING,
    entry_mode            STRING,
    is_international       BOOLEAN,
    _loaded_at            TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE raw_gateway_log (
    gateway_log_id    STRING,
    transaction_id    STRING,
    gateway_name      STRING,
    auth_code         STRING,
    response_code     STRING,
    response_message  STRING,
    gateway_timestamp TIMESTAMP_NTZ,
    settlement_amount NUMBER(12,2),
    interchange_fee   NUMBER(12,4),
    scheme_fee        NUMBER(12,4),
    _loaded_at        TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE dispute_memos (
    dispute_id          STRING,
    transaction_id      STRING,
    merchant_id         STRING,
    card_id             STRING,
    dispute_category    STRING,
    dispute_reason_code STRING,
    dispute_status      STRING,
    created_date        DATE,
    memo_text           STRING            -- <-- the Cortex Search corpus column
);

-- ---------------------------------------------------------------------------
-- 4. Load each file. ON_ERROR=ABORT_STATEMENT so a bad row fails loudly
--    (a deliberate teaching choice -- in Module 5 dbt tests replace this guardrail).
-- ---------------------------------------------------------------------------
COPY INTO raw_merchant_master FROM @PAYLEDGER_RAW_STAGE/raw_merchant_master.csv.gz ON_ERROR = ABORT_STATEMENT;
COPY INTO raw_card_master     FROM @PAYLEDGER_RAW_STAGE/raw_card_master.csv.gz     ON_ERROR = ABORT_STATEMENT;
COPY INTO raw_transactions    FROM @PAYLEDGER_RAW_STAGE/raw_transactions.csv.gz    ON_ERROR = ABORT_STATEMENT;
COPY INTO raw_gateway_log     FROM @PAYLEDGER_RAW_STAGE/raw_gateway_log.csv.gz     ON_ERROR = ABORT_STATEMENT;
COPY INTO dispute_memos       FROM @PAYLEDGER_RAW_STAGE/dispute_memos.csv.gz       ON_ERROR = ABORT_STATEMENT;
-- (If you uploaded via Snowsight, drop the ".gz" suffix -- those files are not auto-compressed.)

-- ---------------------------------------------------------------------------
-- 5. Validate -- expected approx counts at default seed/rows
-- ---------------------------------------------------------------------------
SELECT 'raw_merchant_master' AS tbl, COUNT(*) AS rows FROM raw_merchant_master
UNION ALL SELECT 'raw_card_master',     COUNT(*) FROM raw_card_master
UNION ALL SELECT 'raw_transactions',    COUNT(*) FROM raw_transactions
UNION ALL SELECT 'raw_gateway_log',     COUNT(*) FROM raw_gateway_log
UNION ALL SELECT 'dispute_memos',       COUNT(*) FROM dispute_memos
ORDER BY tbl;

-- The watermark you will anchor the Module 3 delta-load on:
SELECT MAX(_loaded_at) AS max_loaded_at FROM raw_transactions;
