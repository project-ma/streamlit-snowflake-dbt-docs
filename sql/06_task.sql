-- =====================================================================
-- 06  Schedule the docs refresh
-- Daily 06:00 Perth. To refresh straight after your prod build instead,
-- replace SCHEDULE with:  AFTER ANALYTICS.DBT.<your_prod_build_task>
-- =====================================================================
USE ROLE DBT_DOCS_ADMIN;

CREATE OR REPLACE TASK ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS_TASK
  WAREHOUSE = DBT_DOCS_WH
  SCHEDULE = 'USING CRON 0 6 * * * Australia/Perth'
AS
  CALL ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS();

ALTER TASK ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS_TASK RESUME;
