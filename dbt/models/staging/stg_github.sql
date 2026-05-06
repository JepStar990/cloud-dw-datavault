{{ config(materialized="view") }}

-- GitHub commits API returns an array of commit objects
-- read_json_auto returns one row per commit with structured columns
with raw as (
  select *
  from read_json_auto('s3://cloud-dw-datavault-raw-vault/github/*/*/*.json.gz')
)
select
  sha                              as commit_sha,
  commit.author.name               as author_name,
  commit.author.date               as author_date,
  commit.committer.name            as committer_name,
  commit.message                   as message,
  commit.verification.verified     as verified
from raw
where sha is not null
