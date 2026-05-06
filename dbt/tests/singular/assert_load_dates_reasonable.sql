-- All satellites must have load_dt within the last 7 days or be from the initial load
select hash_natural_key, load_dt
from {{ ref('sat_weather_hourly') }}
where load_dt > current_timestamp + interval '1' day
   or load_dt < current_timestamp - interval '90' day
union all
select hash_natural_key, load_dt
from {{ ref('sat_sensor_measurements') }}
where load_dt > current_timestamp + interval '1' day
   or load_dt < current_timestamp - interval '90' day
union all
select hash_natural_key, load_dt
from {{ ref('sat_commit_meta') }}
where load_dt > current_timestamp + interval '1' day
   or load_dt < current_timestamp - interval '90' day
union all
select hash_natural_key, load_dt
from {{ ref('sat_country_indicator_values') }}
where load_dt > current_timestamp + interval '1' day
   or load_dt < current_timestamp - interval '90' day
union all
select hash_natural_key, load_dt
from {{ ref('sat_article_views') }}
where load_dt > current_timestamp + interval '1' day
   or load_dt < current_timestamp - interval '90' day
