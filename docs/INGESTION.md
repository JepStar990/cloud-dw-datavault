# Ingestion Pipeline

## Overview

Six Python extractors fetch data from public APIs and store full JSON payloads (gzip compressed) in the S3 Raw Vault. All extractors share common utilities for HTTP requests, S3 operations, and configuration.

## Common Modules

### `ingestion/common/config.py`
Central configuration:
- `S3_BUCKET` — Target S3 bucket (default: `cloud-dw-datavault-raw-vault`, override with `RAW_VAULT_BUCKET` env var)
- `AWS_REGION` — AWS region (default: `eu-west-1`, override with `AWS_REGION` env var)
- `ts_now()` — Generates UTC timestamps in `YYYYMMDDTHHMMSSZ` format
- `OPENAQ_API_KEY` — OpenAQ API key from `OPENAQ_API_KEY` environment variable

### `ingestion/common/utils.py`
HTTP client with retry logic:
- `http_get_json(url, headers, params)` — GET request with:
  - Descriptive `User-Agent` header (required by Wikimedia)
  - `Accept: application/json` header
  - Automatic retry on 429 (Too Many Requests) and 403 (Forbidden)
  - Configurable timeout (`HTTP_TIMEOUT` env var, default 60s)
  - Configurable retry count (`HTTP_RETRIES` env var, default 3)
  - Exponential backoff on rate-limit responses
- `DEFAULT_UA` — User-Agent string: `cloud-dw-datavault/1.0 (+<contact>)`

### `ingestion/common/s3_utils.py`
S3 storage:
- `put_json(data, key, compress, metadata)` — Serializes data as JSON, optionally gzip-compresses, and uploads to S3
  - Returns the `s3://` URI of the stored object
  - Uses boto3 with retry configuration (max 5 attempts)
  - Sets `Content-Encoding: gzip` header when compressed
  - Uses AWS credential chain (instance profile, env vars, or config)

## Extractor Details

### World Bank (`extract_worldbank.py`)
Fetches indicator data from the World Bank Indicators API v2.

```bash
python3 -m ingestion.extract_worldbank --indicator SP.POP.TOTL --country ZA
```

- API: `https://api.worldbank.org/v2/country/{code}/indicator/{id}?format=json`
- S3 path: `s3://<bucket>/worldbank/<indicator>/<country>/<ts>.json.gz`
- The API returns `[{page_metadata}, [{indicator_data}, ...]]`
- No authentication required

### Open-Meteo Weather (`extract_weather.py`)
Fetches weather forecasts from Open-Meteo.

```bash
python3 -m ingestion.extract_weather --lat -26.2041 --lon 28.0473 --hourly temperature_2m,relativehumidity_2m
```

- API: `https://api.open-meteo.com/v1/forecast?latitude=<lat>&longitude=<lon>&hourly=<vars>`
- S3 path: `s3://<bucket>/openmeteo/<lat>_<lon>/<ts>.json.gz`
- Supports `--daily` for daily variables
- No authentication required

### Wikimedia Pageviews (`extract_wikimedia.py`)
Fetches per-article pageview metrics from the Wikimedia REST API.

```bash
python3 -m ingestion.extract_wikimedia --project en.wikipedia.org --article Nelson_Mandela --access all-access --agent all-agents --granularity daily --start 20250101 --end 20250107
```

- API: `https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/{project}/{access}/{agent}/{article}/{granularity}/{start}/{end}`
- S3 path: `s3://<bucket>/wikimedia/<project>/<article>/<start>_<end>/<ts>.json.gz`
- **Requires descriptive User-Agent header** with contact information
- Set `HTTP_APP_NAME` and `HTTP_CONTACT` environment variables

### GitHub Commits (`extract_github.py`)
Fetches commit history from the GitHub REST API.

```bash
python3 -m ingestion.extract_github --owner octocat --repo Hello-World
```

- API: `https://api.github.com/repos/{owner}/{repo}/commits`
- S3 path: `s3://<bucket>/github/<owner>/<repo>/<ts>.json.gz`
- Optional `GITHUB_TOKEN` env var for higher rate limits (60 req/hr unauthenticated, 5000 req/hr with token)
- Use `--sha <branch>` to specify a branch or tag

### OpenAQ (`extract_openaq.py`)
Fetches air quality measurements from OpenAQ v3.

```bash
export OPENAQ_API_KEY="your-key"
python3 -m ingestion.extract_openaq --sensor_id 3917 --resource measurements --limit 500
```

- API: `https://api.openaq.org/v3/sensors/{id}/{resource}`
- S3 path: `s3://<bucket>/openaq/sensors/<id>/<resource>/<range>/<ts>.json.gz`
- **Requires API key** — set `OPENAQ_API_KEY` environment variable
- Resource options: `measurements`, `hours`, `days`, `years`
- Optional `--date_from` and `--date_to` for date range filtering

### USGS Earthquakes (`extract_usgs.py`)
Fetches earthquake data from USGS GeoJSON feeds.

```bash
python3 -m ingestion.extract_usgs --feed all_day
```

- API: `https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/{feed}.geojson`
- S3 path: `s3://<bucket>/usgs/earthquakes/<feed>/<ts>.geojson.gz`
- Feed options: `all_hour`, `all_day`, `all_week`, `all_month`, `2.5_day`, `4.5_week`, etc.
- No authentication required

## Error Handling

All extractors use the common `http_get_json()` utility which provides:
- Automatic retry with exponential backoff on 429/403 responses
- Configurable timeout (default 60s)
- Configurable max retries (default 3)
- Descriptive error messages on failure

S3 uploads use boto3's retry configuration (max 5 attempts).

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AWS_REGION` | No | `eu-west-1` | AWS region for S3 |
| `RAW_VAULT_BUCKET` | No | `cloud-dw-datavault-raw-vault` | S3 bucket name |
| `HTTP_APP_NAME` | For Wikimedia | `cloud-dw-datavault` | User-Agent app name |
| `HTTP_CONTACT` | For Wikimedia | `mailto:admin@example.com` | User-Agent contact |
| `HTTP_TIMEOUT` | No | `60` | HTTP request timeout (seconds) |
| `HTTP_RETRIES` | No | `3` | Max retry attempts |
| `OPENAQ_API_KEY` | For OpenAQ | (empty) | OpenAQ API key |
| `GITHUB_TOKEN` | No | (none) | GitHub personal access token |
| `OPENAQ_SENSOR_ID` | No | `3917` | Default sensor for Dagster pipeline |
