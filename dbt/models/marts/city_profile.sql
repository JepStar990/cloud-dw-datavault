{{
  config(
    materialized="table",
    description="Cross-source unified city profile — Johannesburg. Joins population, weather, air quality, seismic activity, public interest, and developer activity through Data Vault hub keys."
  )
}}

-- 1. South Africa population (World Bank, latest year)
with pop_latest as (
  select
    cast(year as int) as year,
    round(avg(value), 0) as population
  from {{ ref('sat_country_indicator_values') }}
  where year is not null and value is not null
  group by year
  order by year desc
  limit 1
),

-- 2. Johannesburg weather (Open-Meteo, daily aggregates)
weather_stats as (
  select
    count(*) as weather_days,
    round(avg(avg_temp), 1) as avg_temp_c,
    round(avg(avg_humidity), 1) as avg_humidity_pct
  from {{ ref('pit_weather_daily') }}
),

-- 3. Air quality (OpenAQ, ozone)
air_stats as (
  select
    count(*) as aq_readings,
    round(avg(value), 4) as avg_o3_ppm
  from {{ ref('pit_openaq_hourly') }}
),

-- 4. Public interest — Wikipedia (Nelson Mandela)
wiki_stats as (
  select
    count(*) as wiki_records,
    round(avg(views), 0) as avg_daily_views
  from {{ ref('sat_article_views') }}
),

-- 5. Seismic activity near Southern Africa
seismic_stats as (
  select
    count(*) as nearby_quakes,
    round(max(magnitude), 1) as max_mag
  from {{ ref('earthquake_recent') }}
  where lat between -35 and -15
    and lon between 15 and 35
),

-- 6. GitHub commits
commit_stats as (
  select
    count(*) as total_commits,
    count(distinct author_name) as unique_authors
  from {{ ref('sat_commit_meta') }}
)

-- Combine into single unified row
select
  'Johannesburg' as city,
  'ZA' as country_iso3,
  'South Africa' as country_name,

  -- Population
  pl.population as latest_population,
  pl.year as population_year,

  -- Weather
  ws.weather_days,
  ws.avg_temp_c,
  ws.avg_humidity_pct,

  -- Air quality
  aq.aq_readings,
  aq.avg_o3_ppm,

  -- Public interest
  wk.wiki_records,
  wk.avg_daily_views as avg_daily_mandela_views,

  -- Seismic
  sq.nearby_quakes as nearby_earthquake_count,
  sq.max_mag as max_nearby_magnitude,

  -- Commits
  cs.total_commits,
  cs.unique_authors as unique_committers,

  -- Source coverage score (0-6)
  (case when pl.population > 0 then 1 else 0 end +
   case when ws.weather_days > 0 then 1 else 0 end +
   case when aq.aq_readings > 0 then 1 else 0 end +
   case when wk.wiki_records > 0 then 1 else 0 end +
   case when sq.nearby_quakes > 0 then 1 else 0 end +
   case when cs.total_commits > 0 then 1 else 0 end
  ) as sources_active_out_of_6,

  current_timestamp as generated_at

from pop_latest pl
cross join weather_stats ws
cross join air_stats aq
cross join wiki_stats wk
cross join seismic_stats sq
cross join commit_stats cs
