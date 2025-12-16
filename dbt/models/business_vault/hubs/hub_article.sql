{{ config(materialized="table") }}

with keys as (
  select distinct article as article_bkey
  from {{ ref('stg_wikimedia') }}
  where article is not null
)
select
  {{ hash_key("article_bkey") }} as hk_article,
  article_bkey                   as article_bkey,
  current_timestamp              as load_dt
from keys
