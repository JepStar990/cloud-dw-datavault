{% macro hash_diff(cols) -%}
sha256(upper(trim(
  {%- for col in cols -%}
    {%- if not loop.first %} || '|' || {% endif -%}
    {{ col }}
  {%- endfor -%}
)))
{%- endmacro %}
