{% test valid_hash_key(model, column_name) %}
  -- All hash keys must be 64-character lowercase hex strings (SHA-256 output)
  select {{ column_name }}
  from {{ model }}
  where {{ column_name }} is not null
    and not regexp_matches({{ column_name }}, '^[0-9a-f]{64}$')
{% endtest %}
