output "cluster_endpoint" {
  description = "AKS cluster endpoint"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "database_endpoint" {
  description = "Azure Database for PostgreSQL endpoint"
  value       = "${azurerm_postgresql_flexible_server.postgres.fqdn}:5432"
}

output "redis_endpoint" {
  description = "Azure Cache for Redis endpoint"
  value       = azurerm_redis_cache.redis.hostname
}

output "ingress_hostname" {
  description = "Load balancer hostname (available after nginx ingress provisions)"
  value       = try(helm_release.sligo_cloud.metadata[0].name, "")
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.sligo.metadata[0].name
}

output "external_secrets_operator_enabled" {
  description = "Whether External Secrets Operator resources are managed by this module."
  value       = var.enable_external_secrets_operator
}

output "secret_manager_project_id" {
  description = "GCP project ID used for central Secret Manager when ESO is enabled."
  value       = var.secret_manager_project_id
}

output "secret_name_prefix" {
  description = "Computed secret prefix used for deployment-isolated GSM secret IDs."
  value       = local.gsm_secret_prefix
}

output "storage_account_name" {
  description = "Azure Storage account name"
  value       = local.storage_account_name
}
