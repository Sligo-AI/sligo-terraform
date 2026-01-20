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

output "gcs_bucket_name" {
  description = "GCS bucket name for application storage"
  value       = google_storage_bucket.app_storage.name
}

output "gcs_bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.app_storage.url
}
