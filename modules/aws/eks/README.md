# Sligo Cloud - AWS EKS Module

This module provisions AWS infrastructure and deploys Sligo Cloud using the Helm chart.

## Usage

```hcl
module "sligo_aws" {
  source = "github.com/Sligo-AI/sligo-terraform//modules/aws/eks"

  cluster_name    = "sligo-production"
  domain_name     = "app.example.com"
  client_repository_name = "your-client-containers"
  
  # ... other variables
}
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- Kubernetes Provider >= 2.23
- Helm Provider >= 2.11

## Inputs

See [variables.tf](./variables.tf) for complete list.

## Outputs

See [outputs.tf](./outputs.tf) for complete list.
