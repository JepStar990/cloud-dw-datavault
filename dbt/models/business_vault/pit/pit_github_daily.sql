{{ config(materialized="table") }}
select
  hk_commit,
  author_name,
  author_date,
  committer_name,
  message,
  verified
from {{ ref('sat_commit_meta') }}
