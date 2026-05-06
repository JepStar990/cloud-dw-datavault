"""
Generate a self-contained HTML dashboard from the DuckDB data warehouse.
Output: reports/dw_dashboard.html — deployable to GitHub Pages.
Usage:  python -m reports.generate_dashboard
"""

import json
import os
from datetime import datetime, timezone

import duckdb

DB_PATH = os.getenv("DW_DB_PATH", "/opt/data/dw.duckdb")
OUTPUT = os.path.join(os.path.dirname(__file__), "dw_dashboard.html")
S3_REGION = os.getenv("AWS_REGION", "eu-west-1")

MODELS_BY_LAYER = {
    "staging": [
        "stg_worldbank", "stg_openmeteo", "stg_wikimedia",
        "stg_github", "stg_openaq", "stg_usgs",
    ],
    "hubs": [
        "hub_country", "hub_indicator", "hub_article",
        "hub_location", "hub_commit", "hub_sensor",
    ],
    "links": [
        "link_country_indicator", "link_project_article",
    ],
    "satellites": [
        "sat_country_indicator_values", "sat_article_views",
        "sat_weather_hourly", "sat_commit_meta", "sat_sensor_measurements",
    ],
    "pits": [
        "pit_country_indicator_year", "pit_article_day",
        "pit_weather_daily", "pit_openaq_hourly",
        "pit_usgs_daily", "pit_github_daily",
    ],
    "marts": [
        "population_by_country_year", "article_traffic_daily",
        "weather_hourly", "air_quality_measurements",
        "earthquake_recent", "commit_history",
    ],
}

SOURCE_MAP = {
    "stg_worldbank":    "World Bank",
    "stg_openmeteo":    "Open-Meteo",
    "stg_wikimedia":    "Wikimedia",
    "stg_github":       "GitHub",
    "stg_openaq":       "OpenAQ",
    "stg_usgs":         "USGS",
}


def _query(con, sql):
    try:
        return con.execute(sql).fetchone()[0]
    except Exception:
        return 0


def collect_metrics():
    con = duckdb.connect(DB_PATH)
    con.execute("INSTALL httpfs; LOAD httpfs;")
    con.execute(f"SET s3_region='{S3_REGION}';")

    # Row counts per model
    models = []
    for layer, names in MODELS_BY_LAYER.items():
        for name in names:
            schema = "main_marts" if layer == "marts" else "main"
            n = _query(con, f'select count(*) from {schema}."{name}"')
            models.append({
                "name": name,
                "layer": layer,
                "rows": n,
                "source": SOURCE_MAP.get(name, None),
            })

    # Aggregates
    total_rows = sum(m["rows"] for m in models)
    total_models = len(models)
    sources_with_data = len(set(
        m["source"] for m in models if m["source"] and m["rows"] > 0
    ))

    # Database size
    db_size_bytes = os.path.getsize(DB_PATH) if os.path.exists(DB_PATH) else 0

    # Timestamp
    snapshot_ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    con.close()

    return {
        "models": models,
        "total_rows": total_rows,
        "total_models": total_models,
        "sources_with_data": sources_with_data,
        "total_sources": 6,
        "db_size_mb": round(db_size_bytes / (1024 * 1024), 2),
        "snapshot_ts": snapshot_ts,
    }


