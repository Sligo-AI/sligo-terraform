module "sligo_gcp" {
  source = "../../modules/gcp/gke"

  # Cluster configuration
  cluster_name    = var.cluster_name
  gcp_project_id  = var.gcp_project_id
  gcp_region      = var.gcp_region
  gcp_zones       = var.gcp_zones
  cluster_version = var.cluster_version

  # Application configuration
  domain_name                    = var.domain_name
  client_repository_name         = var.client_repository_name
  app_version                    = var.app_version
  sligo_service_account_key_path = var.sligo_service_account_key_path

  # Database configuration
  db_tier     = var.db_tier
  db_username = var.db_username
  db_password = var.db_password

  # Redis configuration
  redis_memory_size_gb = var.redis_memory_size_gb

  # Secrets
  jwt_secret          = var.jwt_secret
  api_key             = var.api_key
  nextauth_secret     = var.nextauth_secret
  gateway_secret      = var.gateway_secret
  frontend_url        = var.frontend_url
  next_public_api_url = var.next_public_api_url
}
