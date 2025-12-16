{{ config(materialized="incremental", unique_key="hash_natural_key") }}
with base as (
  select commit_sha, author_name, author_date, committer_name, message, verified
  from {{ ref('stg_github') }}
  where commit_sha is not null
),
keys as (
  select
    {{ hash_key("commit_sha") }} as hk_commit,
    {{ hash_key("upper(trim(commit_sha))") }} as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_commit, hash_natural_key,
    {{ hash_diff([
      "coalesce(author_name,'NULL')",
      "coalesce(author_date,'NULL')",
      "coalesce(committer_name,'NULL')",
      "coalesce(message,'NULL')",
      "coalesce(cast(verified as varchar),'NULL')"
    ]) }} as hd_attributes,
    author_name, author_date, committer_name, message, verified,
    current_timestamp as load_dt
  from keys
)
select * from diffs
{% if is_incremental() %}
where (hash_natural_key, hd_attributes) not in (select hash_natural_key, hd_attributes from {{ this }})
{% endif %}
