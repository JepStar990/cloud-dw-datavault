{{ config(materialized="view") }}
select
  l.location_bkey,
  s.ts,
  s.temperature_2m,
  s.relativehumidity_2m
from {{ ref('hub_location') }} l
join {{ ref('sat_weather_hourly') }} s on s.hk_location = l.hk_location
