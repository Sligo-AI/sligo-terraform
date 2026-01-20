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

  # Database configuration
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_username          = var.db_username
  db_password          = var.db_password

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
}
