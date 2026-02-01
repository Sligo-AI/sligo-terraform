module "sligo_aws" {
  source = "../../modules/aws/eks"

  # Cluster configuration
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  aws_region      = var.aws_region

  # Application configuration
  domain_name                    = var.domain_name
  client_repository_name         = var.client_repository_name
  app_version                    = var.app_version
  sligo_service_account_key_path = var.sligo_service_account_key_path
  acm_certificate_arn            = var.acm_certificate_arn

  # Database configuration (Aurora Serverless v2)
  db_username           = var.db_username
  db_password           = var.db_password
  aurora_min_capacity   = var.aurora_min_capacity
  aurora_max_capacity   = var.aurora_max_capacity
  aurora_instance_class = var.aurora_instance_class

  # Redis configuration
  redis_node_type = var.redis_node_type

  # S3 Storage configuration
  s3_bucket_name         = var.s3_bucket_name
  s3_bucket_versioning   = var.s3_bucket_versioning
  s3_bucket_encryption   = var.s3_bucket_encryption
  use_existing_s3_bucket = var.use_existing_s3_bucket

  # Secrets
  jwt_secret             = var.jwt_secret
  api_key                = var.api_key
  nextauth_secret        = var.nextauth_secret
  gateway_secret         = var.gateway_secret
  frontend_url           = var.frontend_url
  next_public_api_url    = var.next_public_api_url
  workos_api_key         = var.workos_api_key
  workos_client_id       = var.workos_client_id
  workos_cookie_password = var.workos_cookie_password
  encryption_key         = var.encryption_key

  # Google Cloud Configuration
  next_public_google_client_id     = var.next_public_google_client_id
  next_public_google_client_key    = var.next_public_google_client_key
  google_client_secret             = var.google_client_secret
  google_project_id                = var.google_project_id
  gcp_sa_key                       = var.gcp_sa_key
  rag_sa_key                       = var.rag_sa_key
  google_vertex_ai_web_credentials = var.google_vertex_ai_web_credentials
  anthropic_api_key                = var.anthropic_api_key
  verbose_logging                  = var.verbose_logging
  backend_request_timeout_ms       = var.backend_request_timeout_ms
  openai_base_url                  = var.openai_base_url
  langsmith_api_key                = var.langsmith_api_key

  # Pinecone Configuration
  pinecone_api_key = var.pinecone_api_key
  pinecone_index   = var.pinecone_index

  # SPENDHQ Configuration (for mcp-gateway)
  spendhq_base_url      = var.spendhq_base_url
  spendhq_client_id     = var.spendhq_client_id
  spendhq_client_secret = var.spendhq_client_secret
  spendhq_token_url     = var.spendhq_token_url
  spendhq_ss_host       = var.spendhq_ss_host
  spendhq_ss_username   = var.spendhq_ss_username
  spendhq_ss_password   = var.spendhq_ss_password
  spendhq_ss_port       = var.spendhq_ss_port
}
