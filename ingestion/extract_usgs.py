"""
USGS Earthquake GeoJSON feeds
Docs: https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php
FeatureCollection: metadata, bbox, features[{properties{...}, geometry{Point [lon,lat,depth]}, id}]
We ingest FULL GeoJSON feed payload unchanged.
"""

import argparse
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
from ingestion.common.config import ts_now

FEED_BASE = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary"

def run(feed: str = "all_hour"):
    """
    feed examples: all_hour, all_day, 2.5_day, 4.5_week, etc.
    """
    url = f"{FEED_BASE}/{feed}.geojson"
    data = http_get_json(url)

    s3_key = f"usgs/earthquakes/{feed}/{ts_now()}.geojson.gz"
    uri = put_json(data, s3_key, compress=True, metadata={"source": "usgs-geojson"})
    print(f"[usgs] wrote: {uri}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--feed", default="all_day")
    args = ap.parse_args()
    run(args.feed)
