-- Every staging model must have at least 1 row; empty sources indicate broken ingestion
select 'stg_worldbank' as model, count(*) as rows from {{ ref('stg_worldbank') }} having count(*) = 0
union all
select 'stg_openmeteo', count(*) from {{ ref('stg_openmeteo') }} having count(*) = 0
union all
select 'stg_wikimedia', count(*) from {{ ref('stg_wikimedia') }} having count(*) = 0
union all
select 'stg_github', count(*) from {{ ref('stg_github') }} having count(*) = 0
union all
select 'stg_openaq', count(*) from {{ ref('stg_openaq') }} having count(*) = 0
union all
select 'stg_usgs', count(*) from {{ ref('stg_usgs') }} having count(*) = 0
