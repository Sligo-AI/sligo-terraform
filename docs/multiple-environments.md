---
title: Multiple Environments
---

# Managing Multiple Environments

Run dev, staging, and production as separate deployments.

## Recommended: Use create-environment

```bash
make create-environment-aws   # or gcp / azure
```

Create one environment per target: `dev`, `staging`, `prod`.

## Directory Structure

```
environments/
├── aws-eks-dev/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── sligo-service-account-key.json
├── aws-eks-staging/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── sligo-service-account-key.json
└── aws-eks-prod/
    ├── main.tf
    ├── terraform.tfvars
    └── sligo-service-account-key.json
```

Each directory has its own Terraform state. Deploy independently:

```bash
cd environments/aws-eks-dev && terraform apply
cd ../aws-eks-prod && terraform apply
```

## Configuration Differences

| Setting | Dev | Staging | Prod |
|---------|-----|---------|------|
| `cluster_name` | sligo-dev | sligo-staging | sligo-prod |
| `domain_name` | dev.example.com | staging.example.com | app.example.com |
| Node/DB size | Smaller | Medium | Larger |
| Secrets | Different per env | Different per env | Different per env |

**Never reuse production secrets** in dev or staging.

## Same Service Account Key

You can use the **same** Sligo service account key for all environments — they all pull from your container repository.

---

[← Back to overview](index.html)
