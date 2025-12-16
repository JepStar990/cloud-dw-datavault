{{ config(materialized="view") }}
select
  c.country_bkey as iso3,
  i.indicator_bkey as indicator,
  y.year,
  y.value_year
from {{ ref('hub_country') }} c
join {{ ref('hub_indicator') }} i on 1=1 -- filter in WHERE
join {{ ref('pit_country_indicator_year') }} y
  on y.hk_country = c.hk_country and y.hk_indicator = i.hk_indicator
where upper(trim(i.indicator_bkey)) = 'SP.POP.TOTL'
