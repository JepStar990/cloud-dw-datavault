#!/bin/bash
set -euxo pipefail

# Amazon Linux 2023 uses DNF (not yum)
# Ref: AL2023 package management tool is DNF
# https://docs.aws.amazon.com/linux/al2023/ug/package-management.html
dnf update -y
dnf install -y python3-pip git docker

# Enable Docker & allow ec2-user to use it without sudo
systemctl enable --now docker
usermod -aG docker ec2-user

# Upgrade pip and install core Python tooling
pip3 install --upgrade pip wheel setuptools

# Install data stack packages (runtime, not design tools):
# - DuckDB engine
# - dbt-core and dbt-duckdb adapter (local transforms)
## - Dagster orchestration CLI and UI (dagit)
pip3 install duckdb dbt-core dbt-duckdb dagster dagit

# Create a workspace directory
mkdir -p /opt/data && chown -R ec2-user:ec2-user /opt/data

# Record build info
echo "Built on $(date -u) with AL2023 + DNF" > /etc/motd

# Note: Metabase will run via Docker/JAR when needed (not pip).
