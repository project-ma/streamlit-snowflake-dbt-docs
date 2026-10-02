# dbt Docs on Streamlit in Snowflake

One GitLab repo holding your dbt project **and** a Streamlit app that serves its
classic dbt docs site. Everything runs inside Snowflake:

```
GitLab repo ──fetch──▶ Snowflake GIT REPOSITORY
                          │
                          ├─ dbt/  ──DEPLOY──▶ dbt project object ──docs generate --static──▶ dbt_artifacts.zip
                          │                                                                    │ copied to
                          │                                                                    ▼
                          └─ app/  ──CREATE STREAMLIT FROM──▶ DBT_DOCS app ──reads──▶ @DOCS_ARTIFACTS/latest/
```

- **`dbt/`** — your dbt project. Snowflake builds a dbt project object from it.
- **`app/`** — the Streamlit app. It reads the latest generated docs from a stage,
  so docs update without redeploying the app.
- A **Snowflake task** pulls `main`, redeploys the dbt project and regenerates the
  docs daily. **GitLab CI** does the same straight after a merge.

## Repo layout

```
dbt/
  profiles.yml             Profile for running inside Snowflake (edit it)
  README.md                What to copy in, and a checklist
  ...your dbt project...   dbt_project.yml, models/, macros/, ...
app/
  streamlit_app.py         Streamlit entrypoint – unzips and renders static_index.html
  environment.yml          Warehouse-runtime dependencies
sql/
  01_roles_and_schema.sql  Roles, warehouse, schema, grants
  02_git_integration.sql   GitLab secret, API integration, Git repository object
  03_dbt_project.sql       dbt project object from dbt/ (+ optional packages access)
  04_docs_stage.sql        Stage holding the generated docs
  05_refresh_procedure.sql Procedure: fetch, deploy dbt, docs generate, copy zip
  06_task.sql              Daily schedule for the procedure
  deploy_app.sql           (Re)create the Streamlit app from the repo
.gitlab-ci.yml             On merge to main: app/ → redeploy app, dbt/ → refresh docs
```

## 1. Add your dbt project

Put your project in `dbt/` so that `dbt/dbt_project.yml` exists.

**Simple copy** (no history):
```bash
cp -R /path/to/your-dbt-project/. dbt/
rm -rf dbt/target dbt/dbt_packages dbt/logs   # build output, not needed
```

**Keep the old repo's commit history** (from the repo root; `git subtree`
needs `dbt/` to not exist and a clean working tree):
```bash
cp -R dbt /tmp/dbt-templates
git rm -rq dbt && git commit -m "Make room for dbt project"
git subtree add --prefix=dbt https://gitlab.com/your-group/your-dbt-repo.git main
cp /tmp/dbt-templates/README.md dbt/   # optional
# then merge /tmp/dbt-templates/profiles.yml into dbt/profiles.yml
```

Then work through the checklist in `dbt/README.md` (profile name, `prod` target,
role, packages).

## 2. Names to replace

Search and replace across the repo:

| Placeholder | Meaning |
| --- | --- |
| `ANALYTICS` | Database for the app objects |
| `DBT_DOCS` | Schema for the app objects |
| `DBT_TRANSFORMER` | Role your dbt project runs as (`sql/01`, `dbt/profiles.yml`) |
| `TRANSFORM_WH`, `ANALYTICS.DBT` | Warehouse / database / schema in `dbt/profiles.yml` |
| `my_project` | Profile name in `dbt/profiles.yml` = `profile:` in `dbt_project.yml` |
| `https://gitlab.com/your-group` | Your GitLab group URL (or self-managed host) |
| `main` | Default branch, if different |

## 3. Push to GitLab

Create an empty project in GitLab, then:
```bash
git add .
git commit -m "Add dbt project"
git remote add origin https://gitlab.com/your-group/dbt-docs-streamlit.git   # if not added yet
git push -u origin main
```

## 4. Set up Snowflake

1. Create a **GitLab Project Access Token** on the repo: role *Reporter*,
   scope `read_repository`.
2. In a **Snowsight worksheet**, run the SQL files in order:
   `01` → `02` (paste the token into the secret) → `03` → `04` → `05` → `06`.
   In `03`, drop the external access part if you have no `packages.yml`.
3. **Generate the docs once by hand** and check the zip landed:
   ```sql
   CALL ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS();
   LS @ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS/latest/;
   ```
4. **Deploy the app**:
   ```sql
   EXECUTE IMMEDIATE FROM @ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/sql/deploy_app.sql;
   ```
5. Open **Projects → Streamlit → dbt Docs**. Give people access with
   `GRANT ROLE DBT_DOCS_VIEWER TO USER <user>;`.

## 5. Optional: GitLab CI

Add the CI/CD variables listed at the top of `.gitlab-ci.yml` (a service user
with role `DBT_DOCS_ADMIN`, key-pair auth). Then, on merges to `main`:

- changes under `app/` recreate the Streamlit app;
- changes under `dbt/` redeploy the dbt project and regenerate the docs.

Without CI, the daily task still picks up `dbt/` changes, and you can redeploy
the app manually:
```sql
ALTER GIT REPOSITORY ANALYTICS.DBT_DOCS.DBT_DOCS_REPO FETCH;
EXECUTE IMMEDIATE FROM @ANALYTICS.DBT_DOCS.DBT_DOCS_REPO/branches/main/sql/deploy_app.sql;
```

## Notes

- This dbt project object is used for **docs only**. If your production builds
  already run elsewhere (another project object, dbt Cloud, CI), they're unaffected.
  If you later want Snowflake to run your builds too, this object can do it:
  `EXECUTE DBT PROJECT ANALYTICS.DBT_DOCS.DBT_PROJECT ARGS = 'build --target prod';`
- You can also open the repo as a **Snowsight Workspace** to edit and run the
  dbt project in the browser; the project lives in the `dbt/` folder.
- If any step of the refresh fails, the procedure stops before touching the stage,
  so the app keeps showing the last good docs.
- The app caches the docs for 15 minutes; the **Reload** button clears the cache.
- Snowsight's own dbt project details page (DAG, lineage, compiled SQL) may cover
  many users' needs; this app is for the classic docs site.
- Things to verify on the first run: that `LAST_QUERY_ID()` inside the procedure
  returns the `EXECUTE DBT PROJECT` query, and that `dbt_artifacts.zip` contains
  `target/static_index.html`.
