/* ============================================================================
   PayLedger course - Module 1: Bootstrap Snowflake objects
   ----------------------------------------------------------------------------
   Prerequisites:
     - A Snowflake trial account (Module 0). You are logged in as your default
       user, which is granted the ACCOUNTADMIN role automatically on a trial.

   What this script does:
     1. Sets context (ACCOUNTADMIN - required to create warehouses/roles)
     2. Creates the course warehouse, database, and the two schemas every
        later module reads from or writes to
     3. Creates the PAYLEDGER_DEV role and grants it to you (CURRENT_USER())
     4. Grants USAGE/OPERATE on the warehouse and full rights on the schemas,
        including FUTURE grants so tables/stages created later (Module 2+)
        are automatically usable by PAYLEDGER_DEV without re-granting
     5. Switches into PAYLEDGER_DEV and verifies the context

   Run this top to bottom in a Snowsight worksheet (or SnowSQL). Everything
   below is idempotent (IF NOT EXISTS / OR REPLACE ROLE), so re-running it
   after a partial failure is safe.
   ========================================================================== */

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- 1. Warehouse - XS, auto-suspend/auto-resume so a trial account never idles
--    and burns credits between study sessions.
-- ---------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS PAYLEDGER_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'PayLedger course warehouse';

-- ---------------------------------------------------------------------------
-- 2. Database + schemas
--    PAYLEDGER_RAW - landing zone for Module 2's raw CSV loads
--    PAYLEDGER_DW  - staging/intermediate/mart schema for Module 3+
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS PAYLEDGER
    COMMENT = 'PayLedger course database';

CREATE SCHEMA IF NOT EXISTS PAYLEDGER.PAYLEDGER_RAW
    COMMENT = 'Landing zone for raw CSV loads (Module 2)';

CREATE SCHEMA IF NOT EXISTS PAYLEDGER.PAYLEDGER_DW
    COMMENT = 'Modeled staging/intermediate/mart schema (Modules 3+)';

-- ---------------------------------------------------------------------------
-- 3. Role - PAYLEDGER_DEV is what every later module's scripts USE ROLE as.
--    Granted to whoever runs this script, so there's no placeholder username
--    to edit.
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS PAYLEDGER_DEV
    COMMENT = 'Course dev role - owns all PayLedger objects';

SET my_user = CURRENT_USER();
GRANT ROLE PAYLEDGER_DEV TO USER IDENTIFIER($my_user);

-- ---------------------------------------------------------------------------
-- 4. Grants
-- ---------------------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE PAYLEDGER_WH TO ROLE PAYLEDGER_DEV;

GRANT USAGE ON DATABASE PAYLEDGER TO ROLE PAYLEDGER_DEV;

GRANT ALL ON SCHEMA PAYLEDGER.PAYLEDGER_RAW TO ROLE PAYLEDGER_DEV;
GRANT ALL ON SCHEMA PAYLEDGER.PAYLEDGER_DW TO ROLE PAYLEDGER_DEV;

-- FUTURE grants: tables/stages Module 2+ creates in these schemas are
-- automatically usable by PAYLEDGER_DEV - without this, COPY INTO in
-- Module 2 would fail with an authorization error even though the schema
-- itself exists.
GRANT ALL ON FUTURE TABLES IN SCHEMA PAYLEDGER.PAYLEDGER_RAW TO ROLE PAYLEDGER_DEV;
GRANT ALL ON FUTURE TABLES IN SCHEMA PAYLEDGER.PAYLEDGER_DW TO ROLE PAYLEDGER_DEV;
GRANT ALL ON FUTURE STAGES IN SCHEMA PAYLEDGER.PAYLEDGER_RAW TO ROLE PAYLEDGER_DEV;
GRANT ALL ON FUTURE STAGES IN SCHEMA PAYLEDGER.PAYLEDGER_DW TO ROLE PAYLEDGER_DEV;

-- ---------------------------------------------------------------------------
-- 5. Verify - switch into the role/warehouse/schema every later module uses
-- ---------------------------------------------------------------------------
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE DATABASE PAYLEDGER;
USE SCHEMA PAYLEDGER_RAW;

SELECT
    CURRENT_ROLE()      AS role,
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_DATABASE()  AS database,
    CURRENT_SCHEMA()    AS schema;
-- Expected: PAYLEDGER_DEV | PAYLEDGER_WH | PAYLEDGER | PAYLEDGER_RAW
