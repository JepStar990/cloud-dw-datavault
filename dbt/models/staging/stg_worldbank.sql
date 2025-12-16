{{ config(materialized="view") }}

-- Read all dumps; DuckDB auto-infers schema and expands arrays/objects.
-- Docs: DuckDB read_json / auto inference; JSON functions.  [5](https://duckdb.org/docs/stable/data/json/loading_json)[6](https://duckdb.org/docs/stable/data/json/json_functions)

with raw as (
  select
    *
  from read_json_auto('{{ source("raw_vault","worldbank_pop_za").meta["s3_glob"] }}')
),

-- World Bank v2 responses are arrays: [metadata, data]
-- We select the last element (observations) if present.
obs as (
  select
    -- Extract observations array as table if payload is [header, items]
    unnest(json_extract(raw, '$[1]')) as j
  from raw
  where json_valid(raw)
),

flat as (
  select
    j->>'$.indicator.id'       as indicator_id,
    j->>'$.indicator.value'    as indicator_name,
    j->>'$.country.id'         as country_id,
    j->>'$.country.value'      as country_name,
    j->>'$.countryiso3code'    as country_iso3,
    j->>'$.date'               as year,
    j->>'$.unit'               as unit,
    j->>'$.obs_status'         as obs_status,
    j->>'$.decimal'            as decimal_places,
    try_cast(j->>'$.value' as double) as value
  from obs
)

select * from flat
