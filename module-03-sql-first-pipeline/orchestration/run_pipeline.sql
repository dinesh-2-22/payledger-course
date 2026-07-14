/* ============================================================================
   PayLedger course - Module 3: Orchestration (Snowflake Tasks)
   ----------------------------------------------------------------------------
   Wires the stored procedures created in ddl/ and etl/ into a dependency
   graph so the pipeline runs itself nightly, instead of you running six
   scripts by hand every time generate_data.py produces a new batch:

                                 ┌─► task_load_stg_transactions ─┐                       ┌─► task_load_fact_payment_ledger
     task_pipeline_start (root) ─┤                               ├─► task_load_int_transactions_enriched ─┤
                                 └─► task_load_stg_gateway_log ───┤                                        │
                                                                  ├─► task_load_int_settlements ───────────┤
                                                                  └─► task_load_int_fees ──────────────────┘

   Why a "start" task: a single Snowflake Task graph may only have ONE root
   task carrying a SCHEDULE -- every other task must reach back to that one
   root via AFTER. task_load_stg_transactions and task_load_stg_gateway_log
   both feed task_load_fact_payment_ledger, so Snowflake treats them as one
   connected graph; giving both their own SCHEDULE throws "the graph has more
   than one root task". task_pipeline_start is a trivial no-op that exists
   purely to own the schedule, so the two staging loads can still run in
   parallel as its children.

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
-- Root: the only task in this graph allowed to carry a SCHEDULE. Fires on the
-- same nightly window generate_data.py simulates (_loaded_at clustered
-- 02:00-03:00). Does no real work -- it exists so the two staging loads
-- below can run as its (parallel) children instead of each self-scheduling.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK task_pipeline_start
    WAREHOUSE = PAYLEDGER_WH
    SCHEDULE  = 'USING CRON 0 3 * * * UTC'
    COMMENT   = 'Root: owns the schedule so staging tasks can run as its children'
AS
    SELECT 'pipeline start';

CREATE OR REPLACE TASK task_load_stg_transactions
    WAREHOUSE = PAYLEDGER_WH
    AFTER task_pipeline_start
    COMMENT   = 'Incremental raw_transactions -> stg_transactions'
AS
    CALL sp_load_stg_transactions();

CREATE OR REPLACE TASK task_load_stg_gateway_log
    WAREHOUSE = PAYLEDGER_WH
    AFTER task_pipeline_start
    COMMENT   = 'Incremental raw_gateway_log -> stg_gateway_log'
AS
    CALL sp_load_stg_gateway_log();

-- ---------------------------------------------------------------------------
-- Intermediate layer: fan out from the two staging tasks.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK task_load_int_transactions_enriched
    WAREHOUSE = PAYLEDGER_WH
    AFTER task_load_stg_transactions
AS
    CALL sp_load_int_transactions_enriched();

CREATE OR REPLACE TASK task_load_int_settlements
    WAREHOUSE = PAYLEDGER_WH
    AFTER task_load_stg_gateway_log
AS
    CALL sp_load_int_settlements();

CREATE OR REPLACE TASK task_load_int_fees
    WAREHOUSE = PAYLEDGER_WH
    AFTER task_load_stg_gateway_log
AS
    CALL sp_load_int_fees();

-- ---------------------------------------------------------------------------
-- Fact layer: fans back in from all three intermediate tasks.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TASK task_load_fact_payment_ledger
    WAREHOUSE = PAYLEDGER_WH
    AFTER task_load_int_transactions_enriched, task_load_int_settlements, task_load_int_fees
AS
    CALL sp_load_fact_payment_ledger();

-- ---------------------------------------------------------------------------
-- Resume the whole tree. A task's children must be resumed before the task
-- itself will actually fire them, so we enable the root's entire subtree in
-- one call rather than resuming tasks one by one.
-- ---------------------------------------------------------------------------
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('task_pipeline_start');

-- ---------------------------------------------------------------------------
-- Testing: don't wait for the 03:00 UTC schedule -- fire the root manually.
-- (EXECUTE TASK on the root cascades through every descendant as each
-- predecessor completes.)
-- ---------------------------------------------------------------------------
-- EXECUTE TASK task_pipeline_start;

-- Monitor recent runs across the whole DAG:
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
ORDER BY scheduled_time DESC
LIMIT 25;

-- ---------------------------------------------------------------------------
-- Cost note (trial account): these tasks now run every night and will spin
-- PAYLEDGER_WH up regardless of whether generate_data.py produced new data.
-- Suspend the tree when you're done with this module:
-- ---------------------------------------------------------------------------
-- ALTER TASK task_load_fact_payment_ledger SUSPEND;
-- ALTER TASK task_load_int_transactions_enriched SUSPEND;
-- ALTER TASK task_load_int_settlements SUSPEND;
-- ALTER TASK task_load_int_fees SUSPEND;
-- ALTER TASK task_load_stg_transactions SUSPEND;
-- ALTER TASK task_load_stg_gateway_log SUSPEND;
-- ALTER TASK task_pipeline_start SUSPEND;
