{{ config(materialized="table") }}
with keys as (
  select distinct
    upper(trim(cast(lat as varchar))) || '|' || upper(trim(cast(lon as varchar))) as location_bkey
  from {{ ref('stg_openmeteo') }}
  where lat is not null and lon is not null
)
select
  {{ hash_key("location_bkey") }} as hk_location,
  location_bkey,
  current_timestamp as load_dt
from keys
