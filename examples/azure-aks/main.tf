module "sligo_azure" {
  source = "../../modules/azure/aks"

  # Cluster configuration
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  location            = var.location
  resource_group_name = var.resource_group_name

  # Node pool configuration
  node_pool_min_count = var.node_pool_min_count
  node_pool_max_count = var.node_pool_max_count
  node_pool_vm_size   = var.node_pool_vm_size

  # Application configuration
  domain_name                    = var.domain_name
  client_repository_name         = var.client_repository_name
  app_version                    = var.app_version
  sligo_service_account_key_path = var.sligo_service_account_key_path

  # Database configuration
  db_username         = var.db_username
  db_password         = var.db_password
  postgres_sku_name   = var.postgres_sku_name
  postgres_storage_mb = var.postgres_storage_mb

  # Redis configuration
  redis_sku_name = var.redis_sku_name
  redis_family   = var.redis_family
  redis_capacity = var.redis_capacity

  # Storage configuration
  use_existing_storage_account = var.use_existing_storage_account

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

  # SPENDHQ Configuration
  spendhq_base_url      = var.spendhq_base_url
  spendhq_client_id     = var.spendhq_client_id
  spendhq_client_secret = var.spendhq_client_secret
  spendhq_token_url     = var.spendhq_token_url
  spendhq_ss_host       = var.spendhq_ss_host
  spendhq_ss_username   = var.spendhq_ss_username
  spendhq_ss_password   = var.spendhq_ss_password
  spendhq_ss_port       = var.spendhq_ss_port
}
