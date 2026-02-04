---
layout: page
title: "Upgrading"
description: "Upgrade Sligo Enterprise application and Terraform module versions."
---

## Application Version

To upgrade Sligo Enterprise to a new version:

1. Check available versions (contact support@sligo.ai or check your GAR).
2. Update `app_version` in `terraform.tfvars`:

   ```hcl
   app_version = "v1.2.3"  # New version
   ```

3. Apply:

   ```bash
   terraform plan
   terraform apply
   ```

**Production:** Pin to specific versions (e.g., `v1.0.0`). Avoid `latest`.

## Helm Chart Version

The Helm chart version is tied to `app_version` in the module. Updating `app_version` typically updates the chart as needed.

## Kubernetes / Cluster Upgrades

- **AWS EKS:** Update `cluster_version` in variables, then `terraform apply`.
- **GCP GKE:** Update `cluster_version`, then apply.
- **Azure AKS:** Update `cluster_version`, then apply.

Test upgrades in a non-production environment first.

---

[← Back to overview](../)
