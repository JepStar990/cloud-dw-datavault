{{ config(materialized="view") }}

-- OpenAQ v3 sensor measurements: {"meta": {...}, "results": [...]}
-- read_json_auto returns 'results' as a LIST of STRUCTs
with raw as (
  select *
  from read_json_auto('s3://cloud-dw-datavault-raw-vault/openaq/sensors/*/*/*/*.json.gz')
),
flat as (
  select unnest(results) as r from raw
)
select
  r.parameter.id          as sensor_id,
  r.parameter.name        as parameter,
  r.parameter.units       as unit,
  r.period.datetimeFrom.utc as date_utc,
  r.value                 as value,
  r.coordinates.latitude  as lat,
  r.coordinates.longitude as lon
from flat
