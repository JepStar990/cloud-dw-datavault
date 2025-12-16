{% macro hash_diff(cols) -%}
-- Hash Diff for satellites: concat standardized attribute set, then SHA-256
-- Usage: {{ hash_diff(["coalesce(cast(val as varchar),'NULL')", "coalesce(unit,'NULL')"]) }}
sha256(
  upper(
    trim(
      {{ cols | join(" || '|' || ") }}
    )
  )
)
{%- endmacro %}~
