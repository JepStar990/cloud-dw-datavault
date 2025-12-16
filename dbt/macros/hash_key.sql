{% macro hash_key(expr) -%}
sha256(upper(trim({{ expr }})))
{%- endmacro %}
