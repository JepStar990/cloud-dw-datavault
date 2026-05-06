{{ config(materialized="table") }}
with base as (
  select
    hk_location,
    substr(ts, 1, 10) as yyyymmdd,
    temperature_2m,
    relativehumidity_2m
  from {{ ref('sat_weather_hourly') }}
),
agg as (
  select
    hk_location,
    yyyymmdd,
    avg(temperature_2m) as avg_temp,
    avg(relativehumidity_2m) as avg_humidity
  from base
  group by 1, 2
)
select * from agg
