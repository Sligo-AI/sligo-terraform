output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.sligo_aws.cluster_endpoint
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.sligo_aws.database_endpoint
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "ingress_hostname" {
  description = "Load balancer hostname"
  value       = module.sligo_aws.ingress_hostname
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.sligo_aws.acm_certificate_arn
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate"
  value       = module.sligo_aws.acm_certificate_validation_records
}
