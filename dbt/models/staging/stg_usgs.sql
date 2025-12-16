{{ config(materialized="view") }}

-- USGS GeoJSON FeatureCollection: features[] with properties + geometry.  [12](https://doc.wikimedia.org/generated-data-platform/aqs/analytics-api/concepts/page-views.html)

with raw as (
  select * from read_json_auto('{{ get_source_meta("raw_vault","usgs_all_day","s3_glob") }}')
),
features as (
  select unnest(raw->'$.features') as f from raw
)
select
  f->>'$.id'                                     as feature_id,
  f->'$.properties'->>'$.title'                  as title,
  try_cast(f->'$.properties'->>'$.mag' as double) as magnitude,
  try_cast(f->'$.properties'->>'$.time' as ubigint) as epoch_ms,
  f->'$.properties'->>'$.place'                  as place,
  try_cast(f->'$.geometry'->'$.coordinates'->>0 as double) as lon,
  try_cast(f->'$.geometry'->'$.coordinates'->>1 as double) as lat,
  try_cast(f->'$.geometry'->'$.coordinates'->>2 as double) as depth_km
from features
