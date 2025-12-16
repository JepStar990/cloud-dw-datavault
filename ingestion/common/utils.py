# ingestion/common/utils.py
import os
import time
from typing import Dict, Optional
import requests

DEFAULT_TIMEOUT = int(os.getenv("HTTP_TIMEOUT", "60"))
DEFAULT_RETRIES = int(os.getenv("HTTP_RETRIES", "3"))
SLEEP_BETWEEN_RETRIES = 2  # seconds

# Build a descriptive UA per Wikimedia guidance:
# Include a contact (email or URL) so they can reach you if needed.
CONTACT = os.getenv("HTTP_CONTACT", "mailto:admin@example.com")
APP_NAME = os.getenv("HTTP_APP_NAME", "cloud-dw-datavault")
DEFAULT_UA = f"{APP_NAME}/1.0 (+{CONTACT})"

def http_get_json(
    url: str,
    headers: Optional[Dict[str, str]] = None,
    params: Optional[Dict[str, str]] = None,
):
    """
    Robust GET -> JSON helper with retry, default headers, and backoff on 403/429.

    Always sets a descriptive User-Agent (required by Wikimedia) and Accept header.
    """
    merged_headers = {"User-Agent": DEFAULT_UA, "Accept": "application/json"}
    if headers:
        merged_headers.update(headers)

    for attempt in range(1, DEFAULT_RETRIES + 1):
        resp = requests.get(url, headers=merged_headers, params=params or {}, timeout=DEFAULT_TIMEOUT)
        if resp.ok:
            return resp.json()

        # Friendly backoff on throttling or forbidden (public APIs)
        if resp.status_code in (429, 403) and attempt < DEFAULT_RETRIES:
            time.sleep(SLEEP_BETWEEN_RETRIES * attempt)
            continue

        if attempt < DEFAULT_RETRIES:
            time.sleep(SLEEP_BETWEEN_RETRIES)
    resp.raise_for_status()
