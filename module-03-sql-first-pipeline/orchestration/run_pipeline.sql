/* ============================================================================
   PayLedger course - Module 3: Orchestration (Snowflake Tasks)
   ----------------------------------------------------------------------------
   Wires the stored procedures created in ddl/ and etl/ into a dependency
   graph so the pipeline runs itself nightly, instead of you running six
   scripts by hand every time generate_data.py produces a new batch:

     task_load_stg_transactions ─┐                       ┌─► task_load_fact_payment_ledger
                                 ├─► task_load_int_transactions_enriched ─┤
     task_load_stg_gateway_log ──┤                                       │
                                 ├─► task_load_int_settlements ───────────┤
                                 └─► task_load_int_fees ──────────────────┘

   Prerequisites:
     - ddl/01-05 have been run (tables exist)
     - etl/*/load_*.sql have been run at least once (procedures exist)
     - dim_* tables exist (ddl/04_dimension_tables.sql) -- fact_payment_ledger's
       FKs assume these are current; re-run that script whenever masters change

   Run this script top to bottom in a Snowsight worksheet or SnowSQL.
   ========================================================================== */

-- EXECUTE TASK is an account-level privilege -- ACCOUNTADMIN must grant it
-- once before PAYLEDGER_DEV can create or run tasks.
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE PAYLEDGER_DEV;

USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

-- ---------------------------------------------------------------------------
-- Root tasks: incremental loads, on the same nightly window generate_data.py
-- simulates (_loaded_at clustered 02:00-03:00). Tasks are created SUSPENDED.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK task_load_stg_transactions
    WAREHOUSE = PAYLEDGER_WH
    SCHEDULE  = 'USING CRON 0 3 * * * UTC'
    COMMENT   = 'Root: incremental raw_transactions -> stg_transactions'
AS
    CALL sp_load_stg_transactions();

CREATE OR REPLACE TASK task_load_stg_gateway_log
    WAREHOUSE = PAYLEDGER_WH
    SCHEDULE  = 'USING CRON 0 3 * * * UTC'
    COMMENT   = 'Root: incremental raw_gateway_log -> stg_gateway_log'
AS
    CALL sp_load_stg_gateway_log();

-- ---------------------------------------------------------------------------
-- Intermediate layer: fan out from the two staging roots.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK task_load_int_transactions_enriched
    WAREHOUSE = PAYLEDGER_WH
    AFTER     = task_load_stg_transactions
AS
    CALL sp_load_int_transactions_enriched();

CREATE OR REPLACE TASK task_load_int_settlements
    WAREHOUSE = PAYLEDGER_WH
    AFTER     = task_load_stg_gateway_log
AS
    CALL sp_load_int_settlements();

CREATE OR REPLACE TASK task_load_int_fees
    WAREHOUSE = PAYLEDGER_WH
    AFTER     = task_load_stg_gateway_log
AS
    CALL sp_load_int_fees();

-- ---------------------------------------------------------------------------
-- Fact layer: fans back in from all three intermediate tasks.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK task_load_fact_payment_ledger
    WAREHOUSE = PAYLEDGER_WH
    AFTER     = task_load_int_transactions_enriched, task_load_int_settlements, task_load_int_fees
AS
    CALL sp_load_fact_payment_ledger();

-- ---------------------------------------------------------------------------
-- Resume the whole tree. A task's children must be resumed before the task
-- itself will actually fire them, so we enable each root's subtree instead of
-- resuming tasks one by one. task_load_fact_payment_ledger is shared by both
-- subtrees, so its RESUME the second time is a harmless no-op.
-- ---------------------------------------------------------------------------
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('task_load_stg_transactions');
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('task_load_stg_gateway_log');

-- ---------------------------------------------------------------------------
-- Testing: don't wait for the 03:00 UTC schedule -- fire the roots manually.
-- (EXECUTE TASK on a root cascades to its children once they complete.)
-- ---------------------------------------------------------------------------
-- EXECUTE TASK task_load_stg_transactions;
-- EXECUTE TASK task_load_stg_gateway_log;

-- Monitor recent runs across the whole DAG:
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
ORDER BY scheduled_time DESC
LIMIT 25;

-- ---------------------------------------------------------------------------
-- Cost note (trial account): these tasks now run every night and will spin
-- PAYLEDGER_WH up regardless of whether generate_data.py produced new data.
-- Suspend the tree when you're done with this module:
--   SELECT SYSTEM$TASK_DEPENDENTS_ENABLE(...) has no direct inverse; suspend
--   each task explicitly instead:
-- ---------------------------------------------------------------------------
-- ALTER TASK task_load_fact_payment_ledger SUSPEND;
-- ALTER TASK task_load_int_transactions_enriched SUSPEND;
-- ALTER TASK task_load_int_settlements SUSPEND;
-- ALTER TASK task_load_int_fees SUSPEND;
-- ALTER TASK task_load_stg_transactions SUSPEND;
-- ALTER TASK task_load_stg_gateway_log SUSPEND;
