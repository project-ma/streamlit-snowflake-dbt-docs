-- =====================================================================
-- 03  Stage that holds the generated docs (dbt_artifacts.zip)
-- =====================================================================
USE ROLE DBT_DOCS_ADMIN;

CREATE STAGE IF NOT EXISTS ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Latest dbt docs build (dbt_artifacts.zip) read by the DBT_DOCS Streamlit app';
