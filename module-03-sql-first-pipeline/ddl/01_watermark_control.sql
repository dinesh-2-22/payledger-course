/* ============================================================================
   PayLedger course - Module 3: Watermark control table
   ----------------------------------------------------------------------------
   Prerequisites: Module 1 (PAYLEDGER_DW schema) and Module 2 (raw tables
   populated) complete.

   One row per incrementally-loaded raw source. Module 2 batches every load
   with a shared _loaded_at, so "how far have we loaded" is a single
   MAX(_loaded_at) per source -- this table remembers that value between runs.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE TABLE IF NOT EXISTS etl_watermark (
    source_table    STRING NOT NULL,
    last_loaded_at  TIMESTAMP_NTZ NOT NULL,
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (source_table)
);

-- Seed a watermark row per incremental source, starting at epoch so the
-- first ETL run treats every existing raw row as new.
INSERT INTO etl_watermark (source_table, last_loaded_at)
SELECT 'raw_transactions', TO_TIMESTAMP_NTZ('1970-01-01')
WHERE NOT EXISTS (SELECT 1 FROM etl_watermark WHERE source_table = 'raw_transactions');

INSERT INTO etl_watermark (source_table, last_loaded_at)
SELECT 'raw_gateway_log', TO_TIMESTAMP_NTZ('1970-01-01')
WHERE NOT EXISTS (SELECT 1 FROM etl_watermark WHERE source_table = 'raw_gateway_log');

SELECT * FROM etl_watermark ORDER BY source_table;
