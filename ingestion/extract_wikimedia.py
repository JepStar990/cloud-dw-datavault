# ingestion/extract_wikimedia.py
import argparse
from urllib.parse import quote
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
from ingestion.common.config import ts_now

def run(project: str, article: str, access: str, agent: str, granularity: str, start: str, end: str):
    encoded_article = quote(article, safe="")  # encode path segment safely
    base = (
        f"https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/"
        f"{project}/{access}/{agent}/{encoded_article}/{granularity}/{start}/{end}"
    )
    data = http_get_json(base)

    s3_key = f"wikimedia/{project}/{encoded_article}/{start}_{end}/{ts_now()}.json.gz"
    uri = put_json(data, s3_key, compress=True, metadata={"source": "wikimedia-pageviews"})
    print(f"[wikimedia] wrote: {uri}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True, help="e.g., en.wikipedia.org")
    ap.add_argument("--article", required=True, help="e.g., Nelson_Mandela")
    ap.add_argument("--access", default="all-access")
    ap.add_argument("--agent", default="all-agents")
    ap.add_argument("--granularity", default="daily")
    ap.add_argument("--start", required=True, help="e.g., 20250101")
    ap.add_argument("--end", required=True, help="e.g., 20250107")
    args = ap.parse_args()
    run(args.project, args.article, args.access, args.agent, args.granularity, args.start, args.end)
