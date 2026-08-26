output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.sligo_gcp.cluster_endpoint
}

output "database_endpoint" {
  description = "Cloud SQL database endpoint"
  value       = module.sligo_gcp.database_endpoint
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "ingress_hostname" {
  description = "Load balancer hostname"
  value       = module.sligo_gcp.ingress_hostname
}

output "redis_backend" {
  description = "Redis backend: external, memorystore, or in-cluster"
  value       = module.sligo_gcp.redis_backend
}

output "redis_endpoint" {
  description = "Redis discovery / service endpoint"
  value       = module.sligo_gcp.redis_endpoint
}
