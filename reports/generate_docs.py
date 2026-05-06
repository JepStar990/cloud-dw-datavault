"""
Generate a static HTML dbt documentation site from manifest.json and catalog.json.
Output: reports/dbt_docs.html — deployable to GitHub Pages alongside the dashboard.
Usage:  python -m reports.generate_docs
"""

import json
import os
from datetime import datetime, timezone

MANIFEST = os.path.join(os.path.dirname(__file__), "..", "dbt", "target", "manifest.json")
CATALOG = os.path.join(os.path.dirname(__file__), "..", "dbt", "target", "catalog.json")
OUTPUT = os.path.join(os.path.dirname(__file__), "dbt_docs.html")


def load_metadata():
    with open(MANIFEST) as f:
        manifest = json.load(f)
    with open(CATALOG) as f:
        catalog = json.load(f)
    return manifest, catalog


def build_dag_data(manifest):
    """Extract model lineage from manifest for DAG visualization."""
    nodes = manifest.get("nodes", {})
    edges = []
    model_ids = set()
    layer_map = {}

    for node_id, node in nodes.items():
        if node.get("resource_type") != "model":
            continue
        name = node.get("name", node_id)
        model_ids.add(node_id)
        # Categorize by path
        path = node.get("original_file_path", "")
        if "staging" in path:
            layer_map[name] = "staging"
        elif "hubs" in path:
            layer_map[name] = "hubs"
        elif "links" in path:
            layer_map[name] = "links"
        elif "satellites" in path:
            layer_map[name] = "satellites"
        elif "pit" in path:
            layer_map[name] = "pits"
        elif "marts" in path:
            layer_map[name] = "marts"
        elif "raw_vault" in path:
            layer_map[name] = "raw_vault"
        else:
            layer_map[name] = "other"

        deps = node.get("depends_on", {}).get("nodes", [])
        for dep_id in deps:
            # Only include model-to-model edges
            if dep_id in model_ids or True:  # allow source refs too
                dep_name = dep_id.split(".")[-1] if "." in dep_id else dep_id
                edges.append((name, dep_name))

    return edges, layer_map


def build_model_catalog(manifest, catalog):
    nodes = manifest.get("nodes", {})
    sources = manifest.get("sources", {})
    cat_nodes = catalog.get("nodes", {})

    models = []
    for node_id, node in nodes.items():
        if node.get("resource_type") != "model":
            continue
        name = node.get("name", node_id)
        schema = node.get("schema", "main")
        materialized = node.get("config", {}).get("materialized", "view")
        description = node.get("description", "")
        columns = node.get("columns", {})
        depends_on = node.get("depends_on", {}).get("nodes", [])

        col_data = []
        for col_name, col_info in columns.items():
            cat_col = cat_nodes.get(node_id, {}).get("columns", {}).get(col_name, {})
            col_data.append({
                "name": col_name,
                "type": cat_col.get("type", ""),
                "description": col_info.get("description", ""),
                "tests": col_info.get("tests", []),
            })

        models.append({
            "name": name,
            "schema": schema,
            "materialized": materialized,
            "description": description,
            "columns": col_data,
            "depends_on_count": len(depends_on),
        })

    models.sort(key=lambda m: (m["schema"], m["name"]))
    return models


