# cloud-dw-datavault — Week 1 (Infra)

Lean, free‑tier‑friendly data platform on AWS using Terraform. 
This week: S3 Raw Vault (versioned + block public), EC2 AL2023 box, IAM least privilege, CI.

#### Prereqs

- AWS account with an admin user/role
- Terraform >= 1.5
- (Optional) An EC2 key pair for SSH (set `ssh_key_name` in `variables.tf`)

## Deploy

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve
```

### Outputs

*   `raw_vault_bucket_name`
*   `raw_vault_bucket_arn`
*   `ec2_public_ip` / `ec2_public_dns`
*   `resolved_al2023_ami`

### Connect by SSH

```bash
ssh -i /path/to/your_key.pem ec2-user@$(terraform output -raw ec2_public_dns)
```

> If you can’t SSH: ensure your **key pair** exists and `ssh_ingress_cidr` allows your IP.

### What’s installed on the EC2 host?

*   Amazon Linux 2023 with **DNF**
*   `docker` service enabled, `ec2-user` in `docker` group
*   Python 3 with:
    *   `duckdb`, `dbt-core`, `dbt-duckdb`
    *   `dagster`, `dagit`

> **Metabase**: Will run via Docker in Week 4 (`metabase/metabase`) per official docs; not installed via pip.

### Clean up

```bash
cd infra/terraform
terraform destroy
```

### Notes

*   AMI resolved dynamically via **SSM public parameter** (always latest AL2023 x86\_64).
*   S3 **Block Public Access** enabled + **Versioning** for immutable raw data.
*   EC2 instance role limited to this project’s raw vault bucket and SSM read.

---

## Commands to run (local)

```bash
# from repo root
cd infra/terraform
terraform init
terraform apply
````

**Verify** on the instance:

```bash
ssh -i ~/.ssh/your_key.pem ec2-user@<public-dns>
docker --version          # should work without sudo
dnf --version             # DNF present (AL2023)
python3 -c "import duckdb; print(duckdb.__version__)"
dbt --version
```
