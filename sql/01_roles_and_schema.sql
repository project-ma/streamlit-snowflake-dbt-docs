-- =====================================================================
-- 01  Roles, warehouse, schema
-- Run once as ACCOUNTADMIN (or SECURITYADMIN + SYSADMIN).
-- Replace ANALYTICS / DBT_DOCS / DBT_TRANSFORMER names to suit.
-- =====================================================================
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS DBT_DOCS_ADMIN;   -- owns repo, dbt project, stage, proc, task, app
CREATE ROLE IF NOT EXISTS DBT_DOCS_VIEWER;  -- people who open the app
GRANT ROLE DBT_DOCS_ADMIN TO ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS DBT_DOCS_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
GRANT USAGE ON WAREHOUSE DBT_DOCS_WH TO ROLE DBT_DOCS_ADMIN;
GRANT USAGE ON WAREHOUSE DBT_DOCS_WH TO ROLE DBT_DOCS_VIEWER;

CREATE SCHEMA IF NOT EXISTS ANALYTICS.DBT_DOCS;
GRANT USAGE ON DATABASE ANALYTICS TO ROLE DBT_DOCS_ADMIN;
GRANT USAGE ON DATABASE ANALYTICS TO ROLE DBT_DOCS_VIEWER;
GRANT USAGE ON SCHEMA ANALYTICS.DBT_DOCS TO ROLE DBT_DOCS_VIEWER;
GRANT ALL ON SCHEMA ANALYTICS.DBT_DOCS TO ROLE DBT_DOCS_ADMIN;

-- dbt runs docs generate using the `role:` in dbt/profiles.yml.
-- That role must be able to read every source and model (for the catalog),
-- and the admin role must be able to assume it.
-- Replace DBT_TRANSFORMER with the role your dbt project already uses.
GRANT ROLE DBT_TRANSFORMER TO ROLE DBT_DOCS_ADMIN;

-- Tasks
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DBT_DOCS_ADMIN;

-- Add people:  GRANT ROLE DBT_DOCS_VIEWER TO USER <user>;
