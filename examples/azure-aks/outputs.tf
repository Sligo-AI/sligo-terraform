output "cluster_endpoint" {
  description = "AKS cluster endpoint"
  value       = module.sligo_azure.cluster_endpoint
}

output "database_endpoint" {
  description = "Azure Database for PostgreSQL endpoint"
  value       = module.sligo_azure.database_endpoint
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "ingress_hostname" {
  description = "Load balancer hostname"
  value       = module.sligo_azure.ingress_hostname
}
