{{ config(materialized="view") }}

-- USGS GeoJSON FeatureCollection: features is a LIST of STRUCTs
-- read_json_auto returns features as a LIST type, not JSON
with raw as (
  select *
  from read_json_auto('{{ get_source_meta("raw_vault","usgs_all_day","s3_glob") }}')
),
features as (
  select unnest(features) as f from raw
)
select
  f.id                                     as feature_id,
  f.properties.title                       as title,
  f.properties.mag                         as magnitude,
  f.properties.time                        as epoch_ms,
  f.properties.place                       as place,
  f.geometry.coordinates[1]                as lon,
  f.geometry.coordinates[2]                as lat,
  f.geometry.coordinates[3]                as depth_km
from features
