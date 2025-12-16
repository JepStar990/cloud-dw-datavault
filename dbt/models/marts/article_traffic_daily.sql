{{ config(materialized="view") }}
select
  a.article_bkey as article,
  p.project_id   as project,
  d.yyyymmdd,
  d.views_day
from {{ ref('hub_article') }} a
join {{ ref('link_project_article') }} l on l.hk_article = a.hk_article
join {{ ref('pit_article_day') }} d     on d.hk_article = a.hk_article and d.project_id = l.project_id
