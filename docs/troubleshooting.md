---
title: Troubleshooting
---

# Troubleshooting

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
