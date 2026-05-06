# Architecture

## Overview

cloud-dw-datavault is a free-tier-friendly data platform on AWS that implements the Data Vault 2.0 methodology. It ingests full JSON payloads from six public APIs into an S3 Raw Vault, then transforms them using DuckDB and dbt into a Business Vault with hubs, links, satellites, and PIT (Point-In-Time) tables for analytics.

## System Architecture

```mermaid
flowchart TB
    subgraph Sources["Public APIs (6 sources)"]
        WB[World Bank]
        WIKI[Wikimedia Pageviews]
        OM[Open-Meteo Weather]
        USGS[USGS Earthquakes]
        OAQ[OpenAQ Air Quality]
        GH[GitHub Commits]
    end

    subgraph Ingestion["Ingestion Layer (EC2 Python)"]
        direction LR
        E1[extract_worldbank.py]
        E2[extract_wikimedia.py]
        E3[extract_openmeteo.py]
        E4[extract_usgs.py]
        E5[extract_openaq.py]
        E6[extract_github.py]
    end

    WB --> E1
    WIKI --> E2
    OM --> E3
    USGS --> E4
    OAQ --> E5
    GH --> E6

    subgraph Storage["S3 Raw Vault"]
        S3[("s3://cloud-dw-datavault-raw-vault<br/>versioned · SSE · blocked public access")]
    end

    E1 & E2 & E3 & E4 & E5 & E6 --> S3

    subgraph Transform["Transformation Layer (DuckDB + dbt on EC2)"]
        direction TB
        STG[6 staging views<br/>read_json_auto from S3]
        BV[Business Vault<br/>6 hubs · 2 links · 5 satellites]
        PIT[6 PIT tables<br/>point-in-time snapshots]
        MARTS[6 mart views<br/>end-user analytics]
        STG --> BV --> PIT --> MARTS
    end

    S3 --> STG

    subgraph Present["Presentation"]
        MB[Metabase]
        DG[Dagster orchestration]
    end

    MARTS --> MB
    DG -.->|schedules| Ingestion
    DG -.->|schedules| Transform
```

## Data Vault 2.0 Layers

```mermaid
flowchart LR
    subgraph L1["Layer 1 — Raw Vault"]
        S3_RAW["Immutable JSON payloads in S3<br/>gzipped · versioned · organized by source"]
    end

    subgraph L2["Layer 2 — Staging"]
        STG_V["stg_worldbank · stg_wikimedia · stg_openmeteo<br/>stg_usgs · stg_openaq · stg_github"]
    end

    subgraph L3["Layer 3 — Business Vault"]
        direction TB
        HUBS["Hubs<br/>hub_country · hub_indicator · hub_article<br/>hub_commit · hub_location · hub_sensor"]
        LINKS["Links<br/>link_country_indicator<br/>link_project_article"]
        SATS["Satellites<br/>sat_country_indicator_values · sat_article_views<br/>sat_weather_hourly · sat_commit_meta<br/>sat_sensor_measurements"]
    end

    subgraph L4["Layer 4 — PIT Tables"]
        PITS["pit_article_day · pit_country_indicator_year<br/>pit_weather_daily · pit_openaq_hourly<br/>pit_usgs_daily · pit_github_daily"]
    end

    subgraph L5["Layer 5 — Marts"]
        MARTS_V["article_traffic_daily · population_by_country_year<br/>weather_hourly · air_quality_measurements<br/>earthquake_recent · commit_history"]
    end

    L1 --> L2 --> L3 --> L4 --> L5
```

## Entity-Relationship Diagram

```mermaid
erDiagram
    hub_country ||--o{ link_country_indicator : "hk_country"
    hub_indicator ||--o{ link_country_indicator : "hk_indicator"
    link_country_indicator ||--o| sat_country_indicator_values : "hk_country_indicator"
    link_country_indicator ||--o{ pit_country_indicator_year : "hk_country_indicator"

    hub_article ||--o{ link_project_article : "hk_article"
    link_project_article ||--o| sat_article_views : "hk_project_article"
    link_project_article ||--o{ pit_article_day : "hk_project_article"

    hub_location ||--o| sat_weather_hourly : "hk_location"
    hub_location ||--o{ pit_weather_daily : "hk_location"

    hub_commit ||--o| sat_commit_meta : "hk_commit"
    hub_commit ||--o{ pit_github_daily : "hk_commit"

    hub_sensor ||--o| sat_sensor_measurements : "hk_sensor"
    hub_sensor ||--o{ pit_openaq_hourly : "hk_sensor"

    hub_location ||--o{ pit_usgs_daily : "hk_location"

    pit_article_day ||--o{ article_traffic_daily : joins
    hub_article ||--o{ article_traffic_daily : joins
    link_project_article ||--o{ article_traffic_daily : joins

    pit_country_indicator_year ||--o{ population_by_country_year : joins
    pit_weather_daily ||--o{ weather_hourly : joins
    pit_openaq_hourly ||--o{ air_quality_measurements : joins
    pit_usgs_daily ||--o{ earthquake_recent : joins
    pit_github_daily ||--o{ commit_history : joins
```

## Orchesration DAG

```mermaid
flowchart TD
    T0["Dagster Schedule<br/>runs daily or on-demand"] --> T1

    subgraph extract["Extract (parallel)"]
        T1[worldbank] & T2[wikimedia] & T3[openmeteo]
        T4[usgs] & T5[openaq] & T6[github]
    end

    T1 & T2 & T3 & T4 & T5 & T6 --> T7

    T7["dbt build<br/>staging → business_vault → marts"]
    T7 --> T8["dbt test<br/>not_null · unique · referential"]

    T8 --> T9{{"All tests pass?"}}
    T9 -->|yes| T10["Dagster run succeeds"]
    T9 -->|no| T11["Alert / retry"]
```

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
