{{ config(materialized="view") }}
select
  feature_id,
  title,
  magnitude,
  epoch_ms,
  place,
  lon,
  lat,
  depth_km
from {{ ref('stg_usgs') }}
where magnitude is not null
