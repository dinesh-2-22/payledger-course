/* ============================================================================
   PayLedger course - Module 3: Reset + dry run
   ----------------------------------------------------------------------------
   Not part of the pipeline itself -- a testing utility. Empties every table
   the pipeline writes to, resets the incremental watermark back to epoch, and
   fires the Task DAG once on demand so you can watch a full run end-to-end
   without waiting for the 03:00 UTC schedule.

   Prerequisites: ddl/01-05 and orchestration/run_pipeline.sql have already
   been run at least once (tables + tasks exist).

   Safe to re-run any number of times -- TRUNCATE + the watermark reset put
   you back to a clean slate every time.
   ========================================================================== */

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

-- ---------------------------------------------------------------------------
-- 1. Clean up: empty every table the pipeline writes to.
--    dim_* tables are NOT truncated here -- they're CREATE OR REPLACE TABLE AS
--    SELECT (full overwrite) in ddl/04_dimension_tables.sql, so re-run that
--    file directly if you want them rebuilt too; it's not required for a
--    clean pipeline run.
-- ---------------------------------------------------------------------------
TRUNCATE TABLE stg_transactions;
TRUNCATE TABLE stg_gateway_log;
TRUNCATE TABLE int_transactions_enriched;
TRUNCATE TABLE int_settlements;
TRUNCATE TABLE int_fees;
TRUNCATE TABLE fact_payment_ledger;

-- ---------------------------------------------------------------------------
-- 2. Reset the watermark so staging reprocesses every raw row from scratch.
-- ---------------------------------------------------------------------------
UPDATE etl_watermark
SET last_loaded_at = TO_TIMESTAMP_NTZ('1970-01-01'),
    updated_at     = CURRENT_TIMESTAMP();

SELECT * FROM etl_watermark ORDER BY source_table;

-- ---------------------------------------------------------------------------
-- 3. Dry run: fire the root task now instead of waiting for the schedule.
--    EXECUTE TASK returns immediately -- the DAG cascades asynchronously in
--    the background, so don't expect the tables below to be populated the
--    instant this statement completes.
-- ---------------------------------------------------------------------------
EXECUTE TASK task_pipeline_start;

-- ---------------------------------------------------------------------------
-- 4. Poll this until every row shows SUCCEEDED (wait ~30-60s after step 3,
--    then re-run this SELECT as needed -- it's just a query, safe to repeat).
-- ---------------------------------------------------------------------------
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE scheduled_time > DATEADD('minute', -30, CURRENT_TIMESTAMP())
ORDER BY scheduled_time DESC;

-- ---------------------------------------------------------------------------
-- 5. Once step 4 shows all 7 tasks SUCCEEDED, verify row counts landed.
-- ---------------------------------------------------------------------------
SELECT 'stg_transactions' AS tbl, COUNT(*) AS rows FROM stg_transactions
UNION ALL SELECT 'stg_gateway_log',           COUNT(*) FROM stg_gateway_log
UNION ALL SELECT 'int_transactions_enriched', COUNT(*) FROM int_transactions_enriched
UNION ALL SELECT 'int_settlements',           COUNT(*) FROM int_settlements
UNION ALL SELECT 'int_fees',                  COUNT(*) FROM int_fees
UNION ALL SELECT 'fact_payment_ledger',       COUNT(*) FROM fact_payment_ledger
ORDER BY tbl;
