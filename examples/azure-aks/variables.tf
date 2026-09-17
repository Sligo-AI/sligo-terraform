# Cluster Configuration
variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.28"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Azure resource group name (leave empty to auto-create)"
  type        = string
  default     = ""
}

variable "node_pool_min_count" {
  type    = number
  default = 2
}

variable "node_pool_max_count" {
  type    = number
  default = 4
}

variable "node_pool_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

# Application Configuration
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "client_repository_name" {
  description = "Client-specific GAR repository name (provided by Sligo)"
  type        = string
}

variable "app_version" {
  description = "Sligo Cloud application version"
  type        = string
  default     = "v1.0.0"
}

variable "chart_version" {
  description = "sligo-cloud Helm chart version from sligo-helm-charts (e.g. '1.2.1'). Ignored when chart_path is set."
  type        = string
  default     = "1.2.1"
}

variable "chart_path" {
  description = "Optional path to a local sligo-cloud chart .tgz. When set, uses that chart instead of the repository."
  type        = string
  default     = ""
}

variable "helm_extra_values" {
  description = "Optional extra YAML for the sligo-cloud Helm chart (merged after module defaults). See modules/azure/aks variable helm_extra_values."
  type        = string
  default     = ""
}

variable "enable_control_plane_exporter" {
  description = "Enable control-plane telemetry export; module derives GCS bucket (sligo-tfstate-{client} with -containers stripped from client_repository_name) and prefix (basename of Terraform cwd). See module variable enable_control_plane_exporter."
  type        = bool
  default     = false
}

variable "sligo_service_account_key_path" {
  description = "Path to Sligo service account key JSON file"
  type        = string
  sensitive   = true
}

# Database Configuration
variable "db_username" {
  type      = string
  default   = "sligo"
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "postgres_sku_name" {
  description = "Azure PostgreSQL Flexible Server SKU (e.g. B_Standard_B1ms, GP_Standard_D2s_v3). Not a Compute VM size."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

# Redis Configuration
variable "redis_sku_name" {
  description = "Azure Managed Redis SKU (e.g. Balanced_B0, Balanced_B1, Balanced_B3)"
  type        = string
  default     = "Balanced_B1"
}

variable "redis_high_availability_enabled" {
  description = "Whether Azure Managed Redis is deployed with high availability"
  type        = bool
  default     = true
}

# Storage Configuration
variable "use_existing_storage_account" {
  type    = bool
  default = false
}

# Secrets
variable "jwt_secret" {
  type      = string
  sensitive = true
}
variable "api_key" {
  type      = string
  sensitive = true
}

variable "backend_api_key" {
  description = "Shared API key used by the frontend to authenticate requests to the backend (min 32 characters)"
  type        = string
  sensitive   = true
}

variable "nextauth_secret" {
  type      = string
  sensitive = true
}
variable "gateway_secret" {
  type      = string
  sensitive = true
}
variable "frontend_url" {
  type = string
}
variable "next_public_api_url" {
  type = string
}
variable "workos_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "workos_client_id" {
  type    = string
  default = ""
}
variable "workos_cookie_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "auth_provider" {
  type    = string
  default = "workos"
}

variable "auth_invitations" {
  description = "Auth invitations provider (e.g. workos). Set to enable invitation flows."
  type        = string
  default     = ""
}

variable "super_admin_emails" {
  description = "Super Admin allowlist. Comma-separated emails."
  type        = string
  default     = ""
}

variable "shq_module_enabled" {
  description = "Optional. Default false."
  type        = bool
  default     = false
}

variable "auth_session_secret" {
  type      = string
  default   = ""
  sensitive = true
}
variable "oidc_issuer" {
  type    = string
  default = ""
}

variable "oidc_client_id" {
  type    = string
  default = ""
}

variable "oidc_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "oidc_scopes" {
  type    = string
  default = "openid profile email"
}

variable "oidc_default_org_id" {
  type    = string
  default = ""
}

variable "oidc_default_org_name" {
  type    = string
  default = ""
}

variable "saml_entrypoint" {
  type    = string
  default = ""
}

variable "saml_issuer" {
  type    = string
  default = ""
}

variable "saml_cert" {
  type      = string
  default   = ""
  sensitive = true
}

variable "saml_default_org_id" {
  type    = string
  default = ""
}

variable "saml_default_org_name" {
  type    = string
  default = ""
}

variable "encryption_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "next_public_google_client_id" {
  type    = string
  default = ""
}
variable "next_public_google_client_key" {
  type    = string
  default = ""
}
variable "google_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
variable "google_project_id" {
  type    = string
  default = ""
}
variable "gcp_sa_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "rag_sa_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "anthropic_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "together_ai_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "google_vertex_ai_web_credentials" {
  type      = string
  default   = ""
  sensitive = true
}
variable "verbose_logging" {
  type    = bool
  default = true
}
variable "backend_request_timeout_ms" {
  type    = number
  default = 300000
}
variable "openai_base_url" {
  type    = string
  default = "https://api.openai.com/v1"
}
variable "langsmith_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "langsmith_tracing" {
  type    = string
  default = "false"
}

