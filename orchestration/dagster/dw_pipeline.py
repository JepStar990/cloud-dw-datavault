"""
Dagster job to orchestrate all six extractors.
Run locally:  dagit -f orchestration/dagster/dw_pipeline.py
Launch "Materialize" from UI or run via CLI using 'dg launch' (Dagster 1.6+).
"""

import os
from dagster import op, job

# Import modules via package path (ensure PYTHONPATH includes repo root)
from ingestion.extract_worldbank import run as wb_run
from ingestion.extract_weather import run as weather_run
from ingestion.extract_wikimedia import run as wm_run
from ingestion.extract_github import run as gh_run
from ingestion.extract_openaq import run as openaq_run
from ingestion.extract_usgs import run as usgs_run

@op
def worldbank_op():
    # Example params (South Africa total population)
    wb_run(indicator="SP.POP.TOTL", country="ZA")

@op
def weather_op():
    # Johannesburg area approx
    weather_run(lat=-26.2041, lon=28.0473, hourly="temperature_2m,relativehumidity_2m", daily="")

@op
def wikimedia_op():
    # Nelson Mandela pageviews daily for a short range example
    wm_run(project="en.wikipedia.org", article="Nelson_Mandela", access="all-access",
           agent="all-agents", granularity="daily", start="20250101", end="20250107")

@op
def github_op():
    # Public repo example (adjust to your org)
    gh_run(owner="octocat", repo="Hello-World")

@op
def openaq_op():
    # Example sensor (replace with a valid sensor ID from OpenAQ); requires OPENAQ_API_KEY env.
    sensor_id = int(os.getenv("OPENAQ_SENSOR_ID", "3917"))
    openaq_run(sensor_id=sensor_id, resource="measurements", limit=1000)

@op
def usgs_op():
    usgs_run(feed="all_day")

@job
def dw_pipeline():
    worldbank_op()
    weather_op()
    wikimedia_op()
    github_op()
    openaq_op()
    usgs_op()
