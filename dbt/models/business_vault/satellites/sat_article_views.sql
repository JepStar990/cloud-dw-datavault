{{ config(materialized="incremental", unique_key="hash_natural_key") }}

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
    {{ hash_key("article") }} as hk_article,
    upper(trim(project))      as project_id,
    {{ hash_key("upper(trim(project)) || '|' || upper(trim(article))") }} as hk_project_article,
    {{ hash_key("upper(trim(project)) || '|' || upper(trim(article)) || '|' || upper(trim(ts_yyyymmddhh))") }} as hash_natural_key,
    *
  from base
),
diffs as (
  select
    hk_article,
    hk_project_article,
    project_id,
    hash_natural_key,
    {{ hash_diff(["coalesce(cast(views as varchar),'NULL')",
                  "coalesce(access,'NULL')",
                  "coalesce(agent,'NULL')",
                  "coalesce(granularity,'NULL')"]) }} as hd_attributes,
    views, access, agent, granularity,
    ts_yyyymmddhh,
    current_timestamp as load_dt
  from keys
)
select * from diffs
{% if is_incremental() %}
  where (hash_natural_key, hd_attributes) not in (
    select hash_natural_key, hd_attributes from {{ this }}
  )
{% endif %}
