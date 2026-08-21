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

Pin the Helm chart in `terraform.tfvars` the same way as the app image tag (independent pins):

```hcl
app_version   = "v1.2.3"  # container image tags
chart_version = "1.2.1"   # sligo-cloud chart from sligo-helm-charts (default 1.2.1)
```

Set `chart_path` to use a local chart `.tgz` instead of the repository (ignores `chart_version`).

## Kubernetes / Cluster Upgrades

- **AWS EKS:** Update `cluster_version` in variables, then `terraform apply`.
- **GCP GKE:** Update `cluster_version`, then apply.
- **Azure AKS:** Update `cluster_version`, then apply.

Test upgrades in a non-production environment first.

---

[← Back to overview](../)
