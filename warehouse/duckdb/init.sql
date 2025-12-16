-- Initialize DuckDB with httpfs for S3 access and use AWS credential chain.
-- Docs: DuckDB httpfs + S3 API support & secrets
-- https://duckdb.org/docs/stable/core_extensions/httpfs/s3api
-- https://duckdb.org/docs/stable/guides/network_cloud_storage/s3_import

INSTALL httpfs;
LOAD httpfs;

-- Use AWS credential chain (instance role, env, config) for S3
CREATE OR REPLACE SECRET s3_default (TYPE s3, PROVIDER credential_chain);

-- You can now read raw JSON/GeoJSON directly from S3 using DuckDB functions
-- Example (for ad-hoc exploration):
-- SELECT COUNT(*) FROM read_parquet('s3://cloud-dw-datavault-raw-vault/path/to/file.parquet');
