---
title: Getting Started
---

# Getting Started

Before deploying Sligo Cloud, you need credentials from Sligo.

## Step 1: Contact Sligo

Email **support@sligo.ai** to receive:

1. **Service Account Key (JSON file)** — Authenticates your cluster to pull container images from Sligo's Google Artifact Registry (GAR)
2. **Container Repository Name** — Your unique repository name (e.g., `your-company-containers`)

## Step 2: Save the Key File

Place the JSON key file in your project directory:

```
environments/aws-eks-prod/
├── sligo-service-account-key.json   ← Place here
├── main.tf
└── terraform.tfvars
```

**Important:** This file is in `.gitignore` — never commit it to version control.

## Step 3: Configure in Terraform

In your `terraform.tfvars`, set:

```hcl
sligo_service_account_key_path = "./sligo-service-account-key.json"
client_repository_name         = "your-company-containers"  # From Sligo
```

---

## Container Images

Images are pulled from:

```
us-central1-docker.pkg.dev/sligo-ai-platform/<client_repository_name>/sligo-frontend:<app_version>
us-central1-docker.pkg.dev/sligo-ai-platform/<client_repository_name>/sligo-backend:<app_version>
us-central1-docker.pkg.dev/sligo-ai-platform/<client_repository_name>/sligo-mcp-gateway:<app_version>
```

Terraform creates a Kubernetes image pull secret automatically — you only need the key file and path.

---

[← Back to overview](./) | [Next: Choose your cloud →](./#choose-your-cloud)
