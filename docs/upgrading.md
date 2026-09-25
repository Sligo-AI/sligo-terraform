---
layout: page
title: "Upgrading"
description: "Upgrade Sligo Enterprise application and Terraform module versions."
---

## Application version

An app release records the Helm chart and Terraform module that were current at that moment. Those two keep their own version numbers.

```bash
bun terraform/resolve-release.ts v1.32.0
# helm=1.4.2
# terraform=v2.8.6
```

The manifest is `terraform/release-manifest.json` in [sligo-cloud](https://github.com/Sligo-AI/sligo-cloud), also attached to that app's GitHub Release.

In your own repository, set `app_version` to the image tag. Set `chart_version` and the module `ref` to the recorded companions. You can set either pin yourself when you need a different chart or module than the one recorded for that app version.

```hcl
app_version   = "v1.32.0"
chart_version = "1.4.2"
```

```hcl
source = "github.com/Sligo-AI/sligo-terraform//modules/gcp/gke?ref=v2.8.6"
```

Copy `examples/<cloud>` from that tag into your repository, then change `source` from the relative module path to the `ref` above. On a later upgrade, diff your root against the example at the new tag. A new secret is a module variable with a default, shown in that example. Set the value in your own `terraform.tfvars` or secret manager. Your `main.tf` needs a new argument only when the input has no default.

`make create-environment` still copies the published example once into `environments/` for anyone working inside this repository. That copy does not track later example edits.

## Kubernetes / Cluster Upgrades

- **AWS EKS:** Update `cluster_version` in variables, then `terraform apply`.
- **GCP GKE:** Update `cluster_version`, then apply.
- **Azure AKS:** Update `cluster_version`, then apply.

Test upgrades in a non-production environment first.

---

[← Back to overview](../)
