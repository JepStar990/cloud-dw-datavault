# Data Models Reference

## Staging Models

Staging models read raw JSON from S3 and normalize into flat relational structures.

### stg_worldbank
Reads World Bank indicator data. The API returns `[{metadata}, [data]]` so the model extracts the second element and unnests observations.

| Column | Type | Description |
|--------|------|-------------|
| indicator_id | VARCHAR | Indicator code (e.g., SP.POP.TOTL) |
| indicator_name | VARCHAR | Human-readable indicator name |
| country_id | VARCHAR | Country code |
| country_name | VARCHAR | Country name |
| country_iso3 | VARCHAR | ISO3 country code |
| year | VARCHAR | Observation year |
| unit | VARCHAR | Unit of measure |
| obs_status | VARCHAR | Observation status |
| decimal_places | VARCHAR | Decimal precision |
| value | DOUBLE | Numeric observation value |

### stg_wikimedia
Reads Wikimedia pageview data. Each dump contains `{"items": [...]}` with timestamped view counts.

| Column | Type | Description |
|--------|------|-------------|
| project | VARCHAR | Wiki project (e.g., en.wikipedia.org) |
| article | VARCHAR | Article title (URL-decoded) |
| granularity | VARCHAR | Time granularity (daily/monthly) |
| access | VARCHAR | Access method (all-access/desktop/mobile) |
| agent | VARCHAR | User agent type (all-agents/user/bot) |
| ts_yyyymmddhh | VARCHAR | Timestamp (YYYYMMDDHH format) |
| views | BIGINT | Page view count |

### stg_openmeteo
Reads Open-Meteo weather data. Hourly arrays are unnested to produce one row per time point.

| Column | Type | Description |
|--------|------|-------------|
| lat | DOUBLE | Latitude |
| lon | DOUBLE | Longitude |
| ts | VARCHAR | ISO timestamp |
| temperature_2m | DOUBLE | Temperature at 2m (Celsius) |
| relativehumidity_2m | DOUBLE | Relative humidity at 2m (%) |

### stg_usgs
Reads USGS earthquake GeoJSON FeatureCollections and flattens feature properties and geometry.

| Column | Type | Description |
|--------|------|-------------|
| feature_id | VARCHAR | USGS event ID |
| title | VARCHAR | Event title |
| magnitude | DOUBLE | Earthquake magnitude |
| epoch_ms | UBIGINT | Event time in epoch milliseconds |
| place | VARCHAR | Location description |
| lon | DOUBLE | Longitude |
| lat | DOUBLE | Latitude |
| depth_km | DOUBLE | Depth in kilometers |

### stg_github
Reads GitHub commit data. Each commit object contains nested author, committer, and verification information.

| Column | Type | Description |
|--------|------|-------------|
| commit_sha | VARCHAR | Commit hash |
| author_name | VARCHAR | Author name |
| author_date | VARCHAR | Author date |
| committer_name | VARCHAR | Committer name |
| message | VARCHAR | Commit message |
| verified | BOOLEAN | Signature verification status |

### stg_openaq
Reads OpenAQ v3 sensor measurements. The `results` array is unnested to produce one row per measurement.

| Column | Type | Description |
|--------|------|-------------|
| sensor_id | BIGINT | Sensor identifier |
| parameter | VARCHAR | Measured parameter (e.g., pm25) |
| unit | VARCHAR | Unit of measure |
| date_utc | VARCHAR | UTC timestamp |
| value | DOUBLE | Measurement value |
| lat | DOUBLE | Sensor latitude |
| lon | DOUBLE | Sensor longitude |

## Business Vault Models

### Hubs

All hubs share the same structure:
- `hk_<entity>` — SHA-256 hash of the business key (primary key)
- `<entity>_bkey` — The business key itself
- `load_dt` — Load timestamp

### Links

All links share the same structure:
- `hk_<relationship>` — SHA-256 hash of concatenated standardized keys
- `hk_<parent1>`, `hk_<parent2>` — Foreign keys to parent hubs
- `load_dt` — Load timestamp

### Satellites

All satellites share the same structure:
- `hk_<parent>` — Foreign key to parent hub
- `hash_natural_key` — SHA-256 hash of the full natural key including time dimension
- `hd_attributes` — SHA-256 hash diff of all descriptive attributes
- Descriptive attributes (domain-specific)
- `load_dt` — Load timestamp

Satellites use incremental loading: only rows with new hash diffs (changed attributes) are inserted. The `unique_key` is `hash_natural_key`.

### PIT Tables

PIT tables pre-join hubs with their latest satellite data at a specific time grain:
- `pit_article_day` — Grouped by article + project + day
- `pit_country_indicator_year` — Grouped by country + indicator + year (MAX value)
- `pit_weather_daily` — Grouped by location + day (AVG temperature/humidity)
- `pit_openaq_hourly` — Direct satellite passthrough at hourly grain
- `pit_usgs_daily` — Direct staging passthrough for recent earthquakes
- `pit_github_daily` — Direct satellite passthrough for commit metadata

## Data Lineage

```
Sources (S3)              Staging               Business Vault              PIT                    Marts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
worldbank/*.json.gz  →  stg_worldbank  →  hub_country
                                          hub_indicator           pit_country_indicator_year  →  population_by_country_year
                                          link_country_indicator
                                          sat_country_indicator_values

wikimedia/*.json.gz  →  stg_wikimedia  →  hub_article
                                          link_project_article    pit_article_day             →  article_traffic_daily
                                          sat_article_views

openmeteo/*.json.gz  →  stg_openmeteo  →  hub_location
                                          sat_weather_hourly      pit_weather_daily           →  weather_hourly

github/*.json.gz     →  stg_github     →  hub_commit
                                          sat_commit_meta         pit_github_daily            →  commit_history

openaq/*.json.gz     →  stg_openaq     →  hub_sensor
                                          sat_sensor_measurements pit_openaq_hourly           →  air_quality_measurements

usgs/*.geojson.gz    →  stg_usgs        (direct passthrough)     pit_usgs_daily               →  earthquake_recent
```

## Incremental Loading Strategy

Satellites are materialized as incremental tables. The deduplication logic:

1. Compute `hash_natural_key` from the full natural key (business keys + time dimension)
2. Compute `hd_attributes` from all descriptive attributes
3. On each run, insert only rows where the combination `(hash_natural_key, hd_attributes)` does not already exist in the target table

This implements insert-only satellite loading: once a fact is recorded, it is never updated. Changed facts get new rows with the same natural key but different attribute hashes.
