output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = try(module.eks.cluster_endpoint, "")
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = try(module.eks.cluster_name, var.cluster_name)
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = try(aws_db_instance.postgres.endpoint, "")
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = try(aws_elasticache_replication_group.redis.primary_endpoint_address, "")
}

output "ingress_hostname" {
  description = "ALB hostname from ingress (will be available after Helm release)"
  value       = try(helm_release.sligo_cloud.metadata[0].name, "")
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.sligo.metadata[0].name
}

output "s3_bucket_name" {
  description = "S3 bucket name for application storage"
  value       = local.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = local.s3_bucket_arn
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (created or provided)"
  value       = local.certificate_arn
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate. Add these CNAME records to GoDaddy to validate the certificate."
  value = var.acm_certificate_arn == "" && length(aws_acm_certificate.sligo) > 0 ? [
    for record in aws_acm_certificate.sligo[0].domain_validation_options : {
      name   = replace(record.resource_record_name, ".${var.domain_name}.", "")  # Remove domain suffix for GoDaddy
      type   = record.resource_record_type
      value  = record.resource_record_value
      full_name = record.resource_record_name
    }
  ] : []
  sensitive = false
}
