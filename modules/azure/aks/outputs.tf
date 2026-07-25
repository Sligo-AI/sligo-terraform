output "temporal_enabled" {
  description = "Whether Temporal clients and the sligo-temporal-worker are enabled."
  value       = var.enable_temporal
}

output "temporal_self_hosted" {
  description = "Whether the in-cluster Temporal server (and Postgres DBs) are provisioned."
  value       = var.enable_temporal && var.temporal_self_hosted
}

output "temporal_database_names" {
  description = "Postgres database names used by self-hosted Temporal; null when Temporal is off or using Temporal Cloud."
  value = var.enable_temporal && var.temporal_self_hosted ? {
    default    = var.temporal_db_name
    visibility = var.temporal_visibility_db_name
  } : null
}

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
  description = "Redis endpoint (external redis_url when set, otherwise Azure Managed Redis hostname)"
  value       = local.use_external_redis ? "(external — see redis_url / REDIS_URL in app secrets)" : try(azurerm_managed_redis.redis[0].hostname, "")
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
