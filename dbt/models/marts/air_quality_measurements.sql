{{ config(materialized="view") }}
select
  sn.sensor_bkey as sensor_id,
  s.parameter,
  s.unit,
  s.date_utc,
  s.value,
  s.lat,
  s.lon
from {{ ref('hub_sensor') }} sn
join {{ ref('sat_sensor_measurements') }} s on s.hk_sensor = sn.hk_sensor
