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
  chart_version                  = var.chart_version
  chart_path                     = var.chart_path
  helm_extra_values              = var.helm_extra_values
  enable_control_plane_exporter  = var.enable_control_plane_exporter
  sligo_service_account_key_path = var.sligo_service_account_key_path

  # Database configuration
  db_username         = var.db_username
  db_password         = var.db_password
  postgres_sku_name   = var.postgres_sku_name
  postgres_storage_mb = var.postgres_storage_mb

  # Redis configuration
  redis_sku_name                  = var.redis_sku_name
  redis_high_availability_enabled = var.redis_high_availability_enabled

  # Storage configuration
  use_existing_storage_account = var.use_existing_storage_account

  # Secrets
  jwt_secret             = var.jwt_secret
  api_key                = var.api_key
  backend_api_key        = var.backend_api_key
  nextauth_secret        = var.nextauth_secret
  gateway_secret         = var.gateway_secret
  frontend_url           = var.frontend_url
  next_public_api_url    = var.next_public_api_url
  workos_api_key         = var.workos_api_key
  workos_client_id       = var.workos_client_id
  workos_cookie_password = var.workos_cookie_password
  auth_provider          = var.auth_provider
  auth_invitations       = var.auth_invitations
  super_admin_emails     = var.super_admin_emails
  auth_session_secret    = var.auth_session_secret
  oidc_issuer            = var.oidc_issuer
  oidc_client_id         = var.oidc_client_id
  oidc_client_secret     = var.oidc_client_secret
  oidc_scopes            = var.oidc_scopes
  oidc_default_org_id    = var.oidc_default_org_id
  oidc_default_org_name  = var.oidc_default_org_name
  saml_entrypoint        = var.saml_entrypoint
  saml_issuer            = var.saml_issuer
  saml_cert              = var.saml_cert
  saml_default_org_id    = var.saml_default_org_id
  saml_default_org_name  = var.saml_default_org_name
  encryption_key         = var.encryption_key

  # Google Cloud Configuration
  next_public_google_client_id     = var.next_public_google_client_id
  next_public_google_client_key    = var.next_public_google_client_key
  google_client_secret             = var.google_client_secret
  google_project_id                = var.google_project_id
  storage_provider                 = var.storage_provider
  gcp_sa_key                       = var.gcp_sa_key
  rag_sa_key                       = var.rag_sa_key
  google_vertex_ai_web_credentials = var.google_vertex_ai_web_credentials
  anthropic_api_key                = var.anthropic_api_key
  together_ai_api_key              = var.together_ai_api_key
  verbose_logging                  = var.verbose_logging
  backend_request_timeout_ms       = var.backend_request_timeout_ms
  openai_base_url                  = var.openai_base_url
  langsmith_api_key                = var.langsmith_api_key
  langsmith_tracing                = var.langsmith_tracing
  langsmith_project                = var.langsmith_project
  langsmith_endpoint               = var.langsmith_endpoint

  # Pinecone Configuration
  pinecone_api_key     = var.pinecone_api_key
  pinecone_index       = var.pinecone_index
  pinecone_environment = var.pinecone_environment

  # RAG vector store (SingleStore optional)
  rag_vector_store     = var.rag_vector_store
  singlestore_host     = var.singlestore_host
  singlestore_port     = var.singlestore_port
  singlestore_user     = var.singlestore_user
  singlestore_password = var.singlestore_password
  singlestore_database = var.singlestore_database

  # Optional auth overrides
  auth_base_url           = var.auth_base_url
  auth_cookie_name        = var.auth_cookie_name
  auth_cookie_same_site   = var.auth_cookie_same_site
  release_upgrade_trigger = var.release_upgrade_trigger

  # SPENDHQ Configuration
  spendhq_base_url      = var.spendhq_base_url
  spendhq_client_id     = var.spendhq_client_id
  spendhq_client_secret = var.spendhq_client_secret
  spendhq_token_url     = var.spendhq_token_url
  spendhq_ss_host       = var.spendhq_ss_host
  spendhq_ss_username   = var.spendhq_ss_username
  spendhq_ss_password   = var.spendhq_ss_password
  spendhq_ss_port       = var.spendhq_ss_port

  # Azure AI Search (optional) + Azure OpenAI (optional)
  azure_aisearch_endpoint        = var.azure_aisearch_endpoint
  azure_aisearch_key             = var.azure_aisearch_key
  azure_aisearch_index           = var.azure_aisearch_index
  azure_aisearch_query_type      = var.azure_aisearch_query_type
  azure_openai_api_key           = var.azure_openai_api_key
  azure_openai_api_instance_name = var.azure_openai_api_instance_name
  azure_openai_api_version       = var.azure_openai_api_version
  azure_openai_base_path         = var.azure_openai_base_path
  bedrock_aws_region             = var.bedrock_aws_region
  bedrock_aws_bearer_token       = var.bedrock_aws_bearer_token

  # Postmark email (optional)
  postmark_server_token        = var.postmark_server_token
  email_from                   = var.email_from
  email_inbound_domain         = var.email_inbound_domain
  email_inbound_webhook_secret = var.email_inbound_webhook_secret
}
