output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "database_endpoint" {
  description = "Cloud SQL database endpoint"
  value       = google_sql_database_instance.postgres.connection_name
}

output "redis_endpoint" {
  description = "Memorystore Redis endpoint"
  value       = google_redis_instance.redis.host
}

output "ingress_hostname" {
  description = "Load balancer hostname from ingress (will be available after Helm release)"
  value       = try(helm_release.sligo_cloud.metadata[0].name, "")
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.sligo.metadata[0].name
}

output "gcs_bucket_file_manager_name" {
  description = "GCS bucket name for file manager storage"
  value       = local.gcs_bucket_file_manager_id
}

output "gcs_bucket_agent_avatars_name" {
  description = "GCS bucket name for agent avatars"
  value       = local.gcs_bucket_agent_avatars_id
}

output "gcs_bucket_logos_name" {
  description = "GCS bucket name for MCP logos"
  value       = local.gcs_bucket_logos_id
}

output "gcs_bucket_rag_name" {
  description = "GCS bucket name for RAG storage"
  value       = local.gcs_bucket_rag_id
}
