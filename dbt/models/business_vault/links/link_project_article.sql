{{ config(materialized="table") }}

with pairs as (
  select distinct
    project as project_id,
    article as article_bkey
  from {{ ref('stg_wikimedia') }}
  where project is not null and article is not null
)
select
  {{ hash_key("upper(trim(project_id)) || '|' || upper(trim(article_bkey))") }} as hk_project_article,
  upper(trim(project_id)) as project_id,
  {{ hash_key("article_bkey") }}         as hk_article,
  current_timestamp                      as load_dt
from pairs
