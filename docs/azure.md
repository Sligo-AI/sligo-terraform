---
layout: page
title: "Deploy on Azure AKS"
description: "Step-by-step guide for deploying Sligo Cloud on Azure AKS with Azure Database for PostgreSQL, Azure Cache for Redis, and Blob Storage."
---

# Deploy Sligo Cloud on Azure AKS

Step-by-step guide for deploying on Azure Kubernetes Service with Azure Database for PostgreSQL, Azure Cache for Redis, and Azure Blob Storage.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) with `az login`
- [Sligo credentials](../getting-started/)
- An **Azure subscription** with appropriate permissions

---

## Step 1: Create Your Environment

```bash
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

make create-environment-azure
```

When prompted:
- **Environment name:** e.g., `prod`, `dev`, `staging`
- **Azure location:** e.g., `eastus`, `westus2`, `westeurope`
- **Cluster name:** defaults to `sligo-{env-name}`
- **Domain name:** e.g., `app.example.com`
- **Client repository name:** from Sligo
- **App version:** e.g., `v1.0.0` (pin for production)

This creates `environments/azure-aks-{env-name}/` with pre-filled config.

---

## Step 2: Add Sligo Credentials

```bash
cd environments/azure-aks-{your-env-name}

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
| `cluster_name` | AKS cluster name |
| `location` | e.g., `eastus`, `westeurope` |
| `resource_group_name` | Leave empty to auto-create |
| `domain_name` | Your app domain |
| `client_repository_name` | From Sligo |
| `app_version` | e.g., `v1.0.0` |
| `db_password` | Database password |
| `jwt_secret`, `api_key`, `nextauth_secret`, `gateway_secret` | App secrets |
| `encryption_key` | 64 hex chars: `openssl rand -hex 32` |

**Optional:** `postgres_sku_name`, `redis_sku_name`, `node_pool_vm_size`, `use_existing_storage_account`.

---

## Step 4: Deploy

```bash
terraform init
terraform plan
terraform apply
```

Deployment typically takes 20–30 minutes (AKS + PostgreSQL + Redis + Storage + nginx ingress).

---

## Step 5: Post-Deploy — DNS

1. Get the nginx ingress load balancer IP:
   ```bash
   kubectl get svc -n ingress-nginx
   ```

2. Create an A record pointing your domain to the external IP.

---

## What Gets Created

- **AKS cluster** with system-assigned identity
- **Azure Database for PostgreSQL** (Flexible Server)
- **Azure Cache for Redis**
- **Azure Storage Account** with 4 blob containers (file-manager, agent-avatars, logos, rag)
- **Nginx Ingress Controller** (LoadBalancer service)
- **Sligo Cloud Helm chart** deployment

---

## Manual Setup (Without create-environment)

```bash
cd examples/azure-aks
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (add secrets, etc.)
terraform init && terraform apply
```

---

[← Back to overview](../) | [AWS →](../aws/) | [GCP →](../gcp/)
