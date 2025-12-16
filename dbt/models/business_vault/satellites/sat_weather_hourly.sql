{{ config(materialized="incremental", unique_key="hash_natural_key") }}
with base as (
  select
    upper(trim(cast(lat as varchar))) || '|' || upper(trim(cast(lon as varchar))) as location_bkey,
    ts,
    temperature_2m,
    relativehumidity_2m
  from {{ ref('stg_openmeteo') }}
  where lat is not null and lon is not null and ts is not null
),
keys as (
  select
    {{ hash_key("location_bkey") }} as hk_location,
    {{ hash_key("upper(trim(location_bkey)) || '|' || upper(trim(ts))") }} as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_location,
    hash_natural_key,
    {{ hash_diff([
      "coalesce(cast(temperature_2m as varchar),'NULL')",
      "coalesce(cast(relativehumidity_2m as varchar),'NULL')"
    ]) }} as hd_attributes,
    temperature_2m, relativehumidity_2m, ts,
    current_timestamp as load_dt
  from keys
)
select * from diffs
{% if is_incremental() %}
where (hash_natural_key, hd_attributes) not in (select hash_natural_key, hd_attributes from {{ this }})
{% endif %}
