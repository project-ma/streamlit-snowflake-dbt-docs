"""
dbt Docs viewer for Streamlit in Snowflake.

The app code lives in GitLab. The docs content does NOT: a scheduled task runs
`dbt docs generate --static` on the dbt project object and publishes the result
to a stage as an extracted `target/` directory (the raw `dbt_artifacts.zip` is
optional). This app reads `static_index.html` straight from that directory, so
docs refresh without redeploying the app.
"""
import streamlit as st
import streamlit.components.v1 as components
from snowflake.snowpark.context import get_active_session

# Keep in sync with sql/04_docs_stage.sql and sql/05_refresh_procedure.sql
DOCS_STAGE = "@ANALYTICS.DBT_DOCS.DOCS_ARTIFACTS"
DOCS_DIR = f"{DOCS_STAGE}/latest/target"   # unzipped dbt target/ directory
INDEX_PATH = f"{DOCS_DIR}/static_index.html"

st.set_page_config(page_title="dbt Docs", layout="wide")
session = get_active_session()


@st.cache_data(ttl=900, show_spinner="Loading dbt docs…")
def load_docs():
    """Return (html, last_modified) for the latest generated docs, or (None, None)."""
    listing = session.sql(f"LIST {DOCS_DIR}/").collect()
    index = [r for r in listing if r["name"].endswith("static_index.html")]
    if not index:
        return None, None
    last_modified = index[0]["last_modified"]

    with session.file.get_stream(INDEX_PATH) as f:
        html = f.read().decode("utf-8")
    return html, last_modified


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
