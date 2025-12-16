"""
GitHub REST /repos/{owner}/{repo}/commits
Docs: https://docs.github.com/en/rest/commits/commits
We ingest the FULL JSON commit list (including 'verification', 'commit{...}', 'author', 'committer', 'parents').
Supports optional GITHUB_TOKEN for higher rate limits.
"""

import argparse
import os
from typing import Dict
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
from ingestion.common.config import ts_now

def run(owner: str, repo: str, branch_or_sha: str = None):
    base = f"https://api.github.com/repos/{owner}/{repo}/commits"
    headers: Dict[str, str] = {"Accept": "application/vnd.github+json"}
    token = os.getenv("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    params = {}
    if branch_or_sha:
        params["sha"] = branch_or_sha

    data = http_get_json(base, headers=headers, params=params)

    s3_key = f"github/{owner}/{repo}/{ts_now()}.json.gz"
    uri = put_json(data, s3_key, compress=True, metadata={"source": "github-commits"})
    print(f"[github] wrote: {uri}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--owner", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--sha", default=None, help="Branch or SHA (optional)")
    args = ap.parse_args()
    run(args.owner, args.repo, args.sha)
