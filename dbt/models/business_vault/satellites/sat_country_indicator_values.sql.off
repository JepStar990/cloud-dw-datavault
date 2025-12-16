{{ config(materialized="incremental", unique_key="hash_natural_key") }}

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
    {{ hash_key("country_bkey") }}  as hk_country,
    {{ hash_key("indicator_bkey") }} as hk_indicator,
    {{ hash_key("upper(trim(country_bkey)) || '|' || upper(trim(indicator_bkey)) || '|' || cast(year as varchar)") }} as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_country,
    hk_indicator,
    hash_natural_key,
    {{ hash_diff(["coalesce(cast(value as varchar),'NULL')",
                  "coalesce(unit,'NULL')",
                  "coalesce(obs_status,'NULL')",
                  "coalesce(cast(decimal_places as varchar),'NULL')"]) }} as hd_attributes,
    value, unit, obs_status, decimal_places,
    year,
    current_timestamp as load_dt
  from keys
)

select * from diffs
{% if is_incremental() %}
  -- For incremental loads, insert only when hd_attributes changed for hash_natural_key
  where (hash_natural_key, hd_attributes) not in (
    select hash_natural_key, hd_attributes from {{ this }}
  )
{% endif %}
