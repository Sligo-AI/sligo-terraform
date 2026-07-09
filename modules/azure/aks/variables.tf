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
  description = "Name of the Azure resource group (will create if empty)"
  type        = string
  default     = ""
}

# Node Pool Configuration
variable "node_pool_min_count" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "node_pool_max_count" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 4
}

variable "node_pool_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
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
  description = "Sligo Cloud application version tag"
  type        = string
  default     = "latest"
}

variable "helm_extra_values" {
  description = "Additional YAML merged into the sligo-cloud Helm release after module-rendered values (Helm: later values override earlier). Use for chart keys not modeled as module variables; do not put secrets here—use Kubernetes secrets or External Secrets."
  type        = string
  default     = ""
}

variable "enable_control_plane_exporter" {
  description = "When true, Helm enables controlPlaneExporter (GCS telemetry). Bucket is sligo-tfstate-{client} where client is client_repository_name with suffix -containers removed; GCS prefix is basename(path.cwd) from the Terraform working directory."
  type        = bool
  default     = false
}

variable "sligo_service_account_key_path" {
  description = "Path to Sligo service account key JSON file"
  type        = string
  sensitive   = true
}

variable "enable_external_secrets_operator" {
  description = "When true, install External Secrets Operator and a ClusterSecretStore for Google Secret Manager in secret_manager_project_id (auth uses the same JSON key file as GAR)."
  type        = bool
  default     = false
}

variable "use_eso_managed_app_secrets" {
  description = "When true, app/backend/mcp secrets are synced from GSM via External Secrets instead of Terraform kubernetes_secret resources. Requires enable_external_secrets_operator."
  type        = bool
  default     = false
}

variable "secret_names" {
  description = "Base secret names (without prefix). Full GSM secret IDs are computed as secret_name_prefix plus name."
  type        = list(string)
  default = [
    "db-password",
    "jwt-secret",
    "api-key",
    "nextauth-secret",
    "encryption-key",
    "workos-api-key",
    "openai-api-key",
    "anthropic-api-key",
    "together-ai-api-key",
    "backend-api-key",
    "gateway-secret",
    "mdi-gcp-key",
    "langsmith-api-key",
    "langsmith-project",
    "langsmith-tracing",
    "langsmith-endpoint",
    "langfuse-base-url",
    "langfuse-public-key",
    "langfuse-secret-key",
    "langsmith-api-base-url",
    "observability-provider"
  ]
}

variable "secret_manager_project_id" {
  description = "GCP project ID hosting GSM secrets (central platform project)."
  type        = string
  default     = "sligo-ai-platform"
}

variable "secret_name_prefix" {
  description = "Prefix for GSM secret IDs to isolate by client or environment. Leave empty to derive from cluster_name."
  type        = string
  default     = ""
}

variable "create_secret_placeholders" {
  description = "When true, the GCP GKE module can create GSM secret placeholders in secret_manager_project_id. AKS does not create GSM resources; use sligo-onboarding or manual provisioning in GCP."
  type        = bool
  default     = false
}

