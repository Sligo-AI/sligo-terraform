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

output "storage_account_name" {
  description = "Azure Storage account name"
  value       = local.storage_account_name
}
