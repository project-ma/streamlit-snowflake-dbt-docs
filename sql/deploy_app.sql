-- =====================================================================
-- deploy_app.sql  — (re)create the Streamlit app from the GitLab repo.
--
-- CREATE STREAMLIT ... FROM copies the files once, so re-run this after
-- changing anything under app/. Either:
--   * GitLab CI does it automatically (see .gitlab-ci.yml), or
--   * run in a Snowsight worksheet:
--       ALTER GIT REPOSITORY ANALYTICS.DBT_DOCS.DBT_DOCS_REPO FETCH;
--       EXECUTE IMMEDIATE FROM @ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/sql/deploy_app.sql;
-- =====================================================================
USE ROLE DBT_DOCS_ADMIN;

CREATE OR REPLACE STREAMLIT ANALYTICS.DBT_DOCS.DBT_DOCS
  FROM @ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/app/
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = DBT_DOCS_WH
  TITLE = 'dbt Docs';

-- Make it live so non-owners can open it straight away
ALTER STREAMLIT ANALYTICS.DBT_DOCS.DBT_DOCS ADD LIVE VERSION FROM LAST;

-- OR REPLACE drops grants, so re-apply them
GRANT USAGE ON STREAMLIT ANALYTICS.DBT_DOCS.DBT_DOCS TO ROLE DBT_DOCS_VIEWER;
