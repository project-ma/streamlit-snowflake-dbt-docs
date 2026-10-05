-- =====================================================================
-- 05  Procedure: pull latest main from GitLab, redeploy the dbt project,
--     generate static docs, copy the artifacts to the docs stage.
--
-- Whether the docs are stored as the raw dbt_artifacts.zip, as an
-- extracted target/ directory, or both, is controlled by ARTIFACT_MODE:
--   'extracted' (default) -> unzipped target/ directory only (what the app reads)
--   'both'                -> keep the zip AND the extracted target/ directory
--   'zip'                 -> keep only the raw dbt_artifacts.zip
--
-- If any step fails the procedure errors before touching the stage,
-- so the app keeps showing the last good docs.
-- =====================================================================
USE ROLE DBT_DOCS_ADMIN;

-- ---------------------------------------------------------------------
-- 05a  Extract a zip on a stage back onto a stage, preserving the
--      archive's relative paths (e.g. dbt_artifacts.zip contains
--      target/static_index.html, target/manifest.json, logs/dbt.log ...).
--
--      SOURCE_ZIP  fully qualified source zip, e.g.
--                    @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/dbt_artifacts.zip
--      DEST_PREFIX destination directory prefix, e.g.
--                    @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest
--                    (files land at <DEST_PREFIX>/<name-from-zip>,
--                     e.g. .../latest/target/static_index.html)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ANALYTICS.DBT_DOCS.EXTRACT_DBT_ARTIFACTS(
  SOURCE_ZIP  STRING,
  DEST_PREFIX STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'extract'
EXECUTE AS OWNER
AS
$$
import io
import zipfile

from snowflake.snowpark import Session


def extract(session: Session, source_zip: str, dest_prefix: str) -> str:
    """Copy every file in the zip at SOURCE_ZIP onto the stage under DEST_PREFIX.

    Only the docs the app serves (the static index and the JSON metadata) are
    written, so we don't stage thousands of compiled-SQL files.
    """
    wanted = ("static_index.html", "manifest.json", "catalog.json")
    dest_prefix = dest_prefix.rstrip("/")

    with session.file.get_stream(source_zip) as f:
        data = f.read()

    written = 0
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for name in z.namelist():
            if name.endswith("/"):
                continue
            base = name.rsplit("/", 1)[-1]
            if base not in wanted:
                continue
            session.file.put_stream(
                io.BytesIO(z.read(name)),
                f"{dest_prefix}/{name}",
                auto_compress=False,
                overwrite=True,
            )
            written += 1

    return f"extracted {written} files into {dest_prefix}/"


-- ---------------------------------------------------------------------
-- 05b  Refresh: fetch repo, deploy dbt project, docs generate, publish
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS(
  ARTIFACT_MODE STRING DEFAULT 'extracted')
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
  loc := SYSTEM$LOCATE_DBT_ARTIFACTS(:qid);

  REMOVE @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/;

  IF (ARTIFACT_MODE IN ('zip', 'both')) THEN
    EXECUTE IMMEDIATE
      'COPY FILES INTO @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/ FROM ''' || :loc ||
      ''' FILES = (''dbt_artifacts.zip'')';
  END IF;

  -- The static docs site (static_index.html) only exists inside the zip, so
  -- extract it unless the caller explicitly asked for the zip only.
  IF (ARTIFACT_MODE IN ('extracted', 'both')) THEN
    IF (ARTIFACT_MODE = 'extracted') THEN
      -- No zip is staged in this mode; pull it straight from the run.
      CALL ANALYTICS.DBT_DOCS.EXTRACT_DBT_ARTIFACTS(
        SYSTEM$LOCATE_DBT_ARCHIVE(:qid),
        '@ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest');
    ELSE
      CALL ANALYTICS.DBT_DOCS.EXTRACT_DBT_ARTIFACTS(
        '@ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/dbt_artifacts.zip',
        '@ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest');
    END IF;
  END IF;

  RETURN 'dbt docs refreshed from query ' || :qid || ' (mode: ' || :ARTIFACT_MODE || ')';
END;
$$;

-- First run by hand to verify (mode defaults to 'extracted'):
-- CALL ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS();
-- LS @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/target/;
-- Keep the raw zip too:
-- CALL ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS('both');
