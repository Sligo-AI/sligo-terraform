---
layout: home
permalink: /
title: "Sligo Enterprise - Terraform Modules"
description: "Official Terraform modules for deploying Sligo Enterprise Platform on AWS EKS, GCP GKE, and Azure AKS."
hero_actions:
  - label: "Get Started"
    url: "/getting-started/"
    style: "primary"
    icon: true
  - label: "View on GitHub"
    url: "https://github.com/Sligo-AI/sligo-terraform"
    style: "outline"
features:
  - title: "Infrastructure as Code"
    description: "Production-ready Terraform configurations for AWS EKS, GCP GKE, and Azure AKS deployments."
    icon: "cloud"
  - title: "Automated Provisioning"
    description: "Kubernetes clusters, managed databases, cache, storage, and Helm chart deployment."
    icon: "server"
  - title: "Multiple Environments"
    description: "Easy management of dev, staging, and production with isolated configurations."
    icon: "cog"
  - title: "Integrated with Helm"
    description: "Seamlessly deploys the Sligo Enterprise Helm Chart with all required configurations."
    icon: "package"
---

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
