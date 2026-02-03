---
layout: page
title: "Deploy on GCP GKE"
description: "Step-by-step guide for deploying Sligo Cloud on Google GKE with Cloud SQL, Memorystore, and Cloud Storage."
---

# Deploy Sligo Cloud on GCP GKE

Step-by-step guide for deploying on Google Kubernetes Engine with Cloud SQL, Memorystore Redis, and Cloud Storage.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [gcloud CLI](https://cloud.google.com/sdk/gcloud) with `gcloud auth application-default login`
- [Sligo credentials](../getting-started/)
- A **GCP project** with billing enabled

---

## Step 1: Create Your Environment

```bash
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

make create-environment-gcp
```

When prompted:
- **Environment name:** e.g., `prod`, `dev`, `staging`
- **GCP region:** e.g., `us-central1`, `europe-west1`
- **Cluster name:** defaults to `sligo-{env-name}`
- **Domain name:** e.g., `app.example.com`
- **Client repository name:** from Sligo
- **App version:** e.g., `v1.0.0` (pin for production)

This creates `environments/gcp-gke-{env-name}/` with pre-filled config.

---

## Step 2: Add Sligo Credentials

```bash
cd environments/gcp-gke-{your-env-name}

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
| `cluster_name` | GKE cluster name |
| `gcp_project_id` | Your GCP project ID |
| `gcp_region` | e.g., `us-central1` |
| `domain_name` | Your app domain |
| `client_repository_name` | From Sligo |
| `app_version` | e.g., `v1.0.0` |
| `db_password` | Database password |
| `jwt_secret`, `api_key`, `nextauth_secret`, `gateway_secret` | App secrets |
| `encryption_key` | 64 hex chars: `openssl rand -hex 32` |

**Optional:** `db_tier` (default `db-f1-micro`), `redis_memory_size_gb`, `use_existing_gcs_bucket`.

---

## Step 4: Deploy

```bash
terraform init
terraform plan
terraform apply
```

Deployment typically takes 15–25 minutes (GKE + Cloud SQL + Memorystore + GCS buckets).

---

## Step 5: Post-Deploy — DNS

1. Get the load balancer IP/hostname:
   ```bash
   kubectl get ingress -n sligo
   ```

2. Create an A or CNAME record pointing your domain to the GCE load balancer.

---

## What Gets Created

- **GKE cluster** with node pool
- **Cloud SQL** (PostgreSQL)
- **Memorystore** (Redis)
- **4 GCS buckets** (file-manager, agent-avatars, logos, rag)
- **GCE Ingress** (HTTP(S) load balancer)
- **Sligo Cloud Helm chart** deployment

---

## Manual Setup (Without create-environment)

```bash
cd examples/gcp-gke
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (add gcp_project_id, secrets, etc.)
terraform init && terraform apply
```

---

[← Back to overview](../) | [AWS →](../aws/) | [Azure →](../azure/)
