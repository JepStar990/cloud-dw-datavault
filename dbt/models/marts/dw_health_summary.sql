{{ config(materialized="table") }}

with staging_counts as (
  select 'stg_worldbank' as model, 'staging' as layer, count(*) as row_count, max(year) as latest_record, 'year' as grain from {{ ref('stg_worldbank') }}
  union all
  select 'stg_openmeteo', 'staging', count(*), max(ts), 'hour' from {{ ref('stg_openmeteo') }}
  union all
  select 'stg_wikimedia', 'staging', count(*), max(ts_yyyymmddhh), 'hour' from {{ ref('stg_wikimedia') }}
  union all
  select 'stg_github', 'staging', count(*), max(author_date), 'commit' from {{ ref('stg_github') }}
  union all
  select 'stg_openaq', 'staging', count(*), max(date_utc), 'reading' from {{ ref('stg_openaq') }}
  union all
  select 'stg_usgs', 'staging', count(*), max(epoch_ms), 'event' from {{ ref('stg_usgs') }}
),

hub_counts as (
  select 'hub_country' as model, 'business_vault' as layer, count(*) as row_count, null as latest_record, 'hub' as grain from {{ ref('hub_country') }}
  union all
  select 'hub_indicator', 'business_vault', count(*), null, 'hub' from {{ ref('hub_indicator') }}
  union all
  select 'hub_article', 'business_vault', count(*), null, 'hub' from {{ ref('hub_article') }}
  union all
  select 'hub_location', 'business_vault', count(*), null, 'hub' from {{ ref('hub_location') }}
  union all
  select 'hub_commit', 'business_vault', count(*), null, 'hub' from {{ ref('hub_commit') }}
  union all
  select 'hub_sensor', 'business_vault', count(*), null, 'hub' from {{ ref('hub_sensor') }}
),

link_counts as (
  select 'link_country_indicator', 'business_vault', count(*), null, 'link' from {{ ref('link_country_indicator') }}
  union all
  select 'link_project_article', 'business_vault', count(*), null, 'link' from {{ ref('link_project_article') }}
),

sat_counts as (
  select 'sat_country_indicator_values', 'business_vault', count(*), max(year), 'satellite' from {{ ref('sat_country_indicator_values') }}
  union all
  select 'sat_article_views', 'business_vault', count(*), max(ts_yyyymmddhh), 'satellite' from {{ ref('sat_article_views') }}
  union all
  select 'sat_weather_hourly', 'business_vault', count(*), max(ts), 'satellite' from {{ ref('sat_weather_hourly') }}
  union all
  select 'sat_commit_meta', 'business_vault', count(*), max(author_date), 'satellite' from {{ ref('sat_commit_meta') }}
  union all
  select 'sat_sensor_measurements', 'business_vault', count(*), max(date_utc), 'satellite' from {{ ref('sat_sensor_measurements') }}
),

pit_counts as (
  select 'pit_country_indicator_year', 'business_vault', count(*), null, 'pit' from {{ ref('pit_country_indicator_year') }}
  union all
  select 'pit_article_day', 'business_vault', count(*), null, 'pit' from {{ ref('pit_article_day') }}
  union all
  select 'pit_weather_daily', 'business_vault', count(*), null, 'pit' from {{ ref('pit_weather_daily') }}
  union all
  select 'pit_openaq_hourly', 'business_vault', count(*), null, 'pit' from {{ ref('pit_openaq_hourly') }}
  union all
  select 'pit_usgs_daily', 'business_vault', count(*), null, 'pit' from {{ ref('pit_usgs_daily') }}
  union all
  select 'pit_github_daily', 'business_vault', count(*), null, 'pit' from {{ ref('pit_github_daily') }}
),

mart_counts as (
  select 'population_by_country_year', 'marts', count(*), null, 'mart' from {{ ref('population_by_country_year') }}
  union all
  select 'article_traffic_daily', 'marts', count(*), null, 'mart' from {{ ref('article_traffic_daily') }}
  union all
  select 'weather_hourly', 'marts', count(*), null, 'mart' from {{ ref('weather_hourly') }}
  union all
  select 'air_quality_measurements', 'marts', count(*), null, 'mart' from {{ ref('air_quality_measurements') }}
  union all
  select 'earthquake_recent', 'marts', count(*), null, 'mart' from {{ ref('earthquake_recent') }}
  union all
  select 'commit_history', 'marts', count(*), null, 'mart' from {{ ref('commit_history') }}
),

all_counts as (
  select * from staging_counts
  union all select * from hub_counts
  union all select * from link_counts
  union all select * from sat_counts
  union all select * from pit_counts
  union all select * from mart_counts
)

select
  model,
  layer,
  grain,
  row_count,
  latest_record,
  current_timestamp as snapshot_ts
from all_counts
order by layer, model
