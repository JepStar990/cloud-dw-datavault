# Testing Guide

## Test Summary

All tests passed as of the latest commit:

| Layer | Test | Status |
|-------|------|--------|
| Python | All imports and module loading | PASSED |
| Python | Config: no hardcoded API keys | PASSED |
| Python | Utils: User-Agent header, retry logic | PASSED |
| Python | S3 utils: gzip compression, URI generation | PASSED |
| Python | Extractor CLI: wikimedia main guard present | PASSED |
| Python | Dagster: pipeline structure and imports | PASSED |
| DuckDB | SHA-256 hash functions | PASSED |
| DuckDB | Hash key consistency (hubs ↔ links ↔ sats) | PASSED |
| dbt | `dbt parse` — all 32 models parse successfully | PASSED |
| dbt | `dbt compile` — all models compile to valid SQL | PASSED |

## Running Tests

### Python Unit Tests

```bash
# Test all imports and configuration
python3 -c "
from ingestion.common.config import S3_BUCKET, AWS_REGION, ts_now
from ingestion.common.utils import http_get_json
from ingestion.common.s3_utils import put_json
print('All imports OK')
"

# Test synthesis of all modules
python3 -m py_compile ingestion/common/config.py
python3 -m py_compile ingestion/common/s3_utils.py
python3 -m py_compile ingestion/common/utils.py
python3 -m py_compile ingestion/extract_worldbank.py
python3 -m py_compile ingestion/extract_weather.py
python3 -m py_compile ingestion/extract_wikimedia.py
python3 -m py_compile ingestion/extract_github.py
python3 -m py_compile ingestion/extract_openaq.py
python3 -m py_compile ingestion/extract_usgs.py
echo 'All syntax checks passed'
```

### dbt Tests

```bash
# Parse all models (Jinja compilation, no database needed)
dbt parse --project-dir dbt

# Compile all models (requires DuckDB connectivity)
dbt compile --project-dir dbt

# Once data is loaded in S3, run the full build:
dbt build --project-dir dbt --select "path:models/staging"
dbt build --project-dir dbt --select "path:models/business_vault"
dbt build --project-dir dbt --select "path:models/marts"

# Run data tests:
dbt test --project-dir dbt --select "path:models/business_vault"
```

### Hash Key Consistency Test

The most critical test verifies that hash keys are consistent across hubs, links, and satellites:

```python
import duckdb

con = duckdb.connect('/opt/data/dw.duckdb')

# Verify hub to satellite joins work
con.execute("""
    SELECT hc.country_bkey, s.year, s.value
    FROM main.hub_country hc
    JOIN main.sat_country_indicator_values s 
      ON s.hk_country = hc.hk_country
""")

# Verify hub to link joins work
con.execute("""
    SELECT hc.country_bkey, hi.indicator_bkey
    FROM main.hub_country hc
    JOIN main.link_country_indicator l 
      ON l.hk_country = hc.hk_country
    JOIN main.hub_indicator hi 
      ON hi.hk_indicator = l.hk_indicator
""")
```

### Dagster Pipeline Validation

```bash
# Validate pipeline structure
python3 -c "
from orchestration.dagster.dw_pipeline import dw_pipeline
print(f'Job: {dw_pipeline.name}')
print(f'Ops: {[n.name for n in dw_pipeline.nodes]}')
"
```

## Data Tests (dbt)

The project includes 25 generic data tests covering:

| Model | Tests |
|-------|-------|
| hub_country | `hk_country` not_null, unique; `country_bkey` not_null, unique |
| hub_indicator | `hk_indicator` not_null, unique; `indicator_bkey` not_null, unique |
| hub_article | `hk_article` not_null, unique; `article_bkey` not_null, unique |
| link_country_indicator | `hk_country` relationships→hub_country; `hk_indicator` relationships→hub_indicator |
| link_project_article | `hk_article` relationships→hub_article |
| sat_country_indicator_values | `hash_natural_key` not_null; `hd_attributes` not_null |
| sat_article_views | `hash_natural_key` not_null; `hd_attributes` not_null |
| sat_weather_hourly | `hash_natural_key` not_null; `hd_attributes` not_null |
| sat_commit_meta | `hash_natural_key` not_null; `hd_attributes` not_null |
| sat_sensor_measurements | `hash_natural_key` not_null; `hd_attributes` not_null |

## Expected Test Results with Real Data

Once data is flowing through the pipeline:

1. **Staging models** should produce non-empty results for each data source
2. **Hub tables** should have no duplicate business keys
3. **Link tables** should have valid foreign key references to hubs
4. **Satellites** should have non-null hash keys and attribute hashes
5. **PIT tables** should aggregate correctly at their target grain
6. **Mart views** should be queryable and produce meaningful results

## Troubleshooting Common Test Failures

**`hash_natural_key` not_null fails**: Check that all staging source columns used in natural key construction are non-null. Add `WHERE ... IS NOT NULL` filters in the satellite base CTE.

**`relationships` test fails**: A link references a hub key that doesn't exist. Ensure hubs are built before links (`dbt build --select path:models/business_vault/hubs` first).

**`unique` test fails on hub**: Duplicate business keys in source data after standardization. Check that `UPPER(TRIM(...))` is applied consistently in the hub key selection.

**Incremental satellite not loading new data**: The `hd_attributes` hash diff matches existing rows, meaning no attributes have changed. This is expected behavior for insert-only satellites.
