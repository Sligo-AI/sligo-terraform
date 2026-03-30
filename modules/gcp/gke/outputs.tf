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
  description = "In-cluster Redis Stack service endpoint"
  value       = "redis.sligo.svc.cluster.local:6379"
}

output "ingress_hostname" {
  description = "Kubernetes ingress resource name"
  value       = try(helm_release.sligo_cloud.metadata[0].name, "")
}

output "ingress_address" {
  description = "External IP or hostname of the GCE load balancer (for DNS). Empty until LB is ready."
  value       = local.ingress_address
}

output "managed_ssl_certificate_enabled" {
  description = "Whether a GKE ManagedCertificate was created for HTTPS. Once DNS points to the LB, Google will provision and renew the cert automatically."
  value       = var.use_managed_ssl_certificate
}

output "dns_records" {
  description = "DNS record to create for the application (point your domain to the load balancer). Required for the managed SSL certificate to be issued."
  value = local.ingress_address != "" ? [
    {
      name   = var.domain_name
      type   = "A"
      target = local.ingress_address
      note   = "App (or use CNAME if target is a hostname)"
    }
    ] : [
    {
      name   = "Pending"
      type   = "-"
      target = "Run: kubectl get ingress -n sligo sligo-cloud -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
      note   = "Load balancer not ready yet; run the command to get the IP when ready"
    }
  ]
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
