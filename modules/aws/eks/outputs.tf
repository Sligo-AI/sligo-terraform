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
  value       = try(aws_elasticache_replication_group.redis.configuration_endpoint_address, "")
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
