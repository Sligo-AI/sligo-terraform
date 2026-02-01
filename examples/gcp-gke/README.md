# GCP GKE Example

Deploy Sligo Cloud on GCP GKE with Cloud SQL, Memorystore Redis, and Cloud Storage.

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (gcp_project_id, secrets, etc.)
terraform init && terraform apply
```

## Full Guide

See the [Deploy on GCP GKE](https://sligo-ai.github.io/sligo-terraform/docs/gcp.html) guide for step-by-step instructions.

## Recommended

For production or multiple environments, use `make create-environment-gcp` to create a dedicated environment in `environments/`.
