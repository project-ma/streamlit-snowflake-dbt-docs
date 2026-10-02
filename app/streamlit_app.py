"""
dbt Docs viewer for Streamlit in Snowflake.

The app code lives in GitLab. The docs content does NOT: a scheduled task runs
`dbt docs generate --static` on the dbt project object and copies the resulting
dbt_artifacts.zip into a stage. This app extracts static_index.html from that
zip and renders it, so docs refresh without redeploying the app.
"""
import io
import zipfile

import streamlit as st
import streamlit.components.v1 as components
from snowflake.snowpark.context import get_active_session

# Keep in sync with sql/03_docs_stage.sql and sql/04_refresh_procedure.sql
DOCS_STAGE = "@ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS"
ZIP_PATH = f"{DOCS_STAGE}/latest/dbt_artifacts.zip"

st.set_page_config(page_title="dbt Docs", layout="wide")
session = get_active_session()


@st.cache_data(ttl=900, show_spinner="Loading dbt docs…")
def load_docs():
    """Return (html, last_modified) for the latest generated docs, or (None, None)."""
    listing = session.sql(f"LIST {DOCS_STAGE}/latest/").collect()
    zips = [r for r in listing if r["name"].endswith("dbt_artifacts.zip")]
    if not zips:
        return None, None
    last_modified = zips[0]["last_modified"]

    with session.file.get_stream(ZIP_PATH) as f:
        archive = zipfile.ZipFile(io.BytesIO(f.read()))

    candidates = [n for n in archive.namelist() if n.endswith("static_index.html")]
    if not candidates:
        return None, last_modified
    return archive.read(candidates[0]).decode("utf-8"), last_modified


html, generated_at = load_docs()

if html is None:
    st.warning(
        "No generated docs found yet. Run "
        "`CALL ANALYTICS.DBT_DOCS.REFRESH_DBT_DOCS();` in a worksheet, "
        "or wait for the scheduled task."
    )
    st.stop()

top_left, top_right = st.columns([4, 1])
top_left.caption(f"Docs generated: {generated_at}")
if top_right.button("Reload", use_container_width=True):
    load_docs.clear()
    st.rerun()

components.html(html, height=1100, scrolling=True)
