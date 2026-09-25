# AWS EKS Example

Deploy Sligo Cloud on AWS EKS with Aurora Serverless v2 PostgreSQL, ElastiCache Redis, and S3.

## Your infrastructure repository

Copy this directory into your infrastructure repository. In `main.tf`, set the module source to the published tag:

```hcl
source = "github.com/Sligo-AI/sligo-terraform//modules/aws/eks?ref=v2.8.6"
```

Copy `terraform.tfvars.example` to `terraform.tfvars` and set your account, domain, and secrets there. Secret values stay in your configuration.

When you upgrade, compare this example at the new tag with your root module and update the module `ref`, `app_version`, and `chart_version`. Optional settings added in that tag appear in the example. Add a new argument in `main.tf` only when the module requires it.

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

## Full Guide

See the [Deploy on AWS EKS](https://sligo-ai.github.io/sligo-terraform/aws/) guide for step-by-step instructions.

## Recommended

For production or multiple environments, use `make create-environment-aws` to create a dedicated environment in `environments/`.
