{{ config(materialized="incremental") }}

with base as (
  select
    project,
    article,
    ts_yyyymmddhh,
    views,
    access,
    agent,
    granularity
  from {{ ref('stg_wikimedia') }}
  where project is not null and article is not null and ts_yyyymmddhh is not null
),
keys as (
  select
    lower(hex(sha256(upper(trim(article))))) as hk_article,
    upper(trim(project))                      as project_id,
    lower(hex(sha256(upper(trim(
      upper(trim(project)) || '|' || upper(trim(article))
    ))))) as hk_project_article,
    lower(hex(sha256(upper(trim(
      upper(trim(project)) || '|' || upper(trim(article)) || '|' || upper(trim(cast(ts_yyyymmddhh as varchar)))
    ))))) as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_article,
    hk_project_article,
    project_id,
    hash_natural_key,
    lower(hex(sha256(upper(trim(
      coalesce(cast(views as varchar),'NULL') || '|' ||
      coalesce(access,'NULL')                  || '|' ||
      coalesce(agent,'NULL')                   || '|' ||
      coalesce(granularity,'NULL')
    ))))) as hd_attributes,
    views, access, agent, granularity,
    ts_yyyymmddhh,
    current_timestamp as load_dt
  from keys
)

select * from diffs
{% if is_incremental() %}
  where not exists (
    select 1
    from {{ this }} t
    where t.hash_natural_key = diffs.hash_natural_key
      and t.hd_attributes   = diffs.hd_attributes
  )
{% endif %}
