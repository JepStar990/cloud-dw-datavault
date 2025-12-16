{{ config(materialized="table") }}

with keys as (
  select distinct indicator_id as indicator_bkey
  from {{ ref('stg_worldbank') }}
  where indicator_id is not null
)
select
  {{ hash_key("indicator_bkey") }} as hk_indicator,
  indicator_bkey                   as indicator_bkey,
  current_timestamp                as load_dt
from keys
