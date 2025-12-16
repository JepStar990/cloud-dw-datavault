{{ config(materialized="table") }}

select
  hk_country,
  hk_indicator,
  try_cast(year as int) as year,
  max(value) as value_year -- insert-only; pick latest version if multiple
from {{ ref('sat_country_indicator_values') }}
group by 1,2,3
