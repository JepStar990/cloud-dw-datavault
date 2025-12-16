{{ config(materialized="table") }}
select
  {{ hash_key("cast(sensor_id as varchar)") }} as hk_sensor,
  cast(sensor_id as varchar) as sensor_bkey,
  current_timestamp as load_dt
from {{ ref('stg_openaq') }}
where sensor_id is not null
group by 1,2,3
