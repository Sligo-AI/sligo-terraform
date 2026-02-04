---
layout: page
title: "Deploy on AWS EKS"
description: "Step-by-step guide for deploying Sligo Cloud on Amazon EKS with Aurora, ElastiCache, and S3."
---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [AWS CLI](https://aws.amazon.com/cli/) configured: `aws configure` or environment variables
- [Sligo credentials](../getting-started/)

---

## Step 1: Create Your Environment

```bash
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

make create-environment-aws
```

When prompted:
- **Environment name:** e.g., `prod`, `dev`, `staging`
- **AWS region:** e.g., `us-east-1`, `us-west-2`, `eu-west-1`
- **Cluster name:** defaults to `sligo-{env-name}`
- **Domain name:** e.g., `app.example.com`
- **Client repository name:** from Sligo
- **App version:** e.g., `v1.0.0` (pin for production)

This creates `environments/aws-eks-{env-name}/` with pre-filled config.

---

## Step 2: Add Sligo Credentials

```bash
cd environments/aws-eks-{your-env-name}

# Copy your Sligo service account key here
cp /path/to/sligo-service-account-key.json ./
```

Ensure `terraform.tfvars` has:

```hcl
sligo_service_account_key_path = "./sligo-service-account-key.json"
```

---

## Step 3: Configure terraform.tfvars

Edit `terraform.tfvars` with your values. Key variables:

| Variable | Description |
|----------|-------------|
| `cluster_name` | EKS cluster name |
| `aws_region` | e.g., `us-east-1` |
| `domain_name` | Your app domain |
| `client_repository_name` | From Sligo |
| `app_version` | e.g., `v1.0.0` |
| `db_password` | Database password |
| `jwt_secret`, `api_key`, `nextauth_secret`, `gateway_secret` | App secrets |
| `encryption_key` | 64 hex chars: `openssl rand -hex 32` |

**Optional:** `acm_certificate_arn` for existing TLS cert, or leave empty to auto-create.

---

## Step 4: Deploy

```bash
terraform init
terraform plan
terraform apply
```

Deployment typically takes 15–25 minutes (EKS + Aurora + ElastiCache + S3).

---

## Step 5: Post-Deploy — DNS

1. Get the load balancer hostname:
   ```bash
   kubectl get ingress -n sligo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
   ```

2. Create a CNAME record:
   - **Name:** Your domain (e.g., `app.example.com`)
   - **Value:** The ALB hostname from above

3. If using auto-created ACM cert, add the DNS validation records shown in `terraform output acm_certificate_validation_records` to your DNS provider.

---

## What Gets Created

- **EKS cluster** with managed node group
- **Aurora Serverless v2** (PostgreSQL)
- **ElastiCache Redis**
- **4 S3 buckets** (file-manager, agent-avatars, logos, rag)
- **AWS Load Balancer Controller** + ALB ingress
- **Sligo Cloud Helm chart** deployment

---

## Manual Setup (Without create-environment)

```bash
cd examples/aws-eks
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init && terraform apply
```

---

[← Back to overview](../) | [GCP →](../gcp/) | [Azure →](../azure/)
