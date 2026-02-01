# AWS EKS Example

Deploy Sligo Cloud on AWS EKS with Aurora Serverless v2 PostgreSQL, ElastiCache Redis, and S3.

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (secrets, region, etc.)
terraform init && terraform apply
```

## Full Guide

See the [Deploy on AWS EKS](https://sligo-ai.github.io/sligo-terraform/aws/) guide for step-by-step instructions.

## Recommended

For production or multiple environments, use `make create-environment-aws` to create a dedicated environment in `environments/`.
