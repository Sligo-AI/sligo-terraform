# GCP GKE Example

Complete example for deploying Sligo Cloud on GCP GKE.

## Prerequisites

- GCP project with billing enabled
- gcloud CLI configured
- Terraform >= 1.0
- kubectl installed
- Sligo service account key

## Usage

1. Copy the example variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the plan:
   ```bash
   terraform plan
   ```

5. Apply:
   ```bash
   terraform apply
   ```

## Configuration

See `terraform.tfvars.example` for all available options.
