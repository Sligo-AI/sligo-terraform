---
layout: page
title: "Deploy on Azure AKS"
description: "Step-by-step guide for deploying Sligo Enterprise on Azure AKS with Azure Database for PostgreSQL, Azure Managed Redis, and Blob Storage."
---

{% include theme-image.html light="azure-deployment.png" dark="azure-deployment-dark.png" alt="Azure Deployment" %}

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
| `jwt_secret`, `api_key`, `backend_api_key`, `nextauth_secret`, `gateway_secret` | App secrets (`backend_api_key` is the frontend↔backend service key, min 32 chars) |
| `encryption_key` | 64 hex chars: `openssl rand -hex 32` |

**Optional:** `postgres_sku_name`, `redis_sku_name`, `node_pool_vm_size`, `use_existing_storage_account`, `super_admin_emails`, `auth_invitations`, `release_upgrade_trigger`.

For PostgreSQL Flexible Server, `postgres_sku_name` must use Azure Database SKU names (for example `B_Standard_B1ms`, `B_Standard_B4ms`, `GP_Standard_D2s_v3`). Do not use Compute VM size names.

AKS logs (control plane and container stdout/stderr via Container Insights) default to **400 days** in Log Analytics. PostgreSQL backups default to **7 days** (Azure requires 7–35) with a CanNotDelete lock when `db_deletion_protection` is true. Staging/dev should lower log retention and set `db_deletion_protection = false`; see [Multiple environments](../multiple-environments/).

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
- **Azure Managed Redis**
- **Azure Storage Account** with 4 blob containers (file-manager, agent-avatars, logos, rag)
- **Nginx Ingress Controller** (LoadBalancer service)
- **Sligo Enterprise Helm chart** deployment

Optional **`enable_temporal = true`** enables Temporal clients and the worker. Default **`temporal_self_hosted = true`** also adds Flexible Server Temporal databases and the in-cluster server; set **`temporal_self_hosted = false`** with Cloud address/API key for Temporal Cloud only. See [secrets.md — Temporal](../secrets/#temporal-terraform-variables) and [terraform.tfvars.temporal.example](../examples/azure-aks/terraform.tfvars.temporal.example).

Optional **`enable_langfuse = true`** with default **`langfuse_self_hosted = true`** adds a `langfuse` Flexible Server database, a private blob container, ClickHouse operator/cert-manager (unless skipped), and a `langfuse.<domain>` ingress host. TLS uses a **separate** nginx secret (`langfuse-tls-cert`), not a second name on `app-tls-cert`. Point DNS for `langfuse.<domain>` at the same nginx LoadBalancer as the app. See [secrets.md — Langfuse](../secrets/#langfuse-terraform-variables) and [terraform.tfvars.langfuse.example](../examples/azure-aks/terraform.tfvars.langfuse.example).

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
