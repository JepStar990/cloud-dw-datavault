{{ config(materialized="view") }}

-- World Bank API returns: [{page_metadata}, [{observations}, ...]]
-- read_json_auto returns 2 rows with a 'json' column (type JSON)
with raw as (
  select *
  from read_json_auto('s3://cloud-dw-datavault-raw-vault/worldbank/SP.POP.TOTL/ZA/*.json.gz')
  where json_type(json) = 'ARRAY'
),
expanded as (
  select
    r.json as j,
    unnest(generate_series(0, cast(json_array_length(r.json) as bigint) - 1)) as i
  from raw r
),
flat as (
  select
    json_extract_string(j, '$[' || i || '].indicator.id')             as indicator_id,
    json_extract_string(j, '$[' || i || '].indicator.value')          as indicator_name,
    json_extract_string(j, '$[' || i || '].country.id')               as country_id,
    json_extract_string(j, '$[' || i || '].country.value')            as country_name,
    json_extract_string(j, '$[' || i || '].countryiso3code')          as country_iso3,
    json_extract_string(j, '$[' || i || '].date')                     as year,
    json_extract_string(j, '$[' || i || '].unit')                     as unit,
    json_extract_string(j, '$[' || i || '].obs_status')               as obs_status,
    json_extract_string(j, '$[' || i || '].decimal')                  as decimal_places,
    try_cast(json_extract_string(j, '$[' || i || '].value') as double) as value
  from expanded
)
select * from flat
