# cloud-dw-datavault

A lean, **free‑tier‑friendly** data platform on AWS that lands **full JSON payloads** from public APIs into an **S3 Raw Vault**, then normalizes them with **DuckDB** + **dbt** into a **Business Vault** (hubs, links, satellites) and **PIT** tables for fast analytics. Orchestration via **Dagster**, dashboards via **Metabase** (Docker), CI via **GitHub Actions**.

> **References used throughout**  
> • **Amazon Linux 2023** uses **DNF** for packages (not `yum`). [1](https://docs.getdbt.com/reference/node-selection/methods)  
> • **AL2023 AMI** resolved via **SSM public parameter** (no hard‑coding). [2](https://publicapis.io/open-aq-api)  
> • **S3 Block Public Access** recommended to prevent accidental exposure. [3](https://awslaunchgoat.com/docs/sso/configure)  
> • **Wikimedia REST API** requires a descriptive **User‑Agent** header. [4](https://github.com/duckdb/dbt-duckdb)[5](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami-parameter-store.html)  
> • **DuckDB JSON** reading + functions; **read_json_auto** supports files/URLs/globs. [6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)[7](https://duckdb.org/2025/04/04/dbt-duckdb)  
> • **dbt tests** (`not_null`, `unique`, `relationships`, `accepted_values`) and YAML deprecations (args nested under `arguments:` in dbt 1.10). [8](https://github.com/orgs/community/discussions/102883)[9](https://repost.aws/questions/QUWZrri8lCTCmD8G0SNL5lUw/public-ssm-parameter-and-cloudformation)  
> • **Data Vault 2.0** (hubs/links/sats, hash keys, insert‑only, PIT tables). [10](https://repost.aws/knowledge-center/s3-block-public-access-setting)[6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)

---

## 1) Architecture (Week 1–4)

**Week 1 (Infra):**
- Terraform creates:
  - **S3 Raw Vault** (versioning + **Block Public Access**)
  - **IAM** role/profile for EC2 with least‑privilege S3 + SSM read
  - **EC2** (AL2023) resolving AMI via **SSM parameter**; user‑data installs Python + Docker + CLIs

**Week 2 (Ingestion):**
- Six extractors write **full JSON** (gzip) to S3:
  - **World Bank** (Indicators v2)  
  - **Open‑Meteo** (hourly/daily)  
  - **Wikimedia Pageviews** (per‑article) – **requires User‑Agent**  
  - **GitHub** commits (optional token)  
  - **OpenAQ** v3 (key required)  
  - **USGS** earthquake GeoJSON

**Week 3 (Business Vault):**
- **DuckDB** + **dbt** staging models normalize JSON
- **Hubs** (hash keys via **SHA‑256(UPPER(TRIM(bkey))**)  
- **Links** (relationship HK over concatenated standardized keys)  
- **Satellites** (insert‑only; **hash diff** for change detection)  
- Initial **PIT** tables; seed **marts** views

**Week 4 (Marts & Ops):**
- Expand **PIT** + **marts** (article traffic, population, weather, air quality, quakes, commits)
- **Metabase** dashboards (Docker)
- **Dagster** schedules (extract → dbt build → tests)
- **GitHub Actions** CI for Terraform + dbt
- **Cost/Security guardrails** (Budgets, S3 lifecycle, SSE)

---

## 2) Prerequisites

- An AWS account + admin role/user
- **Terraform** ≥ 1.5
- **AWS CLI v2**
- **Git** (on EC2 and your workstation)
- An **EC2 key pair** (`.pem`) for SSH, or use **Session Manager**
- dbt and Python installed on EC2 (user‑data or pip `--user`)

> AL2023 (Amazon Linux 2023) uses **DNF** for packages; its AMI can be looked up via **SSM public parameters**, and that’s how we avoid hard‑coded AMI IDs. [1](https://docs.getdbt.com/reference/node-selection/methods)[2](https://publicapis.io/open-aq-api)

---

## 3) Repository Layout

```

cloud-dw-datavault/
├─ infra/terraform/        # Week 1 infra (S3, IAM, EC2)
│  ├─ main.tf variables.tf s3.tf iam.tf ec2.tf outputs.tf user\_data.sh
├─ ingestion/              # Week 2 extractors (Python)
│  ├─ common/ config.py s3\_utils.py utils.py **init**.py
│  ├─ extract\_worldbank.py extract\_weather.py extract\_wikimedia.py
│  ├─ extract\_github.py extract\_openaq.py extract\_usgs.py
├─ dbt/                    # Week 3 models (DuckDB)
│  ├─ dbt\_project.yml
│  ├─ models/
│  │  ├─ sources.yml
│  │  ├─ staging/          # stg\_worldbank.sql, stg\_wikimedia.sql, stg\_usgs.sql, ...
│  │  ├─ business\_vault/   # hubs/, links/, satellites/, pit/
│  │  └─ marts/            # analytics views
│  ├─ macros/              # hash\_key.sql, hash\_diff.sql
│  └─ models/tests.yml
├─ orchestration/dagster/  # Week 2–4 pipeline
│  └─ dw\_pipeline.py  dbt\_ops.py
├─ warehouse/duckdb/init.sql
├─ requirements.txt
└─ README.md

````

---

## 4) Week 1 — Provision AWS

### 4.1 Initialize & apply Terraform

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve
````

**Outputs** include:

*   `raw_vault_bucket_name` (`cloud-dw-datavault-raw-vault`)
*   `ec2_public_dns` / `ec2_public_ip`
*   `resolved_al2023_ami` (marked `sensitive`)

**Notes**

*   S3 **Block Public Access** is enabled for defense‑in‑depth. [\[awslaunchgoat.com\]](https://awslaunchgoat.com/docs/sso/configure)
*   The AL2023 AMI is selected via **SSM public parameter** (no region‑specific ID needed). [\[publicapis.io\]](https://publicapis.io/open-aq-api)

### 4.2 SSH or Session Manager

**SSH** (if you attached a key pair):

```bash
ssh -i ~/.ssh/<your-key>.pem ec2-user@$(terraform output -raw ec2_public_dns)
```

**Session Manager** (no SSH key):

1.  Attach policy **AmazonSSMManagedInstanceCore** to the EC2 role
2.  Verify **Systems Manager → Managed instances**
3.  Start session:
    ```bash
    aws ssm start-session --target <instance-id>
    ```

***

## 5) Week 2 — Ingestion on EC2

### 5.1 Install Python tooling (if user‑data didn’t already)

```bash
# AL2023 (DNF)
sudo dnf install -y python3-pip git docker
systemctl enable --now docker
usermod -aG docker ec2-user

# Python packages (user scope)
python3 -m pip install --upgrade pip wheel setuptools
python3 -m pip install --user -r requirements.txt
python3 -m pip install --user dbt-core dbt-duckdb dagster dagit duckdb
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

> AL2023 uses **DNF** for package management; Docker enables running Metabase later via official images. [\[docs.getdbt.com\]](https://docs.getdbt.com/reference/node-selection/methods), [\[bluebirz.net\]](https://bluebirz.net/posts/try-dbt-part-7/)

### 5.2 Clone the repo on EC2

```bash
cd ~
git clone https://github.com/<your-org>/cloud-dw-datavault.git
cd cloud-dw-datavault
echo 'export PYTHONPATH=$(pwd)' >> ~/.bashrc && source ~/.bashrc
```

### 5.3 Configure AWS CLI (if not using instance role)

```bash
aws configure
aws sts get-caller-identity
```

### 5.4 Required environment variables

*   **Wikimedia**: set **User‑Agent** (or `Api-User-Agent`) **and** contact info
    ```bash
    export HTTP_APP_NAME="cloud-dw-datavault"
    export HTTP_CONTACT="mailto:you@yourcompany.com"
    ```
    > Wikimedia requires a descriptive **User‑Agent** with contact info; calls without it may be blocked. [\[github.com\]](https://github.com/duckdb/dbt-duckdb)

*   **OpenAQ**:
    ```bash
    export OPENAQ_API_KEY="your-openaq-key"
    ```

*   **GitHub** (optional):
    ```bash
    export GITHUB_TOKEN="ghp_***"
    ```

### 5.5 Run all six extractors

> Each prints the `s3://…` key where the **full JSON** payload was written (`.json.gz`).  
> Our `utils.py` helper sets the **User‑Agent** on all HTTP calls.

```bash
# World Bank (ZA population)
python3 -u -m ingestion.extract_worldbank --indicator SP.POP.TOTL --country ZA

# Open-Meteo (Johannesburg)
python3 -u -m ingestion.extract_weather --lat -26.2041 --lon 28.0473 \
  --hourly temperature_2m,relativehumidity_2m

# Wikimedia (Nelson Mandela pageviews; daily range)
python3 -u -m ingestion.extract_wikimedia --project en.wikipedia.org --article Nelson_Mandela \
  --access all-access --agent all-agents --granularity daily --start 20250101 --end 20250107

# GitHub commits (public repo)
python3 -u -m ingestion.extract_github --owner octocat --repo Hello-World

# OpenAQ (sensor example)
python3 -u -m ingestion.extract_openaq --sensor_id 3917 --resource measurements --limit 500

# USGS GeoJSON
python3 -u -m ingestion.extract_usgs --feed all_day
```

Verify objects in S3:

```bash
aws s3 ls s3://cloud-dw-datavault-raw-vault/ --recursive --human-readable --summarize
```

***

## 6) Week 3 — Business Vault (DuckDB + dbt)

### 6.1 dbt profile (DuckDB)

Create `~/.dbt/profiles.yml` on EC2:

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
      settings:
        # Use AWS credential chain (instance role / env / config)
        # No explicit keys required here in most cases.
```

Ensure path exists:

```bash
sudo mkdir -p /opt/data && sudo chown ec2-user:ec2-user /opt/data
dbt debug --project-dir dbt
```

> DuckDB’s `httpfs` extension reads JSON directly from S3 with **credential chain**; `read_json_auto()` handles files, URLs, and globs. [\[registry.t...rraform.io\]](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)

### 6.2 Macros (must exist)

Create `dbt/macros/hash_key.sql` and `dbt/macros/hash_diff.sql`:

```sql
-- hash_key.sql
{% macro hash_key(expr) -%}
{{ return(adapter.dispatch('hash_key', 'cloud_dw_datavault')(expr)) }}
{%- endmacro %}
{% macro default__hash_key(expr) -%}
sha256(upper(trim({{ expr }})))
{%- endmacro %}
```

```sql
-- hash_diff.sql
{% macro hash_diff(cols) -%}
sha256(upper(trim({{ cols | join(" || '|' || ") }})))
{%- endmacro %}
```

> DV2.0 recommends standardized hash keys and **insert‑only** satellites with **hash diff** change detection. [\[repost.aws\]](https://repost.aws/knowledge-center/s3-block-public-access-setting), [\[docs.aws.amazon.com\]](https://docs.aws.amazon.com/AmazonS3/latest/userguide/configuring-block-public-access-bucket.html)

### 6.3 Update dbt tests (deprecation in 1.10)

Nest generic test arguments under `arguments:` in `dbt/models/tests.yml` for `relationships`:

```yaml
- name: link_country_indicator
  columns:
    - name: hk_country
      tests:
        - relationships:
            arguments:
              to: ref('hub_country')
              field: hk_country
```

> dbt 1.10 deprecates top‑level generic test args; use `arguments:` (or `args:`). [\[repost.aws\]](https://repost.aws/questions/QUWZrri8lCTCmD8G0SNL5lUw/public-ssm-parameter-and-cloudformation)

### 6.4 Build staging + BV

```bash
cd dbt
dbt parse
dbt build --select "path:models/staging"
dbt build --select "path:models/business_vault"
dbt test  --select "path:models/business_vault"
```

**Selection syntax** uses method:value (e.g., `path:` / `source:`), not `sources:`. [\[apidog.com\]](https://apidog.com/apidoc/docs-site/345761/api-3507853)

### 6.5 Verify counts

```bash
python3 - <<'PY'
import duckdb
con = duckdb.connect('/opt/data/dw.duckdb')
for t in [
  'hub_country','hub_indicator','hub_article','hub_location','hub_commit','hub_sensor',
  'link_country_indicator','link_project_article',
  'sat_country_indicator_values','sat_article_views','sat_weather_hourly','sat_commit_meta','sat_sensor_measurements'
]:
    try:
        print(t, con.execute(f"select count(*) from {t}").fetchone()[0])
    except Exception as e:
        print(t, "ERROR:", e)
PY
```

***

## 7) Week 4 — PIT Tables, Marts, Dashboards, Orchestration, CI

### 7.1 PIT tables

Create PIT models under `dbt/models/business_vault/pit/` for common grains:

*   `pit_article_day.sql` — daily views per `hk_article, project_id`
*   `pit_country_indicator_year.sql` — yearly values per `hk_country, hk_indicator`

> PIT tables precompute temporal joins for fast downstream analytics in DV2.0. [\[registry.t...rraform.io\]](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)

### 7.2 Marts (views)

Create views under `dbt/models/marts/`:

*   `article_traffic_daily.sql`
*   `population_by_country_year.sql`
*   Add weather, air quality, quake, and commit marts similarly.

Run:

```bash
dbt build --select "path:models/marts"
dbt test  --select "path:models/marts"
```

### 7.3 Metabase (Docker)

```bash
docker run -d --name metabase -p 3000:3000 \
  -v /opt/data:/metabase-data \
  -e MB_DB_FILE=/metabase-data/metabase.db \
  metabase/metabase:latest
```

*   Open `http://<EC2 public DNS>:3000`
*   Add a data source (see DuckDB options, or point to a warehouse)
*   Build dashboards (article traffic, population, weather, air quality, quakes, commits)

> Metabase official Docker quick‑start; DuckDB can be connected via community drivers or MotherDuck (managed). [\[bluebirz.net\]](https://bluebirz.net/posts/try-dbt-part-7/), [\[deeplearni...gnerds.com\]](https://www.deeplearningnerds.com/how-to-add-generic-data-tests-to-your-dbt-models-improve-data-quality-with-confidence/)

### 7.4 Dagster orchestration

*   Ensure `PYTHONPATH=$(pwd)` from repo root.
*   Start UI:
    ```bash
    dagit -m orchestration.dagster.dw_pipeline --port 3001
    ```
*   Add an `op` to call `dbt build` after extraction:
    ```python
    subprocess.run(["dbt", "build", "--select", "path:models/business_vault,path:models/marts"], check=True)
    ```
*   Create a daily **schedule** in Dagster for end‑to‑end.

### 7.5 GitHub Actions (CI)

*   Add a workflow that runs:
    *   Terraform `fmt`/`validate`/`plan` on PRs
    *   `dbt parse` + `dbt compile` (and optionally `dbt build --select path:models/staging`)
*   Use **OIDC** or repository **Secrets** for AWS credentials.

***

## 8) Production guardrails (recommended)

*   **AWS Budgets** via Terraform (USD $5–$10) to alert on spend
*   **S3 lifecycle**:
    *   Transition raw JSON `.json.gz` to IA/Glacier after 30–60 days
*   **S3 SSE**:
    *   Add `ServerSideEncryption='AES256'` in `s3_utils.put_json()` for compliance
*   **IAM**:
    *   Favor SSO/roles for human users; least privilege; MFA as policy. [\[docs.aws.amazon.com\]](https://docs.aws.amazon.com/linux/al2023/ug/AMI-minimal-and-standard-differences.html)

***

## 9) Performance tip: Consolidate JSON → Parquet (optional)

Running DuckDB, periodically collapse many tiny JSONs to **Parquet** (still keep raw JSON):

```sql
COPY (
  SELECT *
  FROM read_json_auto('s3://cloud-dw-datavault-raw-vault/wikimedia/en.wikipedia.org/Nelson_Mandela/*/*.json.gz')
) TO 's3://cloud-dw-datavault-raw-vault/wikimedia/mandela_daily.parquet' (FORMAT 'parquet');
```

> Consolidating early reduces small‑file overhead and speeds scans; `read_json_auto()` + `COPY TO PARQUET` is the simple path. [\[docs.w3cub.com\]](https://docs.w3cub.com/terraform/providers/aws/d/ssm_parameter.html)

***

## 10) Troubleshooting

*   **`hash_key is undefined`**  
    Ensure `dbt/macros/hash_key.sql` and `hash_diff.sql` exist; re‑run `dbt parse`.

*   **`403 / 429` on Wikimedia**  
    Set **User‑Agent** + contact env vars; our helper adds headers on all calls. [\[github.com\]](https://github.com/duckdb/dbt-duckdb)

*   **`sources:raw_vault` selection error**  
    Use `source:raw_vault` or `path:` selectors; `sources:` is not valid. [\[apidog.com\]](https://apidog.com/apidoc/docs-site/345761/api-3507853)

*   **Freshness warnings on sources**  
    Remove `freshness:` from sources.yml or define `loaded_at_field` (duckdb adapter limitation). [\[apidog.com\]](https://apidog.com/apidoc/docs-site/345761/api-3507853)

*   **DuckDB CLI vs Python**  
    You have DuckDB **Python** (dbt‑duckdb works). `python3 -m duckdb` isn’t a CLI; use `duckdb` binary if you install it, or run SQL via Python. [\[registry.t...rraform.io\]](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)

***

## 11) What’s next (roadmap)

**Immediate (this week):**

*   ✅ Merge macros & test fixes
*   ✅ Build **all six** staging + BV
*   ✅ Create **PIT** + first **marts**
*   ✅ Spin up **Metabase** and draft dashboards
*   ✅ Add Dagster `dbt_build` op + daily schedule
*   ✅ Add CI (Terraform + dbt parse/compile)

**Near‑term:**

*   Add **source‑side filters**/params (e.g., multiple articles, more indicators, larger weather variables)
*   Expand **tests** (accepted values, singular SQL tests for anomaly detection) [\[github.com\]](https://github.com/orgs/community/discussions/102883)
*   Add **lifecycle/SSE** and **Budgets** (Terraform)

**Optional enhancements:**

*   Write **Parquet consolidation** jobs and consume Parquet in dbt sources for speed
*   Introduce **PIT** tables for all domains (weather daily, OpenAQ hourly/daily, USGS daily bins, GitHub daily commits)
*   Consider **MotherDuck** if you want remote DuckDB + Metabase native connectivity

***

## 12) Command quick‑start (everything end‑to‑end)

```bash
# ==== Infra (Week 1) ====
cd infra/terraform
terraform init && terraform apply -auto-approve

# ==== EC2 access ====
ssh -i ~/.ssh/<key>.pem ec2-user@$(terraform output -raw ec2_public_dns)

# ==== Repo & environment ====
cd ~/cloud-dw-datavault
echo 'export PYTHONPATH=$(pwd)' >> ~/.bashrc && source ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
export HTTP_APP_NAME="cloud-dw-datavault"
export HTTP_CONTACT="mailto:you@yourcompany.com"

# ==== Ingestion (Week 2) ====
python3 -u -m ingestion.extract_worldbank --indicator SP.POP.TOTL --country ZA
python3 -u -m ingestion.extract_weather --lat -26.2041 --lon 28.0473 --hourly temperature_2m,relativehumidity_2m
python3 -u -m ingestion.extract_wikimedia --project en.wikipedia.org --article Nelson_Mandela \
  --access all-access --agent all-agents --granularity daily --start 20250101 --end 20250107
python3 -u -m ingestion.extract_github --owner octocat --repo Hello-World
export OPENAQ_API_KEY="your-openaq-key"
python3 -u -m ingestion.extract_openaq --sensor_id 3917 --resource measurements --limit 500
python3 -u -m ingestion.extract_usgs --feed all_day

# ==== dbt (Week 3) ====
sudo mkdir -p /opt/data && sudo chown ec2-user:ec2-user /opt/data
dbt debug --project-dir dbt
dbt parse
dbt build --select "path:models/staging,path:models/business_vault"
dbt build --select "path:models/marts"
dbt test  --select "path:models/business_vault,path:models/marts"

# ==== Metabase (Week 4) ====
docker run -d --name metabase -p 3000:3000 \
  -v /opt/data:/metabase-data -e MB_DB_FILE=/metabase-data/metabase.db metabase/metabase:latest

# ==== Dagster ====
dagit -m orchestration.dagster.dw_pipeline --port 3001
```

***

## 13) License & Contributions

*   PRs welcome for new sources, marts, dashboards, and CI improvements.

***

## 14) Acknowledgements

*   Thanks to the teams behind **DuckDB**, **dbt**, **Dagster**, and the open **API** providers (World Bank, Wikimedia, Open‑Meteo, USGS, GitHub, OpenAQ).

```
