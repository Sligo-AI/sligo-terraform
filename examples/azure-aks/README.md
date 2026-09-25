# Azure AKS Example

Deploy Sligo Cloud on Azure Kubernetes Service with Azure Database for PostgreSQL, Azure Managed Redis, and Azure Blob Storage.

## Your infrastructure repository

Copy this directory into your infrastructure repository. In `main.tf`, set the module source to the published tag:

```hcl
source = "github.com/Sligo-AI/sligo-terraform//modules/azure/aks?ref=v2.8.6"
```

Copy `terraform.tfvars.example` to `terraform.tfvars` and set your subscription, domain, and secrets there. Secret values stay in your configuration.

When you upgrade, compare this example at the new tag with your root module and update the module `ref`, `app_version`, and `chart_version`. Optional settings added in that tag appear in the example. Add a new argument in `main.tf` only when the module requires it.

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

## Full Guide

See the [Deploy on Azure AKS](https://sligo-ai.github.io/sligo-terraform/azure/) guide for step-by-step instructions.

## Recommended

For production or multiple environments, use `make create-environment-azure` to create a dedicated environment in `environments/`.
