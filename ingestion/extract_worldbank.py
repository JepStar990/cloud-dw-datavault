"""
World Bank Indicators API v2
Docs: https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation
Schema fields commonly present: indicator{id,name}, country{id,name}, countryiso3code, date, value, unit, obs_status, decimal
We ingest the full JSON array(s): metadata + observations (no trimming).
"""

import argparse
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
from ingestion.common.config import ts_now

def run(indicator: str, country: str):
    url = f"https://api.worldbank.org/v2/country/{country}/indicator/{indicator}"
    params = {"format": "json", "per_page": "20000"}  # get all available rows
    data = http_get_json(url, params=params)

    # S3: worldbank/<indicator>/<country>/<ts>.json.gz
    s3_key = f"worldbank/{indicator}/{country}/{ts_now()}.json.gz"
    uri = put_json(data, s3_key, compress=True, metadata={"source": "worldbank"})
    print(f"[worldbank] wrote: {uri}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--indicator", required=True, help="e.g., SP.POP.TOTL")
    ap.add_argument("--country", required=True, help="e.g., ZA")
    args = ap.parse_args()
    run(args.indicator, args.country)