def render_html(models, edges, layer_map):
    snapshot_ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # Build Mermaid DAG from edges
    layer_colors = {
        "staging": "#667eea", "hubs": "#764ba2", "links": "#f093fb",
        "satellites": "#f5576c", "pits": "#4facfe", "marts": "#43e97b",
        "raw_vault": "#94a3b8", "other": "#94a3b8",
    }

    mermaid_lines = ["flowchart LR"]
    seen_nodes = set()
    for src, tgt in edges:
        src_layer = layer_map.get(src, "other")
        tgt_layer = layer_map.get(tgt, "other")
        src_color = layer_colors.get(src_layer, "#94a3b8")
        tgt_color = layer_colors.get(tgt_layer, "#94a3b8")

        src_id = src.replace(".", "_").replace("-", "_")
        tgt_id = tgt.replace(".", "_").replace("-", "_")

        if src not in seen_nodes:
            mermaid_lines.append(f'    {src_id}["{src}"]:::l_{src_layer}')
            seen_nodes.add(src)
        if tgt not in seen_nodes:
            mermaid_lines.append(f'    {tgt_id}["{tgt}"]:::l_{tgt_layer}')
            seen_nodes.add(tgt)
        mermaid_lines.append(f"    {tgt_id} --> {src_id}")

    for layer, color in layer_colors.items():
        mermaid_lines.append(f'    classDef l_{layer} fill:{color}33,stroke:{color},color:{color},stroke-width:1px')

    mermaid_src = "\n".join(mermaid_lines)

    # Legend
    legend_items = "".join(
        f'<span style="display:inline-block;padding:2px 10px;border-radius:100px;font-size:11px;font-weight:600;background:{layer_colors[l]}33;color:{layer_colors[l]};border:1px solid {layer_colors[l]}44;margin:2px;">{l}</span>'
        for l in ["staging", "hubs", "links", "satellites", "pits", "marts"] if l in layer_map.values()
    )

    model_rows = ""
    for m in models:
        badge = {"view": "#43e97b33", "table": "#4facfe33", "incremental": "#f093fb33"}.get(
            m["materialized"], "#667eea33")
        badge_text = {"view": "#43e97b", "table": "#4facfe", "incremental": "#f093fb"}.get(
            m["materialized"], "#667eea")

        cols_html = ""
        for c in m["columns"]:
            tests_str = ", ".join(str(t) for t in c["tests"]) if c["tests"] else "—"
            desc = c["description"] or "—"
            cols_html += f"""
                <tr class="col-row">
                    <td class="col-name">{c['name']}</td>
                    <td class="col-type">{c['type']}</td>
                    <td>{desc}</td>
                    <td class="col-tests">{tests_str}</td>
                </tr>"""

        model_rows += f"""
        <tr class="model-row" onclick="this.nextElementSibling.classList.toggle('open')">
            <td>{m['name']}</td>
            <td>{m['schema']}</td>
            <td><span style="display:inline-block;padding:2px 10px;border-radius:100px;font-size:11px;font-weight:600;background:{badge};color:{badge_text};">{m['materialized']}</span></td>
            <td>{m['description'] or '—'}</td>
            <td>{m['depends_on_count']}</td>
            <td>{len(m['columns'])}</td>
        </tr>
        <tr class="col-detail">
            <td colspan="6">
                <table class="inner-table">
                    <thead>
                        <tr><th>Column</th><th>Type</th><th>Description</th><th>Tests</th></tr>
                    </thead>
                    <tbody>{cols_html}</tbody>
                </table>
            </td>
        </tr>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>dbt Docs — cloud-dw-datavault</title>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>mermaid.initialize({{startOnLoad:true,theme:'dark',themeVariables:{{darkMode:true,background:'#0f172a',primaryColor:'#4facfe',lineColor:'#475569',textColor:'#e2e8f0'}},flowchart:{{useMaxWidth:true,htmlLabels:true,curve:'basis'}}}});</script>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 24px; }}
.header {{ text-align: center; padding: 32px 0; }}
.header h1 {{ font-size: 24px; color: #f8fafc; }}
.header p {{ color: #94a3b8; margin-top: 4px; font-size: 14px; }}
.nav {{ text-align: center; margin-bottom: 24px; }}
.nav a {{ color: #4facfe; margin: 0 12px; font-size: 13px; text-decoration: none; }}
.stats {{ display: flex; gap: 16px; justify-content: center; margin-bottom: 32px; flex-wrap: wrap; }}
.stat {{ background: #1e293b; border: 1px solid #334155; border-radius: 8px; padding: 12px 24px; text-align: center; }}
.stat .value {{ font-size: 22px; font-weight: 700; color: #f8fafc; }}
.stat .label {{ font-size: 11px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; }}
.table-box {{ background: #1e293b; border: 1px solid #334155; border-radius: 12px; overflow: hidden; }}
table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
th {{ text-align: left; padding: 10px 12px; border-bottom: 1px solid #334155; color: #94a3b8; font-weight: 600; text-transform: uppercase; font-size: 11px; letter-spacing: 0.05em; background: #1e293b; }}
td {{ padding: 10px 12px; border-bottom: 1px solid #1e293b; }}
.model-row {{ cursor: pointer; }}
.model-row:hover td {{ background: #1e293b; }}
.col-detail {{ display: none; }}
.col-detail.open {{ display: table-row; }}
.col-detail td {{ padding: 0; background: #0b1120; }}
.inner-table {{ margin: 8px 24px; width: calc(100% - 48px); }}
.inner-table th {{ font-size: 10px; background: transparent; }}
.col-name {{ font-family: 'SF Mono', 'Fira Code', monospace; font-size: 12px; color: #e2e8f0; }}
.col-type {{ font-family: 'SF Mono', 'Fira Code', monospace; font-size: 11px; color: #94a3b8; }}
.col-tests {{ font-family: 'SF Mono', 'Fira Code', monospace; font-size: 11px; color: #43e97b; }}
.footer {{ text-align: center; padding: 24px; color: #475569; font-size: 12px; }}
</style>
</head>
<body>

<div class="header">
    <h1>📚 dbt Documentation</h1>
    <p>Data Vault 2.0 model catalog · Snapshot {snapshot_ts}</p>
</div>

<div class="nav">
    <a href="index.html">Home</a>
    <a href="dw_dashboard.html">Dashboard</a>
    <a href="dbt_docs.html">dbt Docs</a>
</div>

<div class="stats">
    <div class="stat">
        <div class="value">{len(models)}</div>
        <div class="label">Models</div>
    </div>
    <div class="stat">
        <div class="value">{sum(len(m['columns']) for m in models)}</div>
        <div class="label">Columns</div>
    </div>
    <div class="stat">
        <div class="value">{sum(1 for m in models if m['materialized'] == 'incremental')}</div>
        <div class="label">Incremental</div>
    </div>
    <div class="stat">
        <div class="value">{sum(1 for m in models if m['materialized'] == 'table')}</div>
        <div class="label">Tables</div>
    </div>
</div>

<div class="chart-box" style="margin-bottom:24px;">
    <h3>Data Lineage DAG</h3>
    <div style="margin-bottom:12px;">{legend_items}</div>
    <pre class="mermaid" style="background:transparent;font-size:11px;line-height:1.4;overflow-x:auto;">
{mermaid_src}
    </pre>
</div>

<div class="table-box">
    <table>
        <thead>
            <tr><th>Model</th><th>Schema</th><th>Type</th><th>Description</th><th>Refs</th><th>Cols</th></tr>
        </thead>
        <tbody>{model_rows}</tbody>
    </table>
</div>

<div class="footer">
    Generated by cloud-dw-datavault · {snapshot_ts} · Click rows to expand columns
</div>

</body>
</html>"""


def main():
    print("Loading dbt metadata...")
    manifest, catalog = load_metadata()

    print("Building model catalog...")
    models = build_model_catalog(manifest, catalog)

    print("Building DAG data...")
    edges, layer_map = build_dag_data(manifest)

    print("Rendering docs site...")
    html = render_html(models, edges, layer_map)

    with open(OUTPUT, "w") as f:
        f.write(html)

    print(f"dbt docs written to {OUTPUT}")
    print(f"  {len(models)} models documented")


if __name__ == "__main__":
    main()