def render_html(metrics):
    m = metrics
    models_json = json.dumps(m["models"])
    layers = ["staging", "hubs", "links", "satellites", "pits", "marts"]
    layer_colors = ["#667eea", "#764ba2", "#f093fb", "#f5576c", "#4facfe", "#43e97b"]

    layer_rows = {}
    for layer in layers:
        layer_rows[layer] = sum(mod["rows"] for mod in m["models"] if mod["layer"] == layer)

    # Build chart data
    layer_labels = json.dumps([l.capitalize() for l in layers])
    layer_data = json.dumps([layer_rows[l] for l in layers])
    layer_bg = json.dumps(layer_colors)

    # Per-model table rows
    table_rows = ""
    for mod in m["models"]:
        status = "✅" if mod["rows"] > 0 else "⚠️"
        table_rows += f"""
        <tr>
            <td>{mod['name']}</td>
            <td><span class="badge layer-{mod['layer']}">{mod['layer']}</span></td>
            <td class="num">{mod['rows']:,}</td>
            <td>{status}</td>
        </tr>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>cloud-dw-datavault — Warehouse Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 24px; }}
.header {{ text-align: center; padding: 32px 0; }}
.header h1 {{ font-size: 28px; color: #f8fafc; }}
.header p {{ color: #94a3b8; margin-top: 4px; font-size: 14px; }}
.cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 32px; }}
.card {{ background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 20px; text-align: center; }}
.card .value {{ font-size: 32px; font-weight: 700; color: #f8fafc; }}
.card .label {{ font-size: 12px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; margin-top: 4px; }}
.charts {{ display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 32px; }}
.chart-box {{ background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 24px; }}
.chart-box h3 {{ font-size: 14px; color: #94a3b8; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 0.05em; }}
.chart-box canvas {{ max-height: 320px; }}
.table-box {{ background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 24px; overflow-x: auto; }}
.table-box h3 {{ font-size: 14px; color: #94a3b8; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 0.05em; }}
table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
th {{ text-align: left; padding: 10px 12px; border-bottom: 1px solid #334155; color: #94a3b8; font-weight: 600; text-transform: uppercase; font-size: 11px; letter-spacing: 0.05em; }}
td {{ padding: 10px 12px; border-bottom: 1px solid #1e293b; }}
tr:hover td {{ background: #1e293b; }}
.num {{ text-align: right; font-variant-numeric: tabular-nums; font-family: 'SF Mono', 'Fira Code', monospace; }}
.badge {{ display: inline-block; padding: 2px 10px; border-radius: 100px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; }}
.layer-staging      {{ background: #667eea33; color: #667eea; }}
.layer-hubs         {{ background: #764ba233; color: #a78bfa; }}
.layer-links        {{ background: #f093fb33; color: #f093fb; }}
.layer-satellites   {{ background: #f5576c33; color: #f5576c; }}
.layer-pits         {{ background: #4facfe33; color: #4facfe; }}
.layer-marts        {{ background: #43e97b33; color: #43e97b; }}
.footer {{ text-align: center; padding: 24px; color: #475569; font-size: 12px; }}
@media (max-width: 768px) {{ .charts {{ grid-template-columns: 1fr; }} }}
</style>
</head>
<body>

<div class="header">
    <h1>☁️ cloud-dw-datavault</h1>
    <p>Data Warehouse Health Dashboard · Snapshot {m['snapshot_ts']}</p>
</div>

<div class="cards">
    <div class="card">
        <div class="value">{m['total_models']}</div>
        <div class="label">Total Models</div>
    </div>
    <div class="card">
        <div class="value">{m['total_rows']:,}</div>
        <div class="label">Total Rows</div>
    </div>
    <div class="card">
        <div class="value">{m['sources_with_data']}/{m['total_sources']}</div>
        <div class="label">Sources Active</div>
    </div>
    <div class="card">
        <div class="value">{m['db_size_mb']} MB</div>
        <div class="label">Database Size</div>
    </div>
</div>

<div class="charts">
    <div class="chart-box">
        <h3>Rows by Layer</h3>
        <canvas id="layerChart"></canvas>
    </div>
    <div class="chart-box">
        <h3>Rows by Model</h3>
        <canvas id="modelChart"></canvas>
    </div>
</div>

<div class="table-box">
    <h3>All Models ({m['total_models']})</h3>
    <table>
        <thead>
            <tr><th>Model</th><th>Layer</th><th>Rows</th><th>Status</th></tr>
        </thead>
        <tbody>{table_rows}</tbody>
    </table>
</div>

<div class="footer">
    Generated by cloud-dw-datavault reports engine · {m['snapshot_ts']} · Deploy to GitHub Pages
</div>

<script>
const layerCtx = document.getElementById('layerChart').getContext('2d');
new Chart(layerCtx, {{
    type: 'doughnut',
    data: {{
        labels: {layer_labels},
        datasets: [{{
            data: {layer_data},
            backgroundColor: {layer_bg},
            borderColor: '#0f172a',
            borderWidth: 2
        }}]
    }},
    options: {{
        responsive: true,
        plugins: {{ legend: {{ position: 'bottom', labels: {{ color: '#94a3b8', padding: 16, font: {{ size: 12 }} }} }} }}
    }}
}});

const modelCtx = document.getElementById('modelChart').getContext('2d');
new Chart(modelCtx, {{
    type: 'bar',
    data: {{
        labels: {json.dumps([mod['name'] for mod in m['models']])},
        datasets: [{{
            label: 'Row count',
            data: {json.dumps([mod['rows'] for mod in m['models']])},
            backgroundColor: {json.dumps([layer_colors[layers.index(mod['layer'])] for mod in m['models']])},
            borderRadius: 4
        }}]
    }},
    options: {{
        indexAxis: 'y',
        responsive: true,
        plugins: {{ legend: {{ display: false }} }},
        scales: {{
            x: {{ ticks: {{ color: '#94a3b8' }}, grid: {{ color: '#1e293b' }} }},
            y: {{ ticks: {{ color: '#94a3b8', font: {{ size: 11 }} }}, grid: {{ display: false }} }}
        }}
    }}
}});
</script>
</body>
</html>"""


def main():
    print("Collecting data warehouse metrics...")
    metrics = collect_metrics()

    print("Generating dashboard...")
    html = render_html(metrics)

    with open(OUTPUT, "w") as f:
        f.write(html)

    print(f"Dashboard written to {OUTPUT}")
    print(f"  {metrics['total_models']} models, {metrics['total_rows']:,} rows, "
          f"{metrics['sources_with_data']}/{metrics['total_sources']} sources active")


if __name__ == "__main__":
    main()
