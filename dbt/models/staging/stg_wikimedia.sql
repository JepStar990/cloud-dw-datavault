{{ config(materialized="view") }}

-- Each dump contains {"items":[...]} where items have timestamp/views.  [10](https://cran.csail.mit.edu/web/packages/pageviews/pageviews.pdf)

with raw as (
  select * from read_json_auto('{{ get_source_meta("raw_vault","wikimedia_mandela","s3_glob") }}')
),
items as (
  select unnest(raw->'$.items') as j from raw
)
select
  j->>'$.project'     as project,
  j->>'$.article'     as article,
  j->>'$.granularity' as granularity,
  j->>'$.access'      as access,
  j->>'$.agent'       as agent,
  j->>'$.timestamp'   as ts_yyyymmddhh,
  try_cast(j->>'$.views' as bigint) as views
from items
