---
layout: home
title: "Sligo Cloud - Terraform Modules"
description: "Official Terraform modules for deploying Sligo Cloud Platform on AWS EKS and Google Cloud GKE."
hero_actions:
  - label: "Get Started"
    url: "/sligo-terraform/quick-start/"
    style: "primary"
    icon: true
  - label: "View on GitHub"
    url: "https://github.com/Sligo-AI/sligo-terraform"
    style: "outline"
features:
  - title: "Infrastructure as Code"
    description: "Production-ready Terraform configurations for AWS EKS and GCP GKE deployments."
    icon: "cloud"
  - title: "Automated Provisioning"
    description: "Kubernetes clusters, managed databases, cache, storage, and Helm chart deployment."
    icon: "server"
  - title: "Multiple Environments"
    description: "Easy management of dev, staging, and production environments with isolated configurations."
    icon: "cog"
  - title: "Integrated with Helm"
    description: "Seamlessly deploys the Sligo Cloud Helm Chart with all required secrets and configurations."
    icon: "package"
---

## What This Repository Provides

- **Infrastructure as Code (IAC)** for Sligo Cloud deployments
- **Reusable Terraform modules** for AWS EKS and GCP GKE
- **Complete examples** with best practices
- **Environment automation** - Use `make create-environment` to quickly create new environments

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

# Create a new environment (interactive prompts)
make create-environment
```

<div class="callout callout--info">
  <div class="callout-content">
    <div class="callout-title">Prerequisites</div>
    Before you begin, ensure you have Terraform >= 1.0, Helm >= 3.10, and your cloud provider credentials configured. See the <a href="/sligo-terraform/prerequisites/">Prerequisites</a> page for details.
  </div>
</div>

## Supported Platforms

| Platform | Module | Status |
|----------|--------|--------|
| AWS EKS | `modules/aws/eks` | ✅ Production Ready |
| GCP GKE | `modules/gcp/gke` | ✅ Production Ready |

## Related Documentation

- [Sligo Helm Charts](https://sligo-ai.github.io/sligo-helm-charts/) - Application deployment charts
- [Configuration Reference](/sligo-terraform/variables/) - All available Terraform variables
