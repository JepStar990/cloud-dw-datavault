import os
from datetime import datetime, timezone

# S3 bucket (Raw Vault)
S3_BUCKET = os.getenv("RAW_VAULT_BUCKET", "cloud-dw-datavault-raw-vault")

# Default region (used in S3 client if desired)
AWS_REGION = os.getenv("AWS_REGION", "eu-west-1")

# Timestamp helper (UTC, ISO-like)
def ts_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

OPENAQ_API_KEY = os.getenv("OPENAQ_API_KEY", "")
