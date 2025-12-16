-- macros/get_source_meta.sql
{% macro get_source_meta(source_name, table_name, key, default=None) %}
{%- if execute -%}
  {%- for s in graph.sources.values() -%}
    {%- if s.source_name == source_name and s.name == table_name -%}
      {%- if key in s.meta -%}
        {{ return(s.meta[key]) }}
      {%- else -%}
        {{ return(default) }}
      {%- endif -%}
    {%- endif -%}
  {%- endfor -%}
  {{ return(default) }}
{%- endif -%}
{% endmacro %}
