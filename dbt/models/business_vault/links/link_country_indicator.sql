{{ config(materialized="table") }}

with pairs as (
  select distinct
    country_iso3 as country_bkey,
    indicator_id as indicator_bkey
  from {{ ref('stg_worldbank') }}
  where country_iso3 is not null and indicator_id is not null
)
select
  {{ hash_key("upper(trim(country_bkey)) || '|' || upper(trim(indicator_bkey))") }} as hk_country_indicator,
  {{ hash_key("country_bkey") }}   as hk_country,
  {{ hash_key("indicator_bkey") }} as hk_indicator,
  current_timestamp                as load_dt
from pairs
