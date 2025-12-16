{{ config(materialized="view") }}

-- Dumps: s3://.../openaq/sensors/<id>/<resource>/<range>/<ts>.json.gz
with raw as (
  select * from read_json_auto('s3://cloud-dw-datavault-raw-vault/openaq/sensors/*/*/*/*.json.gz')
),
flat as (
  -- Flatten depending on resource; here we assume 'results' list
  select unnest(raw->'$.results') as r from raw
),
sel as (
  select
    r->>'$.locationId'      as location_id,
    r->>'$.sensorId'        as sensor_id,
    r->>'$.parameter'       as parameter,
    r->>'$.unit'            as unit,
    r->>'$.date.utc'        as date_utc,
    try_cast(r->>'$.value' as double) as value,
    r->>'$.coordinates.latitude'  as lat,
    r->>'$.coordinates.longitude' as lon
  from flat
)
select
  try_cast(sensor_id as bigint) as sensor_id,
  parameter, unit, date_utc,
  value,
  try_cast(lat as double) as lat,
  try_cast(lon as double) as lon
from sel
