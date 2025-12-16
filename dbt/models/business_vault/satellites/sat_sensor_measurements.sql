{{ config(materialized="incremental", unique_key="hash_natural_key") }}
with base as (
  select sensor_id, parameter, unit, date_utc, value, lat, lon
  from {{ ref('stg_openaq') }}
  where sensor_id is not null and date_utc is not null
),
keys as (
  select
    {{ hash_key("cast(sensor_id as varchar)") }} as hk_sensor,
    {{ hash_key("upper(trim(cast(sensor_id as varchar))) || '|' || upper(trim(parameter)) || '|' || upper(trim(date_utc))") }} as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_sensor, hash_natural_key,
    {{ hash_diff([
      "coalesce(cast(value as varchar),'NULL')",
      "coalesce(unit,'NULL')",
      "coalesce(cast(lat as varchar),'NULL')",
      "coalesce(cast(lon as varchar),'NULL')"
    ]) }} as hd_attributes,
    parameter, unit, date_utc, value, lat, lon,
    current_timestamp as load_dt
  from keys
)
select * from diffs
{% if is_incremental() %}
where (hash_natural_key, hd_attributes) not in (select hash_natural_key, hd_attributes from {{ this }})
{% endif %}
