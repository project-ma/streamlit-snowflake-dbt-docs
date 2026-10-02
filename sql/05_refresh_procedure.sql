-- =====================================================================
-- 05  Procedure: pull latest main from GitLab, redeploy the dbt project,
--     generate static docs, copy the artifacts zip to the docs stage.
-- If any step fails the procedure errors before touching the stage,
-- so the app keeps showing the last good docs.
-- =====================================================================
USE ROLE DBT_DOCS_ADMIN;

CREATE OR REPLACE PROCEDURE ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  qid STRING;
  loc STRING;
BEGIN
  -- Docs always reflect what's on main right now
  ALTER GIT REPOSITORY ANALYTICS.DBT_DOCS.DBT_DOCS_REPO FETCH;
  ALTER DBT PROJECT ANALYTICS.DBT_DOCS.DBT_PROJECT
    DEPLOY FROM '@ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/dbt';

  EXECUTE DBT PROJECT ANALYTICS.DBT_DOCS.DBT_PROJECT
    ARGS = 'docs generate --static --target prod';

  qid := LAST_QUERY_ID();
  SELECT SYSTEM$LOCATE_DBT_ARTIFACTS(:qid) INTO :loc;

  REMOVE @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/;
  EXECUTE IMMEDIATE
    'COPY FILES INTO @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/ FROM ''' || :loc ||
    ''' FILES = (''dbt_artifacts.zip'')';

  RETURN 'dbt docs refreshed from query ' || :qid;
END;
$$;

-- First run by hand to verify:
-- CALL ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS();
-- LS @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/;