variable "langsmith_project" {
  type    = string
  default = ""
}

variable "langsmith_endpoint" {
  type    = string
  default = "https://api.smith.langchain.com"
}

variable "pinecone_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "pinecone_index" {
  type    = string
  default = ""
}

variable "pinecone_environment" {
  description = "Pinecone environment (legacy SDK, optional)"
  type        = string
  default     = ""
}

variable "rag_vector_store" {
  description = "Default RAG vector store: pinecone, singlestore, or omit to default to Pinecone"
  type        = string
  default     = ""
}

variable "singlestore_host" {
  description = "SingleStore host for RAG vector store (when rag_vector_store=singlestore)"
  type        = string
  default     = ""
}

variable "singlestore_port" {
  description = "SingleStore port"
  type        = string
  default     = "3306"
}

variable "singlestore_user" {
  description = "SingleStore username for RAG"
  type        = string
  default     = ""
}

variable "singlestore_password" {
  description = "SingleStore password for RAG"
  type        = string
  default     = ""
  sensitive   = true
}

variable "singlestore_database" {
  description = "SingleStore database name for RAG"
  type        = string
  default     = ""
}

variable "auth_base_url" {
  description = "Auth base URL (fallback if NEXT_PUBLIC_URL not set)"
  type        = string
  default     = ""
}

variable "auth_cookie_name" {
  description = "Session cookie name (default: sligo_session)"
  type        = string
  default     = ""
}

variable "auth_cookie_same_site" {
  description = "Session cookie SameSite: lax (default) or none. Use 'none' for iframe embedding (requires HTTPS)."
  type        = string
  default     = ""
}

variable "release_upgrade_trigger" {
  description = "Optional value to force a Helm upgrade without changing app_version."
  type        = string
  default     = ""
}

variable "spendhq_base_url" {
  type    = string
  default = ""
}
variable "spendhq_client_id" {
  type      = string
  default   = ""
  sensitive = true
}
variable "spendhq_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
variable "spendhq_token_url" {
  type    = string
  default = ""
}
variable "spendhq_ss_host" {
  type    = string
  default = ""
}
variable "spendhq_ss_username" {
  type      = string
  default   = ""
  sensitive = true
}
variable "spendhq_ss_password" {
  type      = string
  default   = ""
  sensitive = true
}
variable "spendhq_ss_port" {
  type    = string
  default = "3306"
}

variable "create_azure_ai" {
  description = "Create an Azure OpenAI-compatible account and inject AZURE_OPENAI_* (no model deployments). Default true; set false to BYO."
  type        = bool
  default     = true
}

variable "create_azure_aisearch" {
  description = "Create Azure AI Search and inject AZURE_AISEARCH_* (app creates the index). Default true; set false to BYO."
  type        = bool
  default     = true
}

variable "azure_ai_location" {
  description = "Region for Azure AI / AI Search. Empty uses the AKS location."
  type        = string
  default     = ""
}

variable "azure_ai_public_network_access" {
  description = "Public internet access to created Azure AI / AI Search. Default false uses private endpoints (VNet only)."
  type        = bool
  default     = false
}

# Azure AI Search (optional BYO; nextjs + mcp-gateway)
variable "azure_aisearch_endpoint" {
  type    = string
  default = ""
}
variable "azure_aisearch_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "azure_aisearch_index" {
  type    = string
  default = "vectorsearch"
}
variable "azure_aisearch_query_type" {
  type    = string
  default = "similarity_hybrid"
}
# Azure OpenAI (optional BYO; nextjs + backend + mcp-gateway)
variable "azure_openai_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "azure_openai_api_instance_name" {
  type    = string
  default = ""
}
variable "azure_openai_api_version" {
  type    = string
  default = "2024-02-15-preview"
}
variable "azure_openai_base_path" {
  type    = string
  default = ""
}

# Amazon Bedrock (optional; nextjs + backend)
variable "bedrock_aws_region" {
  type        = string
  default     = ""
  description = "Bedrock source region (e.g. us-east-1)"
}
variable "bedrock_aws_bearer_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Long-term Bedrock API key (not an IAM access key)"
}

variable "storage_provider" {
  description = "Storage provider: azure, gcs, or s3. AKS defaults to azure so the app uses the provisioned Blob account. Override only for GCS or S3."
  type        = string
  default     = "azure"
}

# Postmark email (optional)
variable "postmark_server_token" {
  type      = string
  default   = ""
  sensitive = true
}

variable "email_from" {
  type    = string
  default = ""
}

variable "email_inbound_domain" {
  type    = string
  default = ""
}

variable "email_inbound_webhook_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "enable_managed_tls" {
  description = "Let's Encrypt Certificates for app-tls-cert. See module variable enable_managed_tls."
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "ACME account email. Empty defaults to letsencrypt@<domain_name>."
  type        = string
  default     = ""
}

variable "letsencrypt_server" {
  description = "Let's Encrypt ACME directory: production or staging."
  type        = string
  default     = "production"
}

variable "install_cert_manager" {
  description = "Install cert-manager when managed TLS or Langfuse needs it."
  type        = bool
  default     = true
}
