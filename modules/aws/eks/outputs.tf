output "temporal_enabled" {
  description = "Whether self-hosted Temporal infrastructure is provisioned."
  value       = var.enable_temporal
}

output "temporal_database_names" {
  description = "Postgres database names used by Temporal when enable_temporal is true."
  value = var.enable_temporal ? {
    default    = var.temporal_db_name
    visibility = var.temporal_visibility_db_name
  } : null
}

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
  description = "Redis endpoint (external redis_url when set, otherwise ElastiCache primary endpoint)"
  value       = local.use_external_redis ? "(external — see redis_url / REDIS_URL in app secrets)" : try(aws_elasticache_replication_group.redis[0].primary_endpoint_address, "")
}

output "ingress_hostname" {
  description = "ALB hostname for DNS CNAME when alb_hostname is set; otherwise the Helm release name. Get real ALB hostname: kubectl get ingress -n sligo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
  value       = var.alb_hostname != "" ? var.alb_hostname : try(helm_release.sligo_cloud.metadata[0].name, "sligo-cloud")
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.sligo.metadata[0].name
}

output "external_secrets_operator_enabled" {
  description = "Whether External Secrets Operator resources are managed by this module."
  value       = var.enable_external_secrets_operator
}

output "secret_manager_project_id" {
  description = "GCP project ID used for central Secret Manager when ESO is enabled."
  value       = var.secret_manager_project_id
}

output "secret_name_prefix" {
  description = "Computed secret prefix used for deployment-isolated GSM secret IDs."
  value       = local.gsm_secret_prefix
}

output "gcp_adc_enabled" {
  description = "Whether GCP credentials are configured (credentials flow via GCP_SA_KEY/GOOGLE_VERTEX_AI_WEB_CREDENTIALS in secrets, not via file mount)"
  value       = local.gcp_adc_enabled
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

# Parent zone of domain_name (e.g. "sligo.ai" from "app-staging.sligo.ai") for DNS record names
locals {
  _domain_parts = split(var.domain_name, ".")
  _zone_suffix  = length(local._domain_parts) > 1 ? join(".", slice(local._domain_parts, 1, length(local._domain_parts))) : var.domain_name
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate. When route53_zone_id is set these are created automatically; otherwise add these CNAME records in your DNS provider (public DNS only). Use name_for_zone as the record name in a zone matching zone_suffix (e.g. for sligo.ai use name_for_zone as the CNAME name)."
  value = var.acm_certificate_arn == "" && length(aws_acm_certificate.sligo) > 0 ? [
    for record in aws_acm_certificate.sligo[0].domain_validation_options : {
      type          = record.resource_record_type
      value         = record.resource_record_value
      full_name     = trim(record.resource_record_name, ".")
      zone_suffix   = local._zone_suffix
      name_for_zone = replace(trim(record.resource_record_name, "."), ".${local._zone_suffix}", "")
    }
  ] : []
  sensitive = false
}

# Post-apply DNS steps (when not fully automated via Route 53)
locals {
  _validation_records = var.acm_certificate_arn == "" && length(aws_acm_certificate.sligo) > 0 ? tolist(aws_acm_certificate.sligo[0].domain_validation_options) : []
  _first_validation   = length(local._validation_records) > 0 ? local._validation_records[0] : null
  _step1_acm = length(local._validation_records) > 0 && var.route53_zone_id == "" ? [
    "1. ACM validation (public DNS): Add a CNAME record in your DNS provider.",
    "   Name:  ${replace(trim(local._first_validation.resource_record_name, "."), ".${local._zone_suffix}", "")}",
    "   Value: ${local._first_validation.resource_record_value}",
    "   (Zone suffix: ${local._zone_suffix})",
    "   Then wait until the certificate is ISSUED (ACM checks automatically; can take a few minutes)."
    ] : (length(local._validation_records) > 0 && var.route53_zone_id != "" ? [
      "1. ACM validation: Terraform created the CNAME in Route 53. Wait until the certificate is ISSUED."
  ] : [])
  _step2 = [
    "2. Get ALB hostname (after cert is ISSUED):",
    "   kubectl get ingress -n sligo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
  ]
  _step3 = [
    "3. Add CNAMEs in your DNS (point to the hostname from step 2):",
    "   ${var.domain_name} -> <ALB hostname>",
    "   api.${var.domain_name} -> <ALB hostname>",
    "   Or set route53_zone_id and alb_hostname in Terraform and apply again to create these in Route 53."
  ]
  dns_next_steps_lines = concat(
    local._step1_acm,
    local._step2,
    local._step3
  )
}

output "dns_next_steps" {
  description = "Post-apply DNS and SSL steps. Run 'terraform output dns_next_steps' for copy-paste instructions."
  value       = join("\n", local.dns_next_steps_lines)
}

output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity when create_ses_resources is true."
  value       = try(aws_ses_domain_identity.email[0].arn, null)
}

output "ses_verification_token" {
  description = "TXT record value for _amazonses.<domain> to verify the SES identity."
  value       = try(aws_ses_domain_identity.email[0].verification_token, null)
}

output "ses_dkim_tokens" {
  description = "DKIM tokens; publish each as <token>._domainkey.<domain> CNAME to <token>.dkim.amazonses.com."
  value       = try(aws_ses_domain_dkim.email[0].dkim_tokens, null)
}
