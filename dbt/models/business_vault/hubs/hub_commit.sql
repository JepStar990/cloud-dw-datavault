{{ config(materialized="table") }}
select
  {{ hash_key("commit_sha") }} as hk_commit,
  commit_sha as commit_bkey,
  current_timestamp as load_dt
from {{ ref('stg_github') }}
where commit_sha is not null
group by 1,2,3
