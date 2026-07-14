/* ============================================================================
   PayLedger course - Module 3 (optional): Snowflake <-> GitHub Git integration
   ----------------------------------------------------------------------------
   Not required for the pipeline itself -- this is a workflow convenience.
   Once set up, Snowflake clones this repo directly, so instead of
   copy-pasting every ddl/etl/orchestration file into a Snowsight worksheet by
   hand, you can:
     1. `git push` from your machine (as you've been doing all along)
     2. ALTER GIT REPOSITORY ... FETCH;  (or click "Pull" in a Workspace)
     3. EXECUTE IMMEDIATE FROM @<repo>/branches/main/<path-to-file>.sql;
   or just open the cloned repo as a Snowsight Workspace and run files from
   there directly -- either way, no copy-paste.

   Prerequisites: Module 1 complete (PAYLEDGER_DEV role, PAYLEDGER_WH,
   PAYLEDGER.PAYLEDGER_DW exist). Run section 1 as ACCOUNTADMIN once; sections
   2+ as PAYLEDGER_DEV.
   ========================================================================== */

-- ---------------------------------------------------------------------------
-- 1. One-time account setup (ACCOUNTADMIN)
--    GitHub requires a Personal Access Token, not a password. Create a
--    fine-grained PAT scoped to this one repo with "Contents: Read" (add
--    "Read and write" only if you also want to push back to GitHub from
--    Snowflake, which this course doesn't need).
-- ---------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE DATABASE PAYLEDGER;
USE SCHEMA PAYLEDGER_DW;

CREATE OR REPLACE SECRET payledger_github_secret
    TYPE = PASSWORD
    USERNAME = 'raysidharthamca'          -- your GitHub username
    PASSWORD = '<your GitHub PAT>';       -- paste your token, don't commit it

CREATE OR REPLACE API INTEGRATION payledger_github_api
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/raysidharthamca/')
    ALLOWED_AUTHENTICATION_SECRETS = (payledger_github_secret)
    ENABLED = TRUE;

-- Let PAYLEDGER_DEV use both without needing ACCOUNTADMIN going forward.
GRANT USAGE ON INTEGRATION payledger_github_api TO ROLE PAYLEDGER_DEV;
GRANT READ ON SECRET payledger_github_secret TO ROLE PAYLEDGER_DEV;

-- ---------------------------------------------------------------------------
-- 2. Create the Git Repository object (clones the repo into Snowflake)
-- ---------------------------------------------------------------------------
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_DW;

CREATE OR REPLACE GIT REPOSITORY payledger_course_repo
    API_INTEGRATION = payledger_github_api
    GIT_CREDENTIALS = payledger_github_secret
    ORIGIN = 'https://github.com/raysidharthamca/payledger-course.git';

-- Confirm it cloned and see what's there:
SHOW GIT BRANCHES IN GIT REPOSITORY payledger_course_repo;
LS @payledger_course_repo/branches/main;

-- ---------------------------------------------------------------------------
-- 3. Day-to-day: pull latest, then run files straight from the repo stage
--    instead of pasting their contents into a worksheet.
-- ---------------------------------------------------------------------------
ALTER GIT REPOSITORY payledger_course_repo FETCH;

EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/ddl/01_watermark_control.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/ddl/02_staging_tables.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/ddl/03_intermediate_tables.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/ddl/04_dimension_tables.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/ddl/05_fact_table.sql;

EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/etl/stg_transactions/load_stg_transactions.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/etl/stg_gateway_log/load_stg_gateway_log.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/etl/int_transactions_enriched/load_int_transactions_enriched.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/etl/int_settlements/load_int_settlements.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/etl/int_fees/load_int_fees.sql;
EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/etl/fact_payment_ledger/load_fact_payment_ledger.sql;

EXECUTE IMMEDIATE FROM @payledger_course_repo/branches/main/module-03-sql-first-pipeline/orchestration/run_pipeline.sql;

-- ---------------------------------------------------------------------------
-- Alternative: skip EXECUTE IMMEDIATE entirely and just work in the UI --
-- Snowsight left nav -> Workspaces -> "+" -> Create Workspace from Git
-- Repository -> pick payledger_course_repo / main. That opens the whole repo
-- as browsable files you can open and run directly, and "Pull" replaces
-- step 3's ALTER ... FETCH.
-- ---------------------------------------------------------------------------
