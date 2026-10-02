-- =====================================================================
-- 02  Connect Snowflake to this GitLab repository
-- Run once as ACCOUNTADMIN, AFTER 01_roles_and_schema.sql.
--
-- GitLab token: create a Project Access Token on this repo
--   (Settings > Access tokens), role Reporter, scope read_repository.
--   Add write_repository only if you want to push from Snowsight.
-- For a self-managed GitLab, swap https://gitlab.com for your host.
-- =====================================================================
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SECRET ANALYTICS.DBT_DOCS.GITLAB_TOKEN
  TYPE = password
  USERNAME = 'oauth2'                      -- any non-empty value works with a GitLab token
  PASSWORD = '<paste-gitlab-project-access-token>';

CREATE OR REPLACE API INTEGRATION GITLAB_DBT_DOCS_API
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://gitlab.com/your-group')
  ALLOWED_AUTHENTICATION_SECRETS = (ANALYTICS.DBT_DOCS.GITLAB_TOKEN)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION GITLAB_DBT_DOCS_API TO ROLE DBT_DOCS_ADMIN;
GRANT USAGE ON SECRET ANALYTICS.DBT_DOCS.GITLAB_TOKEN TO ROLE DBT_DOCS_ADMIN;

USE ROLE DBT_DOCS_ADMIN;

CREATE OR REPLACE GIT REPOSITORY ANALYTICS.DBT_DOCS.DBT_DOCS_REPO
  API_INTEGRATION = GITLAB_DBT_DOCS_API
  GIT_CREDENTIALS = ANALYTICS.DBT_DOCS.GITLAB_TOKEN
  ORIGIN = 'https://gitlab.com/your-group/dbt-docs-streamlit.git';

-- Sanity check: should list app/, sql/, README.md ...
LS @ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/;
