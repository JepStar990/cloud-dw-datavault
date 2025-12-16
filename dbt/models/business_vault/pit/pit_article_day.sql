{{ config(materialized="table") }}

-- Keys: hk_article, project_id + day (YYYYMMDD)
with base as (
  select
    hk_article,
    project_id,
    substr(ts_yyyymmddhh, 1, 8) as yyyymmdd,
    views
  from {{ ref('sat_article_views') }}
),
agg as (
  select
    hk_article,
    project_id,
    y    yyyymmdd,
    sum(views) as views_day
  from base
  group by 1,2,3
)
select * from agg
