
{{ config(materialized="incremental") }}

with base as (
  select
    country_iso3                   as country_bkey,
    indicator_id                   as indicator_bkey,
    try_cast(year as int)          as year,
    try_cast(value as double)      as value,
    unit, obs_status, decimal_places
  from {{ ref('stg_worldbank') }}
  where country_iso3 is not null and indicator_id is not null and year is not null
),
keys as (
  select
    lower(hex(sha256(upper(trim(country_bkey)))))   as hk_country,
    lower(hex(sha256(upper(trim(indicator_bkey))))) as hk_indicator,
    lower(hex(sha256(upper(trim(
      upper(trim(country_bkey)) || '|' || upper(trim(indicator_bkey)) || '|' || cast(year as varchar)
    ))))) as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_country,
    hk_indicator,
    hash_natural_key,
    lower(hex(sha256(upper(trim(
      coalesce(cast(value as varchar),'NULL')        || '|' ||
      coalesce(unit,'NULL')                          || '|' ||
      coalesce(obs_status,'NULL')                    || '|' ||
      coalesce(cast(decimal_places as varchar),'NULL')
    ))))) as hd_attributes,
    value, unit, obs_status, decimal_places,
    year,
    current_timestamp as load_dt
  from keys
)

select * from diffs
{% if is_incremental() %}
  where not exists (
    select 1
    from {{ this }} t
    where t.hash_natural_key = diffs.hash_natural_key
      and t.hd_attributes   = diffs.hd_attributes
  )
{% endif %}
