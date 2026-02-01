---
title: Sligo Cloud Terraform
---

# Sligo Cloud - Terraform Modules

Deploy Sligo Cloud Platform on your preferred cloud with production-ready Terraform modules.

## Choose Your Cloud

| Cloud | Guide |
|-------|-------|
| **AWS** | [Deploy on AWS EKS →](aws/) |
| **Google Cloud** | [Deploy on GCP GKE →](gcp/) |
| **Microsoft Azure** | [Deploy on Azure AKS →](azure/) |

---

## What You Get

- **Kubernetes cluster** (EKS, GKE, or AKS)
- **Managed database** (Aurora/Cloud SQL/Azure Database for PostgreSQL)
- **Managed cache** (ElastiCache/Memorystore/Azure Cache for Redis)
- **Object storage** (S3/GCS/Azure Blob)
- **Helm chart deployment** with secrets and ingress
- **Environment automation** via `make create-environment`

---

## Prerequisites (All Clouds)

- **Terraform** >= 1.0
- **kubectl** and **Helm** >= 3.10
- **Sligo credentials** (service account key + repository name) — [Get started →](getting-started/)
- **Domain name** for your application
- **Cloud credentials** configured (AWS CLI, gcloud, or az)

---

## Quick Links

- [Sligo credentials & setup](getting-started/)
- [Secrets management](secrets/)
- [Multiple environments (dev/staging/prod)](multiple-environments/)
- [Upgrading](upgrading/)
- [Troubleshooting](troubleshooting/)

---

## Support

- **Email:** support@sligo.ai
- **Issues:** [GitHub Issues](https://github.com/Sligo-AI/sligo-terraform/issues)
