{% macro hash_key(expr) -%}
-- Data Vault 2.0: deterministic hash over standardized business key
-- K_hash = SHA256(UPPER(TRIM(business_key)))  (preferred over MD5)
-- Ref: DV2.0 implementation guidance and hashing rules.  {{ return(adapter.dispatch('hash_key', 'cloud_dw_datavault')(expr)) }}
{%- endmacro %}

{% macro default__hash_key(expr) -%}
sha256(upper(trim({{ expr }})))
{%- endmacro %}
