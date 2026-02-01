# Sligo Cloud - Terraform Modules

Deploy Sligo Cloud Platform on AWS, Google Cloud, or Azure with production-ready Terraform modules.

## Choose Your Cloud

| Cloud | Guide |
|-------|-------|
| **AWS EKS** | [Deploy on AWS →](https://sligo-ai.github.io/sligo-terraform/docs/aws.html) |
| **Google Cloud GKE** | [Deploy on GCP →](https://sligo-ai.github.io/sligo-terraform/docs/gcp.html) |
| **Microsoft Azure AKS** | [Deploy on Azure →](https://sligo-ai.github.io/sligo-terraform/docs/azure.html) |

---

## Quick Start

```bash
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

# Create environment (prompts for cloud: aws-eks, gcp-gke, or azure-aks)
make create-environment

# Or specify cloud directly:
make create-environment-aws    # AWS EKS
make create-environment-gcp    # GCP GKE
make create-environment-azure  # Azure AKS
```

Then configure your environment and run `terraform init && terraform apply`.

---

## What You Get

- **Kubernetes cluster** (EKS, GKE, or AKS)
- **Managed database** (Aurora / Cloud SQL / Azure Database for PostgreSQL)
- **Managed cache** (ElastiCache / Memorystore / Azure Cache for Redis)
- **Object storage** (S3 / GCS / Azure Blob)
- **Helm chart deployment** with secrets and ingress
- **Environment automation** via `make create-environment`

---

## Prerequisites

- **Terraform** >= 1.0, **kubectl**, **Helm** >= 3.10
- **Sligo credentials** — Contact support@sligo.ai for service account key + repository name
- **Domain name** for your application
- **Cloud credentials** — AWS CLI, gcloud, or az login

---

## Documentation

| Topic | Link |
|-------|------|
| Getting started (Sligo credentials) | [docs/getting-started](https://sligo-ai.github.io/sligo-terraform/docs/getting-started.html) |
| Secrets management | [docs/secrets](https://sligo-ai.github.io/sligo-terraform/docs/secrets.html) |
| Multiple environments | [docs/multiple-environments](https://sligo-ai.github.io/sligo-terraform/docs/multiple-environments.html) |
| Upgrading | [docs/upgrading](https://sligo-ai.github.io/sligo-terraform/docs/upgrading.html) |
| Troubleshooting | [docs/troubleshooting](https://sligo-ai.github.io/sligo-terraform/docs/troubleshooting.html) |

---

## Repository Structure

```
sligo-terraform/
├── modules/
│   ├── aws/eks/      # AWS EKS module
│   ├── gcp/gke/      # GCP GKE module
│   └── azure/aks/    # Azure AKS module
├── examples/
│   ├── aws-eks/
│   ├── gcp-gke/
│   └── azure-aks/
├── docs/             # Full documentation (GH Pages)
└── scripts/
    └── create-environment.sh
```

---

## Support

- **Email:** support@sligo.ai
- **Issues:** [GitHub Issues](https://github.com/Sligo-AI/sligo-terraform/issues)
