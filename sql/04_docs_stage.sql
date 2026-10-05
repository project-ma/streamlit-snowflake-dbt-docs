-- =====================================================================
-- 04  Stage that holds the generated docs.
--
--     The refresh procedure (sql/05) publishes an extracted target/
--     directory here (latest/target/static_index.html, ...); it can also
--     keep the raw dbt_artifacts.zip alongside it (see ARTIFACT_MODE).
-- =====================================================================
USE ROLE DBT_DOCS_ADMIN;

CREATE STAGE IF NOT EXISTS ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  COMMENT = 'Latest dbt docs build (extracted target/ + optional dbt_artifacts.zip) read by the DBT_DOCS Streamlit app';
