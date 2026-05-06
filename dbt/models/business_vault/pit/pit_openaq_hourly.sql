{{ config(materialized="table") }}
select
  hk_sensor,
  parameter,
  date_utc,
  value,
  lat,
  lon
from {{ ref('sat_sensor_measurements') }}
