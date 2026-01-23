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

  # Database configuration
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_username          = var.db_username
  db_password          = var.db_password
  prisma_accelerate_url = var.prisma_accelerate_url

  # Redis configuration
  redis_node_type = var.redis_node_type

  # S3 Storage configuration
  s3_bucket_name         = var.s3_bucket_name
  s3_bucket_versioning   = var.s3_bucket_versioning
  s3_bucket_encryption   = var.s3_bucket_encryption
  use_existing_s3_bucket = var.use_existing_s3_bucket

  # Secrets
  jwt_secret          = var.jwt_secret
  api_key             = var.api_key
  nextauth_secret     = var.nextauth_secret
  gateway_secret      = var.gateway_secret
  frontend_url        = var.frontend_url
  next_public_api_url = var.next_public_api_url
  workos_api_key      = var.workos_api_key
  workos_client_id    = var.workos_client_id
  workos_cookie_password = var.workos_cookie_password
  encryption_key      = var.encryption_key
  
  # Google Cloud Configuration
  next_public_google_client_id = var.next_public_google_client_id
  next_public_google_client_key = var.next_public_google_client_key
  google_client_secret = var.google_client_secret
  google_project_id = var.google_project_id
  google_api_key = var.google_api_key
  google_storage_bucket = var.google_storage_bucket
  google_storage_agent_avatars_bucket = var.google_storage_agent_avatars_bucket
  google_storage_mcp_logos_bucket = var.google_storage_mcp_logos_bucket
  google_storage_rag_sa_key = var.google_storage_rag_sa_key
  file_manager_google_projectid = var.file_manager_google_projectid
  
  # Pinecone Configuration
  pinecone_api_key = var.pinecone_api_key
  pinecone_index = var.pinecone_index
}
