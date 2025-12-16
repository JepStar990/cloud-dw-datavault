{{ config(materialized="view") }}

-- Expect dumps under: s3://.../openmeteo/<lat>_<lon>/<timestamp>.json.gz
with raw as (
  select * from read_json_auto('s3://cloud-dw-datavault-raw-vault/openmeteo/*/*')
),
hourly as (
  select
    raw->>'$.latitude'  as lat,
    raw->>'$.longitude' as lon,
    unnest(raw->'$.hourly.time')                  as ts,
    unnest(raw->'$.hourly.temperature_2m')        as temperature_2m,
    unnest(raw->'$.hourly.relativehumidity_2m')   as relativehumidity_2m
  from raw
  where json_valid(raw)
)
select
  try_cast(lat as double) as lat,
  try_cast(lon as double) as lon,
  ts,
  try_cast(temperature_2m as double) as temperature_2m,
  try_cast(relativehumidity_2m as double) as relativehumidity_2m
from hourly
