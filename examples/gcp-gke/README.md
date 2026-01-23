# GCP GKE Example

Complete example for deploying Sligo Cloud on GCP GKE.

## Prerequisites

- GCP project with billing enabled
- gcloud CLI configured (`gcloud auth application-default login`)
- Terraform >= 1.0
- kubectl installed
- **Sligo Service Account Key** (JSON file) - Contact support@sligo.ai
  - Place this file in the `examples/gcp-gke/` directory
  - Name it: `sligo-service-account-key.json`
  - This file is automatically ignored by git for security
- **Container Repository Name** - Provided by Sligo support
  - Your unique repository name in Sligo's Google Artifact Registry

## Step-by-Step Usage

1. **Get your Sligo credentials:**
   - Contact support@sligo.ai for your service account key and repository name

2. **Place your service account key:**
   ```bash
   # Place sligo-service-account-key.json in this directory
   ls -la sligo-service-account-key.json
   ```

3. **Copy and configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   # Set client_repository_name (from Sligo)
   # Set sligo_service_account_key_path = "./sligo-service-account-key.json"
   ```

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Review the plan:**
   ```bash
   terraform plan
   ```

6. **Apply:**
   ```bash
   terraform apply
   ```

## Container Registry Access

Sligo Cloud containers are stored in **Google Artifact Registry (GAR)**. The service account key you place in this directory allows your Kubernetes cluster to pull container images from Sligo's registry. Terraform automatically creates the necessary image pull secrets.

## Configuration

See `terraform.tfvars.example` for all available options.
