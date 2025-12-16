{{ config(materialized="table") }}

with keys as (
  select distinct
    country_iso3 as country_bkey
  from {{ ref('stg_worldbank') }}
  where country_iso3 is not null
)
select
  {{ hash_key("country_bkey") }} as hk_country,
  country_bkey                  as country_bkey,
  current_timestamp             as load_dt
from keys
