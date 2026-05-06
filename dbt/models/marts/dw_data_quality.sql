{{ config(materialized="table") }}

-- Per-model data quality scores: completeness, uniqueness, freshness

with stg_metrics as (
  select
    'stg_worldbank' as model, 'staging' as layer, count(*) as row_count,
    count(value) * 1.0 / nullif(count(*), 0) as fill_rate,
    count(distinct country_iso3) as distinct_keys,
    min(year) as earliest, max(year) as latest,
    count(distinct year) as span
  from {{ ref('stg_worldbank') }}
  union all
  select 'stg_openmeteo', 'staging', count(*),
    count(temperature_2m) * 1.0 / nullif(count(*), 0),
    count(distinct lat || '|' || lon), min(ts), max(ts), count(distinct ts)
  from {{ ref('stg_openmeteo') }}
  union all
  select 'stg_wikimedia', 'staging', count(*),
    count(views) * 1.0 / nullif(count(*), 0),
    count(distinct article), min(ts_yyyymmddhh), max(ts_yyyymmddhh), count(distinct ts_yyyymmddhh)
  from {{ ref('stg_wikimedia') }}
  union all
  select 'stg_github', 'staging', count(*),
    count(author_name) * 1.0 / nullif(count(*), 0),
    count(distinct commit_sha), min(author_date), max(author_date), count(distinct author_date)
  from {{ ref('stg_github') }}
  union all
  select 'stg_openaq', 'staging', count(*),
    count(value) * 1.0 / nullif(count(*), 0),
    count(distinct sensor_id), min(date_utc), max(date_utc), count(distinct date_utc)
  from {{ ref('stg_openaq') }}
  union all
  select 'stg_usgs', 'staging', count(*),
    count(magnitude) * 1.0 / nullif(count(*), 0),
    count(distinct feature_id), min(epoch_ms), max(epoch_ms), count(distinct epoch_ms)
  from {{ ref('stg_usgs') }}
),

hub_metrics as (
  select 'hub_country' as model, 'hubs' as layer, count(*) as row_count,
    1.0 as fill_rate, count(distinct country_bkey) as distinct_keys,
    null as earliest, null as latest, null as span
  from {{ ref('hub_country') }}
  union all
  select 'hub_indicator', 'hubs', count(*), 1.0, count(distinct indicator_bkey), null, null, null from {{ ref('hub_indicator') }}
  union all
  select 'hub_article', 'hubs', count(*), 1.0, count(distinct article_bkey), null, null, null from {{ ref('hub_article') }}
  union all
  select 'hub_location', 'hubs', count(*), 1.0, count(distinct location_bkey), null, null, null from {{ ref('hub_location') }}
  union all
  select 'hub_commit', 'hubs', count(*), 1.0, count(distinct commit_bkey), null, null, null from {{ ref('hub_commit') }}
  union all
  select 'hub_sensor', 'hubs', count(*), 1.0, count(distinct sensor_bkey), null, null, null from {{ ref('hub_sensor') }}
),

sat_metrics as (
  select 'sat_country_indicator_values' as model, 'satellites' as layer, count(*) as row_count,
    count(value) * 1.0 / nullif(count(*), 0) as fill_rate,
    null as distinct_keys,
    min(year) as earliest, max(year) as latest, count(distinct year) as span
  from {{ ref('sat_country_indicator_values') }}
  union all
  select 'sat_article_views', 'satellites', count(*),
    count(views) * 1.0 / nullif(count(*), 0), null, min(ts_yyyymmddhh), max(ts_yyyymmddhh), count(distinct ts_yyyymmddhh)
  from {{ ref('sat_article_views') }}
  union all
  select 'sat_weather_hourly', 'satellites', count(*),
    count(temperature_2m) * 1.0 / nullif(count(*), 0), null, min(ts), max(ts), count(distinct ts)
  from {{ ref('sat_weather_hourly') }}
  union all
  select 'sat_commit_meta', 'satellites', count(*),
    count(author_name) * 1.0 / nullif(count(*), 0), null, min(author_date), max(author_date), count(distinct author_date)
  from {{ ref('sat_commit_meta') }}
  union all
  select 'sat_sensor_measurements', 'satellites', count(*),
    count(value) * 1.0 / nullif(count(*), 0), null, min(date_utc), max(date_utc), count(distinct date_utc)
  from {{ ref('sat_sensor_measurements') }}
),

all_metrics as (
  select * from stg_metrics
  union all select * from hub_metrics
  union all select * from sat_metrics
)

select
  model, layer, row_count,
  round(fill_rate, 4) as fill_rate,
  distinct_keys,
  earliest, latest, span,
  current_timestamp as snapshot_ts
from all_metrics
order by layer, model
