# Deployment Guide

## Prerequisites

- AWS account with admin access
- Terraform >= 1.5
- AWS CLI v2
- An EC2 key pair (`.pem` file) for SSH access
- Git

## Step 1: Provision Infrastructure

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve
```

This creates:
- S3 bucket (`cloud-dw-datavault-raw-vault`) with versioning and block public access
- IAM role and instance profile with least-privilege S3 + SSM access
- EC2 instance (t3.micro, Amazon Linux 2023) with user-data bootstrap

### Terraform Outputs

| Output | Description |
|--------|-------------|
| `raw_vault_bucket_name` | S3 bucket name |
| `ec2_public_dns` | EC2 public hostname |
| `ec2_public_ip` | EC2 public IP address |
| `resolved_al2023_ami` | AMI ID used (marked sensitive) |

### Customizing Variables

Edit `infra/terraform/variables.tf` or create a `terraform.tfvars`:

```hcl
aws_region       = "eu-west-1"
instance_type    = "t3.micro"
ssh_key_name     = "my-key"
ssh_ingress_cidr = "203.0.113.0/24"  # Restrict to your IP
```

## Step 2: Connect to EC2

```bash
# SSH
ssh -i ~/.ssh/<key>.pem ec2-user@$(terraform output -raw ec2_public_dns)

# Or use Session Manager (if configured)
aws ssm start-session --target <instance-id>
```

## Step 3: Clone and Configure

```bash
cd ~
git clone https://github.com/<org>/cloud-dw-datavault.git
cd cloud-dw-datavault

# Set up Python environment
echo 'export PYTHONPATH=$(pwd)' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install dependencies (should already be installed by user-data)
python3 -m pip install --user duckdb dbt-core dbt-duckdb dagster dagit
python3 -m pip install --user -r requirements.txt

# Configure environment variables
export HTTP_APP_NAME="cloud-dw-datavault"
export HTTP_CONTACT="mailto:you@yourcompany.com"
export OPENAQ_API_KEY="your-openaq-key"  # Optional
export GITHUB_TOKEN="ghp_..."           # Optional
```

## Step 4: Verify dbt Configuration

Create `~/.dbt/profiles.yml`:

```yaml
cloud_dw_duckdb:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: /opt/data/dw.duckdb
      threads: 4
      extensions:
        - httpfs
        - parquet
```

Ensure the data directory exists:

```bash
sudo mkdir -p /opt/data
sudo chown -R ec2-user:ec2-user /opt/data
dbt debug --project-dir dbt
```

## Step 5: Run Ingestion

```bash
# World Bank
python3 -m ingestion.extract_worldbank --indicator SP.POP.TOTL --country ZA

# Weather
python3 -m ingestion.extract_weather --lat -26.2041 --lon 28.0473 \
  --hourly temperature_2m,relativehumidity_2m

# Wikimedia
python3 -m ingestion.extract_wikimedia --project en.wikipedia.org \
  --article Nelson_Mandela --access all-access --agent all-agents \
  --granularity daily --start 20250101 --end 20250107

# GitHub
python3 -m ingestion.extract_github --owner octocat --repo Hello-World

# OpenAQ (requires key)
python3 -m ingestion.extract_openaq --sensor_id 3917 \
  --resource measurements --limit 500

# USGS
python3 -m ingestion.extract_usgs --feed all_day
```

Verify data in S3:

```bash
aws s3 ls s3://cloud-dw-datavault-raw-vault/ --recursive --human-readable --summarize
```

## Step 6: Build the Data Vault

```bash
cd dbt

# Parse and compile
dbt parse
dbt compile

# Build staging
dbt build --select "path:models/staging"

# Build business vault
dbt build --select "path:models/business_vault"

# Build marts
dbt build --select "path:models/marts"

# Run tests
dbt test
```

## Step 7: Start Services

### Metabase (Docker)

```bash
docker run -d --name metabase -p 3000:3000 \
  -v /opt/data:/metabase-data \
  -e MB_DB_FILE=/metabase-data/metabase.db \
  metabase/metabase:latest
```

Access at `http://<EC2 public DNS>:3000`

### Dagster (Orchestration)

```bash
dagster dev -f orchestration/dagster/dw_pipeline.py
```

Access at `http://<EC2 public DNS>:3000`

## Step 8: Verify End-to-End

```bash
# Check table counts
python3 << 'PYEOF'
import duckdb
con = duckdb.connect('/opt/data/dw.duckdb')
for t in ['hub_country','hub_indicator','hub_article','hub_location',
          'hub_commit','hub_sensor','link_country_indicator',
          'link_project_article','sat_country_indicator_values',
          'sat_article_views','sat_weather_hourly','sat_commit_meta',
          'sat_sensor_measurements']:
    try:
        n = con.execute(f"select count(*) from main.{t}").fetchone()[0]
        print(f"  {t}: {n} rows")
    except Exception as e:
        print(f"  {t}: ERROR - {e}")
con.close()
PYEOF
```

## CI/CD Pipeline

Two GitHub Actions workflows validate every push and PR.

### CI (`ci.yml`)

| Job | What it does | Requires AWS |
|-----|-------------|:---:|
| `dbt-parse` | Validates all SQL/Jinja in dbt models, macros, tests | No |
| `python-lint` | Lints and format-checks `ingestion/` with ruff | No |
| `dbt-integration` | Full `dbt build` against live S3 data | Yes |

The integration job runs automatically on push to main and can be triggered manually on PRs via `workflow_dispatch`. It requires an `aws` deployment environment with `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets.

### Terraform (`terraform.yml`)

| Step | What it does |
|------|-------------|
| `terraform fmt -check` | Validates HCL formatting |
| `terraform init` | Initializes providers and backends |
| `terraform validate` | Validates Terraform syntax |
| `terraform plan` | Dry-run to show infrastructure diffs |

### Configuring secrets

Add these to your repository **Settings → Secrets and variables → Actions**:

| Secret / Variable | Used by |
|-------------------|---------|
| `AWS_ACCESS_KEY_ID` (secret) | Terraform + dbt integration |
| `AWS_SECRET_ACCESS_KEY` (secret) | Terraform + dbt integration |
| `AWS_REGION` (variable) | Terraform init/plan |

For the integration job, create an **Environment** named `aws` and attach the AWS secrets to it.

## Production Considerations

Before going to production:

1. **Restrict SSH CIDR**: Change `ssh_ingress_cidr` from `0.0.0.0/0` to your specific IP range
2. **Enable S3 lifecycle**: Transition old raw JSON to Glacier after 30-60 days
3. **Enable S3 SSE**: Add server-side encryption on the raw vault bucket
4. **Set up AWS Budgets**: Alert on spend over $5-10/month
5. **Configure Metabase auth**: Enable authentication in Metabase settings
6. **Set up monitoring**: CloudWatch agent for EC2 metrics
7. **Backup DuckDB**: Regular snapshots of `/opt/data/dw.duckdb`
