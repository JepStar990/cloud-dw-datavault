{% macro hash_diff(cols) -%}
-- Hash diff for satellites: concatenate standardized attribute set
-- UPPER(TRIM)) for strings; coalesce to stable tokens; then SHA256.
-- Example usage: {{ hash_diff(["col1","col2","col3"]) }}
sha256(
    upper(
      trim(
        {{ cols | map('string') | join(" || '|' || ") }}
      )
    )
)
{%- endmacro %}
