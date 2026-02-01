output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = try(module.eks.cluster_endpoint, "")
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = try(module.eks.cluster_name, var.cluster_name)
}

output "database_endpoint" {
  description = "Aurora Serverless v2 cluster endpoint"
  value       = try("${aws_rds_cluster.postgres.endpoint}:${aws_rds_cluster.postgres.port}", "")
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = try(aws_elasticache_replication_group.redis.primary_endpoint_address, "")
}

output "ingress_hostname" {
  description = "ALB hostname for DNS CNAME. Use: kubectl get ingress -n sligo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
  value       = try(helm_release.sligo_cloud.metadata[0].name, "")
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.sligo.metadata[0].name
}

output "s3_bucket_name" {
  description = "S3 bucket name for file manager storage (backward compatibility)"
  value       = local.s3_bucket_file_manager_id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for file manager (backward compatibility)"
  value       = local.s3_bucket_file_manager_arn
}

output "s3_bucket_file_manager_name" {
  description = "S3 bucket name for file manager storage"
  value       = local.s3_bucket_file_manager_id
}

output "s3_bucket_agent_avatars_name" {
  description = "S3 bucket name for agent avatars"
  value       = local.s3_bucket_agent_avatars_id
}

output "s3_bucket_logos_name" {
  description = "S3 bucket name for MCP logos"
  value       = local.s3_bucket_logos_id
}

output "s3_bucket_rag_name" {
  description = "S3 bucket name for RAG storage"
  value       = local.s3_bucket_rag_id
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (created or provided)"
  value       = local.certificate_arn
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate. Add these CNAME records to GoDaddy to validate the certificate."
  value = var.acm_certificate_arn == "" && length(aws_acm_certificate.sligo) > 0 ? [
    for record in aws_acm_certificate.sligo[0].domain_validation_options : {
      name      = replace(record.resource_record_name, ".${var.domain_name}.", "") # Remove domain suffix for GoDaddy
      type      = record.resource_record_type
      value     = record.resource_record_value
      full_name = record.resource_record_name
    }
  ] : []
  sensitive = false
}
