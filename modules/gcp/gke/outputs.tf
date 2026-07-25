output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
}

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

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "database_endpoint" {
  description = "Cloud SQL database endpoint"
  value       = google_sql_database_instance.postgres.connection_name
}

output "redis_endpoint" {
  description = "Redis endpoint (external redis_url when set, otherwise in-cluster Redis Stack service)"
  value       = local.use_external_redis ? "(external — see redis_url / REDIS_URL in app secrets)" : "redis.sligo.svc.cluster.local:6379"
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

output "external_secrets_operator_enabled" {
  description = "Whether External Secrets Operator resources are managed by this module."
  value       = var.enable_external_secrets_operator
}

output "secret_manager_project_id" {
  description = "Project ID used for central Secret Manager reads/writes when ESO is enabled."
  value       = var.secret_manager_project_id
}

output "secret_name_prefix" {
  description = "Computed secret prefix used for deployment-isolated secret IDs."
  value       = local.gsm_secret_prefix
}
