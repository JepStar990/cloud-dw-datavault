import gzip
import json
import os
from io import BytesIO
from typing import Any, Dict, Optional

import boto3
from botocore.config import Config
from .config import S3_BUCKET, AWS_REGION

# Boto3 S3 client: will use instance role or local profile/env automatically
_s3 = boto3.client("s3", region_name=AWS_REGION, config=Config(retries={"max_attempts": 5}))

def put_json(
    data: Any,
    key: str,
    compress: bool = True,
    metadata: Optional[Dict[str, str]] = None,
) -> str:
    """
    Save full JSON payload to S3 Raw Vault.
    - data: any Python object (dict/list)
    - key: S3 object key (path inside bucket)
    - compress: store gzip for lower storage cost
    - metadata: optional metadata dict
    Returns: s3:// URI
    """
    body_bytes: bytes
    json_bytes = json.dumps(data, ensure_ascii=False).encode("utf-8")

    if compress:
        buf = BytesIO()
        with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
            gz.write(json_bytes)
        body_bytes = buf.getvalue()
        content_type = "application/json"
        content_encoding = "gzip"
    else:
        body_bytes = json_bytes
        content_type = "application/json"
        content_encoding = None

    put_kwargs = {
        "Bucket": S3_BUCKET,
        "Key": key,
        "Body": body_bytes,
        "ContentType": content_type,
    }
    if content_encoding:
        put_kwargs["ContentEncoding"] = content_encoding
    if metadata:
        put_kwargs["Metadata"] = metadata

    _s3.put_object(**put_kwargs)
    return f"s3://{S3_BUCKET}/{key}"
