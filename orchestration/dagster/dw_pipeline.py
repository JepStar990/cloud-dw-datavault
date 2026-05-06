"""
Dagster job to orchestrate all six extractors followed by dbt build and dashboard.
Run locally:  dagster dev -f orchestration/dagster/dw_pipeline.py
Launch "Materialize" from UI or run via CLI using 'dagster job execute'.
"""

import os
import subprocess
from dagster import op, job

# Import modules via package path (ensure PYTHONPATH includes repo root)
from ingestion.extract_worldbank import run as wb_run
from ingestion.extract_weather import run as weather_run
from ingestion.extract_wikimedia import run as wm_run
from ingestion.extract_github import run as gh_run
from ingestion.extract_openaq import run as openaq_run
from ingestion.extract_usgs import run as usgs_run

REPO_DIR = os.path.expanduser("~/cloud-dw-datavault")

@op
def worldbank_op():
    wb_run(indicator="SP.POP.TOTL", country="ZA")

@op
def weather_op():
    weather_run(lat=-26.2041, lon=28.0473, hourly="temperature_2m,relativehumidity_2m", daily="")

@op
def wikimedia_op():
    wm_run(project="en.wikipedia.org", article="Nelson_Mandela", access="all-access",
           agent="all-agents", granularity="daily", start="20250101", end="20250107")

@op
def github_op():
    gh_run(owner="octocat", repo="Hello-World")

@op
def openaq_op():
    sensor_id = int(os.getenv("OPENAQ_SENSOR_ID", "3917"))
    openaq_run(sensor_id=sensor_id, resource="measurements", limit=1000)

@op
def usgs_op():
    usgs_run(feed="all_day")

@op
def dbt_build_op():
    subprocess.run(
        ["dbt", "build", "--project-dir", os.path.join(REPO_DIR, "dbt"),
         "--select", "path:models/staging,path:models/business_vault,path:models/marts"],
        check=True
    )

@op
def dashboard_op():
    subprocess.run(
        ["python3", "-m", "reports.generate_dashboard"],
        cwd=REPO_DIR,
        check=True
    )
    # Auto-commit and push to keep GitHub Pages up-to-date
    subprocess.run(
        ["git", "-C", REPO_DIR, "add", "reports/dw_dashboard.html"],
        check=True
    )
    result = subprocess.run(
        ["git", "-C", REPO_DIR, "diff", "--cached", "--quiet"],
        capture_output=True
    )
    if result.returncode != 0:
        subprocess.run(
            ["git", "-C", REPO_DIR, "commit", "-m",
             "Update warehouse dashboard [skip ci]"],
            check=True
        )
        subprocess.run(
            ["git", "-C", REPO_DIR, "push"],
            check=True
        )

@job
def dw_pipeline():
    extracts = [worldbank_op(), weather_op(), wikimedia_op(),
                github_op(), openaq_op(), usgs_op()]
    build = dbt_build_op()
    for e in extracts:
        build.add_upstream(e)
    dashboard_op().add_upstream(build)