# Database Configuration (Azure Database for PostgreSQL Flexible Server)
variable "db_username" {
  description = "Database username"
  type        = string
  default     = "sligo"
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "enable_temporal" {
  description = "Provision Temporal Postgres databases, secrets, and Helm values for self-hosted Temporal."
  type        = bool
  default     = false
}

variable "temporal_namespace" {
  description = "Temporal namespace name (logical, not Kubernetes)."
  type        = string
  default     = "sligo-prod"
}

variable "temporal_task_queue" {
  description = "Temporal task queue polled by sligo-temporal-worker."
  type        = string
  default     = "sligo-workflows"
}

variable "temporal_history_shard_count" {
  description = "Temporal history shard count. Immutable after first deploy."
  type        = number
  default     = 512
}

variable "temporal_db_name" {
  description = "Postgres database name for Temporal default store."
  type        = string
  default     = "temporal"
}

variable "temporal_visibility_db_name" {
  description = "Postgres database name for Temporal visibility store."
  type        = string
  default     = "temporal_visibility"
}

variable "temporal_db_username" {
  description = "Postgres user for Temporal databases. Empty reuses db_username."
  type        = string
  default     = ""
  sensitive   = true
}

variable "temporal_db_password" {
  description = "Postgres password for Temporal databases. Empty reuses db_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "temporal_web_enabled" {
  description = "Deploy Temporal Web UI (ClusterIP; Super Admin access via sligo-app proxy)."
  type        = bool
  default     = true
}

variable "postgres_sku_name" {
  description = "Azure PostgreSQL Flexible Server SKU (e.g., B_Standard_B1ms, GP_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

# Redis Configuration
# When redis_url is set (e.g. Redis Cloud), Azure Cache for Redis is not provisioned.
variable "redis_url" {
  description = "External Redis connection URL (e.g. Redis Cloud rediss://...). When non-empty, app secrets use this URL and Helm does not deploy Redis; Azure Cache for Redis is not created."
  type        = string
  default     = ""
  sensitive   = true
}

# Azure Cache for Redis (only when redis_url is empty)
variable "redis_sku_name" {
  description = "Azure Cache for Redis SKU (Basic, Standard, or Premium)"
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis SKU family (C or P)"
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis capacity (0-6 for C family, 1-5 for P family)"
  type        = number
  default     = 1
}

# Blob Storage Configuration
variable "storage_account_name" {
  description = "Azure Storage account name (optional, will create if empty)"
  type        = string
  default     = ""
}

variable "use_existing_storage_account" {
  description = "If true, use existing storage account. Requires storage_account_name and azure_storage_account_key."
  type        = bool
  default     = false
}

variable "azure_storage_account_key" {
  description = "Storage account key (required when use_existing_storage_account is true)"
  type        = string
  default     = ""
  sensitive   = true
}

# Secrets (same structure as AWS/GCP)
variable "jwt_secret" {
  description = "JWT secret for backend"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "API key"
  type        = string
  sensitive   = true
}

variable "nextauth_secret" {
  description = "NextAuth secret"
  type        = string
  sensitive   = true
}

variable "gateway_secret" {
  description = "MCP Gateway secret"
  type        = string
  sensitive   = true
}

variable "frontend_url" {
  description = "Frontend URL"
  type        = string
}

variable "next_public_api_url" {
  description = "Public API URL"
  type        = string
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
  description = "Auth provider: workos (default), oidc, or saml"
  type        = string
  default     = "workos"
}

variable "auth_session_secret" {
  description = "Session signing secret for OIDC/SAML (min 32 chars). Required when auth_provider is oidc or saml."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oidc_issuer" {
  description = "OIDC issuer URL (when auth_provider=oidc)"
  type        = string
  default     = ""
}

variable "oidc_client_id" {
  description = "OIDC client ID (when auth_provider=oidc)"
  type        = string
  default     = ""
}

variable "oidc_client_secret" {
  description = "OIDC client secret (when auth_provider=oidc)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oidc_scopes" {
  description = "OIDC scopes (when auth_provider=oidc)"
  type        = string
  default     = "openid profile email"
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
  description = "SAML IdP SSO URL (when auth_provider=saml)"
  type        = string
  default     = ""
}

variable "saml_issuer" {
  description = "SAML SP entity ID (when auth_provider=saml)"
  type        = string
  default     = ""
}

variable "saml_cert" {
  description = "SAML IdP certificate PEM (when auth_provider=saml)"
  type        = string
  default     = ""
  sensitive   = true
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
variable "next_public_onedrive_client_id" {
  type    = string
  default = ""
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
variable "sql_connection_string_decryption_iv" {
  type      = string
  default   = ""
  sensitive = true
}
variable "sql_connection_string_decryption_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "google_project_id" {
  type    = string
  default = ""
}
variable "openai_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "perplexity_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "tavily_api_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "storage_provider" {
  description = "Storage provider: gcs or s3 (optional; app defaults to gcs when unset)"
  type        = string
  default     = ""
}
variable "gcp_sa_key" {
  type      = string
  default   = ""
  sensitive = true
}
variable "google_client_secret" {
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
  description = "Enable LangSmith tracing (true/false)"
  type        = string
  default     = "false"
}

variable "langsmith_project" {
  description = "LangSmith project name for traces"
  type        = string
  default     = ""
}

variable "langsmith_endpoint" {
  description = "LangSmith API endpoint URL"
  type        = string
  default     = "https://api.smith.langchain.com"
}

variable "langfuse_base_url" {
  description = "Langfuse base URL"
  type        = string
  default     = ""
}

variable "langfuse_public_key" {
  description = "Langfuse public key"
  type        = string
  default     = ""
}

variable "langfuse_secret_key" {
  description = "Langfuse secret key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "langsmith_api_base_url" {
  description = "LangSmith API base URL"
  type        = string
  default     = ""
}

variable "observability_provider" {
  description = "Observability provider"
  type        = string
  default     = ""
}

variable "onedrive_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
# Azure AI Search (optional; for nextjs + mcp-gateway when using RAG vector store azureaisearch)
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
# Azure OpenAI (optional; for backend)
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
