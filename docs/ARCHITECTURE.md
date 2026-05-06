# Architecture

## Overview

cloud-dw-datavault is a free-tier-friendly data platform on AWS that implements the Data Vault 2.0 methodology. It ingests full JSON payloads from six public APIs into an S3 Raw Vault, then transforms them using DuckDB and dbt into a Business Vault with hubs, links, satellites, and PIT (Point-In-Time) tables for analytics.

## System Architecture

```
                    +-------------------+
                    |   Public APIs      |
                    | (6 data sources)   |
                    +--------+----------+
                             |
                             v
              +--------------+--------------+
              |     Ingestion Layer         |
              |  (Python extractors on EC2) |
              +--------------+--------------+
                             |
                             v
              +--------------+--------------+
              |        S3 Raw Vault         |
              |  (versioned, SSE, blocked   |
              |   public access)            |
              +--------------+--------------+
                             |
                             v
              +--------------+--------------+
              |     Transformation Layer    |
              |  DuckDB + dbt (on EC2)       |
              |  - Staging (normalize JSON) |
              |  - Business Vault           |
              |  - PIT tables               |
              |  - Marts (analytics views)  |
              +--------------+--------------+
                             |
                             v
              +--------------+--------------+
              |    Presentation Layer       |
              |  Metabase (Docker)          |
              |  + Dagster (orchestration)  |
              +-----------------------------+
```

## Data Vault 2.0 Design

### Layer 1: Raw Vault (S3)
Immutable storage of full JSON payloads from each source. Files are gzipped and organized by data source, entity, and timestamp. Versioning is enabled on the S3 bucket for auditability.

### Layer 2: Staging
dbt views that use DuckDB's `read_json_auto()` to parse raw JSON from S3 directly. Each staging model normalizes one source's JSON into a flat relational structure.

### Layer 3: Business Vault

**Hubs** — Unique business keys with hash primary keys.
- `hub_country` — ISO3 country codes
- `hub_indicator` — World Bank indicator IDs
- `hub_article` — Wikipedia article titles
- `hub_commit` — GitHub commit SHAs
- `hub_location` — Latitude/longitude pairs
- `hub_sensor` — OpenAQ sensor IDs

**Links** — Many-to-many relationships between hubs.
- `link_country_indicator` — Which indicators exist for which countries
- `link_project_article` — Which articles belong to which wiki projects

**Satellites** — Descriptive attributes with insert-only change tracking.
- `sat_country_indicator_values` — Population values, units, observation status
- `sat_article_views` — Page view counts, access type, agent type
- `sat_weather_hourly` — Temperature, humidity measurements
- `sat_commit_meta` — Author, committer, message, verification status
- `sat_sensor_measurements` — Air quality values, coordinates

### Layer 4: PIT Tables
Pre-computed point-in-time tables that join hubs with their latest satellite data at common grains:
- `pit_article_day` — Daily article views
- `pit_country_indicator_year` — Yearly indicator values
- `pit_weather_daily` — Daily weather averages
- `pit_openaq_hourly` — Hourly air quality
- `pit_usgs_daily` — Daily earthquake summary
- `pit_github_daily` — Commit metadata snapshot

### Layer 5: Marts
Analytics views joining PIT tables with hubs and links:
- `article_traffic_daily` — Article view traffic by project
- `population_by_country_year` — Population over time
- `weather_hourly` — Temperature and humidity by location
- `air_quality_measurements` — Sensor readings with coordinates
- `earthquake_recent` — Recent seismic events
- `commit_history` — GitHub commit log

## Hashing Standard

All hash keys use SHA-256 with standardized inputs:
```
SHA-256(UPPER(TRIM(business_key)))
```

For composite keys in links:
```
SHA-256(UPPER(TRIM(key1)) || '|' || UPPER(TRIM(key2)))
```

For natural keys in satellites:
```
SHA-256(UPPER(TRIM(key1)) || '|' || UPPER(TRIM(key2)) || '|' || UPPER(TRIM(time_dimension)))
```

Hash diffs for change detection:
```
SHA-256(UPPER(TRIM(
  COALESCE(CAST(attr1 AS VARCHAR), 'NULL') || '|' ||
  COALESCE(attr2, 'NULL') || '|' || ...
)))
```

## Data Flow

1. **Extraction**: Python scripts call public APIs, store full JSON in S3 with gzip compression.
2. **Staging**: dbt runs DuckDB `read_json_auto()` against S3 globs to parse JSON into views.
3. **Business Vault**: Hubs, links, and satellites are built from staging views using hash keys.
4. **PIT**: Point-in-time tables aggregate satellite data at standard time grains.
5. **Marts**: Analytics views join hubs, links, and PIT tables for end-user queries.
6. **Orchestration**: Dagster schedules extraction → dbt build → testing in sequence.

## Security Design

- S3 Block Public Access enabled (all four settings)
- IAM roles with least privilege (S3 access limited to raw vault bucket)
- API keys via environment variables, never in source code
- EC2 instance profile for credential-free AWS access
- S3 versioning for immutable audit trail
- gzip compression on all stored payloads

## Cost Optimization

- t3.micro EC2 (free tier eligible)
- S3 lifecycle policies can transition to IA/Glacier after 30-60 days
- DuckDB runs locally (no database server costs)
- Metabase runs on the same EC2 instance via Docker
- All tools are open source
