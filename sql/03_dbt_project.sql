-- =====================================================================
-- 03  dbt project object, built from the dbt/ folder of this repo
-- Run after 02 (the Git repository object must exist and be fetched).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 03a  OPTIONAL: only if dbt/packages.yml (or dependencies.yml) exists.
--      Lets Snowflake run `dbt deps` to download packages.
--      Skip this block, and the EXTERNAL_ACCESS_INTEGRATIONS line below,
--      if your project has no packages.
-- ---------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NETWORK RULE ANALYTICS.DBT_DOCS.DBT_DEPS_NETWORK_RULE
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('hub.getdbt.com', 'codeload.github.com');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION DBT_DEPS_ACCESS
  ALLOWED_NETWORK_RULES = (ANALYTICS.DBT_DOCS.DBT_DEPS_NETWORK_RULE)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION DBT_DEPS_ACCESS TO ROLE DBT_DOCS_ADMIN;

-- ---------------------------------------------------------------------
-- 03b  Create the dbt project object
-- ---------------------------------------------------------------------
USE ROLE DBT_DOCS_ADMIN;

ALTER GIT REPOSITORY ANALYTICS.DBT_DOCS.DBT_DOCS_REPO FETCH;

CREATE DBT PROJECT IF NOT EXISTS ANALYTICS.DBT_DOCS.DBT_PROJECT
  FROM '@ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/dbt'
  DEFAULT_TARGET = 'prod'
  EXTERNAL_ACCESS_INTEGRATIONS = (DBT_DEPS_ACCESS)   -- remove if no packages
  COMMENT = 'Built from GitLab repo dbt-docs-streamlit, folder dbt/';

-- Later updates (the refresh procedure and GitLab CI do this for you):
--   ALTER GIT REPOSITORY ANALYTICS.DBT_DOCS.DBT_DOCS_REPO FETCH;
--   ALTER DBT PROJECT ANALYTICS.DBT_DOCS.DBT_PROJECT
--     DEPLOY FROM '@ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/dbt';
