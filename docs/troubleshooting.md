---
layout: page
title: "Troubleshooting"
description: "Common issues and solutions for Sligo Terraform deployments."
---

## Common Issues

### Terraform init fails

- Ensure Terraform >= 1.0.
- Run `terraform init -upgrade` to refresh providers.

### Image pull errors (ImagePullBackOff)

- Confirm `sligo_service_account_key_path` points to a valid JSON file.
- Check the key has access to the GAR repository.
- Verify `client_repository_name` matches what Sligo provided.

### Database connection failures

- Ensure security groups/firewall allow access from the cluster to the database.
- Check `db_password` is correct and not truncated.

### Query the database

The application connects over private TCP. On AWS, the RDS Data API (`aurora_enable_http_endpoint`) is **off** by default.

From a workstation with `kubectl` access to the cluster, copy `DATABASE_URL` from the `backend-secrets` secret and run `psql` in a throwaway pod:

```bash
DB_URL=$(kubectl get secret -n sligo backend-secrets -o jsonpath='{.data.DATABASE_URL}' | base64 -d)
kubectl run -n sligo -it --rm psql --image=postgres:15 --restart=Never --env="DATABASE_URL=${DB_URL}" -- \
  psql "$DATABASE_URL"
```

GCP Cloud SQL and Azure Flexible Server are private-IP only; the same in-cluster `psql` approach applies.

To tear down a protected database, set deletion protection to `false` (AWS `db_deletion_protection`, GCP `cloud_sql_deletion_protection`, Azure `db_deletion_protection`), apply, then destroy.

### LiteParse pods unschedulable (Insufficient cpu)

Chart 1.2.1 defaults LiteParse to 2 replicas requesting 2 CPU each. Default node sizes are 2 vCPU, so those pods cannot schedule (`Preemption is not helpful`, `Insufficient cpu`).

The module overrides this to 1 replica requesting 1 CPU / 2Gi with a 2 CPU / 4Gi limit (Cloud Run LiteParse size, but a request that still fits 2-vCPU nodes). If you are still on module `v2.4.0`, set `helm_extra_values` until you upgrade:

```hcl
helm_extra_values = <<-YAML
liteparse:
  replicaCount: 1
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
YAML
```

### Ingress / Load balancer not ready

- **AWS:** Wait for ALB creation (can take a few minutes). Check AWS Load Balancer Controller logs.
- **GCP:** GCE ingress provisioning can take 5–10 minutes.
- **Azure:** Ensure nginx ingress controller has an external IP; check `kubectl get svc -n ingress-nginx`.

### Terraform plan shows unexpected changes

- Review `lifecycle` blocks in modules.
- For node pool changes, some may require cluster recreation — review the plan carefully.

## Getting Help

- **Sligo support:** support@sligo.ai
- **Helm chart issues:** [sligo-helm-charts](https://github.com/Sligo-AI/sligo-helm-charts)
- **Terraform module issues:** [sligo-terraform](https://github.com/Sligo-AI/sligo-terraform/issues)

---

[← Back to overview](../)
