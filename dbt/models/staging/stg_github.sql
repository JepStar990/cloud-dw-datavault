{{ config(materialized="view") }}

-- Dumps under: s3://.../github/<owner>/<repo>/<ts>.json.gz
with raw as (
  select * from read_json_auto('s3://cloud-dw-datavault-raw-vault/github/*/*/*.json.gz')
),
flat as (
  select
    raw->>'$.sha'                        as commit_sha,
    raw->'$.commit'->>'$.author.name'    as author_name,
    raw->'$.commit'->>'$.author.date'    as author_date,
    raw->'$.commit'->>'$.committer.name' as committer_name,
    raw->'$.commit'->>'$.message'        as message,
    raw->'$.verification'->>'$.verified' as verified
  from raw
  where json_valid(raw)
)
select
  commit_sha,
  author_name, author_date, committer_name, message,
  case when lower(verified)='true' then true else false end as verified
from flat
