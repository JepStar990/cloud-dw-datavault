{{ config(materialized="view") }}
select
  c.commit_bkey as commit_sha,
  s.author_name,
  s.author_date,
  s.committer_name,
  s.message,
  s.verified
from {{ ref('hub_commit') }} c
join {{ ref('sat_commit_meta') }} s on s.hk_commit = c.hk_commit
