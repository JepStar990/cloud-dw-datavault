"""
OpenAQ v3
Docs: https://docs.openaq.org/  | Measurements resource: https://docs.openaq.org/resources/measurements
Requires API key (set OPENAQ_API_KEY env). We ingest FULL JSON for sensors/{id}/measurements or /hours /days.
"""

import argparse
import os
from typing import Dict
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
from ingestion.common.config import ts_now

API_BASE = "https://api.openaq.org/v3"

def run(sensor_id: int, resource: str = "measurements", limit: int = 1000, date_from: str = None, date_to: str = None):
    api_key = os.getenv("OPENAQ_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAQ_API_KEY env variable not set")

    headers: Dict[str, str] = {"X-API-Key": api_key}
    url = f"{API_BASE}/sensors/{sensor_id}/{resource}"

    params = {"limit": str(limit)}
    if date_from:
        params["date_from"] = date_from
    if date_to:
        params["date_to"] = date_to

    data = http_get_json(url, headers=headers, params=params)

    s3_key = f"openaq/sensors/{sensor_id}/{resource}/{date_from or 'na'}_{date_to or 'na'}/{ts_now()}.json.gz"
    uri = put_json(data, s3_key, compress=True, metadata={"source": "openaq"})
    print(f"[openaq] wrote: {uri}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--sensor_id", type=int, required=True)
    ap.add_argument("--resource", default="measurements", choices=["measurements","hours","days","years"])
    ap.add_argument("--limit", type=int, default=1000)
    ap.add_argument("--date_from", default=None)
    ap.add_argument("--date_to", default=None)
    args = ap.parse_args()
    run(args.sensor_id, args.resource, args.limit, args.date_from, args.date_to)
