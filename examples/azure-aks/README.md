# Azure AKS Example

Deploy Sligo Cloud on Azure Kubernetes Service with Azure Database for PostgreSQL, Azure Cache for Redis, and Azure Blob Storage.

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (secrets, location, etc.)
terraform init && terraform apply
```

## Full Guide

See the [Deploy on Azure AKS](https://sligo-ai.github.io/sligo-terraform/azure/) guide for step-by-step instructions.

## Recommended

For production or multiple environments, use `make create-environment-azure` to create a dedicated environment in `environments/`.
