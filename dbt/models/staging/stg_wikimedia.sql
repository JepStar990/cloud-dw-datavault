{{ config(materialized="view") }}

-- Wikimedia pageview dump contains {"items": [...]}
-- read_json_auto returns 'items' as a LIST of STRUCTs
with raw as (
  select *
  from read_json_auto('{{ get_source_meta("raw_vault","wikimedia_mandela","s3_glob") }}')
),
items as (
  select unnest(items) as j from raw
)
select
  j.project     as project,
  j.article     as article,
  j.granularity as granularity,
  j.access      as access,
  j.agent       as agent,
  j.timestamp   as ts_yyyymmddhh,
  j.views       as views
from items
