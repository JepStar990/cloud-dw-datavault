# Raw Vault bucket (versioned + Block Public Access)

resource "aws_s3_bucket" "raw_vault" {
  bucket = "${var.project_name}-raw-vault"
  force_destroy = false

  tags = {
    Name = "RawDataVault"
  }
}

# Versioning for immutable raw data
resource "aws_s3_bucket_versioning" "raw_vault" {
  bucket = aws_s3_bucket.raw_vault.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access (defense-in-depth)
resource "aws_s3_bucket_public_access_block" "raw_vault" {
  bucket                  = aws_s3_bucket.raw_vault.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
