"""
Open-Meteo API
Docs: https://open-meteo.com/en/docs
We request any set of hourly/daily variables; payload includes latitude/longitude/timezone,
hourly_units/hourly arrays, etc. We store the FULL JSON response.
"""

import argparse
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
from ingestion.common.config import ts_now

def run(lat: float, lon: float, hourly: str = "temperature_2m,relativehumidity_2m", daily: str = ""):
    base = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "timezone": "auto",
        "hourly": hourly,
    }
    if daily:
        params["daily"] = daily
    data = http_get_json(base, params=params)

    s3_key = f"openmeteo/{lat}_{lon}/{ts_now()}.json.gz"
    uri = put_json(data, s3_key, compress=True, metadata={"source": "open-meteo"})
    print(f"[open-meteo] wrote: {uri}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--lat", type=float, required=True)
    ap.add_argument("--lon", type=float, required=True)
    ap.add_argument("--hourly", default="temperature_2m,relativehumidity_2m")
    ap.add_argument("--daily", default="")
    args = ap.parse_args()
    run(args.lat, args.lon, args.hourly, args.daily)
