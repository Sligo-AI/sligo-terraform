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

variable "cluster_log_retention_days" {
  description = "Days to retain AKS logs in Log Analytics (control plane and container stdout/stderr). Default 400 (~1 year). Use a shorter value (for example 30 or 90) in staging and development. Azure requires 30–730."
  type        = number
  default     = 400
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

variable "chart_version" {
  description = "sligo-cloud Helm chart version (e.g., '1.2.1'). Chart 1.2.1+ enables LiteParse by default; this module pins its image to the client GAR. Ignored when chart_path is set."
  type        = string
  default     = "1.2.1"
}

variable "chart_path" {
  description = "Optional path to local sligo-cloud chart .tgz file. When set, uses local chart instead of repository."
  type        = string
  default     = ""
}

variable "release_upgrade_trigger" {
  description = "Optional value to force a Helm upgrade (runs release-setup pre-upgrade job: Prisma migrate, sync). Change this (e.g. timestamp or increment) and apply to trigger the hook and pod restarts without changing app_version."
  type        = string
  default     = ""
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
    "langfuse-ui-url",
    "langfuse-init-user-email",
    "langfuse-init-user-password",
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
  description = "Enable Temporal clients (app/backend/mcp) and the sligo-temporal-worker Deployment. Pair with temporal_self_hosted for in-cluster server, or temporal_self_hosted=false for Temporal Cloud."
  type        = bool
  default     = false
}

variable "temporal_self_hosted" {
  description = "When enable_temporal is true, install the official Temporal server subchart and provision Postgres DBs. Set false to use Temporal Cloud (or another external Temporal Service)."
  type        = bool
  default     = true
}

variable "temporal_frontend_address" {
  description = "Temporal frontend host:port for Temporal Cloud / external mode (e.g. namespace.account.tmprl.cloud:7233). Ignored when temporal_self_hosted is true (uses temporal-frontend:7233)."
  type        = string
  default     = ""
}

variable "temporal_api_key" {
  description = "Temporal Cloud API key. Required when enable_temporal=true and temporal_self_hosted=false. Injected into nextjs/backend/mcp-gateway secrets (worker reuses backend-secrets)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "temporal_tls" {
  description = "Override TEMPORAL_TLS for clients (\"true\" or \"false\"). Empty = false for self-hosted, true for Temporal Cloud / external."
  type        = string
  default     = ""
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
  description = "Temporal history shard count. Immutable after first deploy. Only used when temporal_self_hosted is true."
  type        = number
  default     = 512
}

variable "temporal_db_name" {
  description = "Postgres database name for Temporal default store. Only used when temporal_self_hosted is true."
  type        = string
  default     = "temporal"
}

variable "temporal_visibility_db_name" {
  description = "Postgres database name for Temporal visibility store. Only used when temporal_self_hosted is true."
  type        = string
  default     = "temporal_visibility"
}

variable "temporal_db_username" {
  description = "Postgres user for Temporal databases. Empty reuses db_username. Only used when temporal_self_hosted is true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "temporal_db_password" {
  description = "Postgres password for Temporal databases. Empty reuses db_password. Only used when temporal_self_hosted is true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "temporal_web_enabled" {
  description = "Deploy Temporal Web UI (ClusterIP; Super Admin access via sligo-app proxy). Only applies when temporal_self_hosted is true."
  type        = bool
  default     = true
}

# Proactive Insights
variable "enable_proactive_insights" {
  description = "Enable Proactive Insights (sets PROACTIVE_INSIGHTS_ENABLED on app pods and adds SPENDHQ_SS_* to backend-secrets for the Temporal worker). Requires enable_temporal and the spendhq_ss_* SingleStore credentials."
  type        = bool
  default     = false
}

check "proactive_insights_config" {
  assert {
    condition = (
      !var.enable_proactive_insights ||
      (var.enable_temporal && var.spendhq_ss_host != "" && var.spendhq_ss_username != "" && var.spendhq_ss_password != "")
    )
    error_message = "When enable_proactive_insights=true, set enable_temporal=true (PI runs on the Temporal worker) and provide spendhq_ss_host, spendhq_ss_username, and spendhq_ss_password."
  }
}

variable "postgres_sku_name" {
  description = "Azure PostgreSQL Flexible Server SKU name (e.g. B_Standard_B1ms, B_Standard_B4ms, GP_Standard_D2s_v3). Must be a Flexible Server SKU, not a Compute VM size."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

variable "db_backup_retention_days" {
  description = "Days of automated PostgreSQL backups to retain. Default 7. Azure Flexible Server requires 7–35. Staging can keep the default; production can raise it up to 35."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "When true, a CanNotDelete lock is applied to the PostgreSQL Flexible Server. Default true. Set false in staging and development so terraform destroy can run in one step."
  type        = bool
  default     = true
}

# Redis Configuration
# When redis_url is set (e.g. Redis Cloud), Azure Managed Redis is not provisioned.
variable "redis_url" {
  description = "External Redis connection URL (e.g. Redis Cloud rediss://...). When non-empty, app secrets use this URL and Helm does not deploy Redis; Azure Managed Redis is not created."
  type        = string
  default     = ""
  sensitive   = true
}

# Azure Managed Redis (only when redis_url is empty)
variable "redis_sku_name" {
  description = "Azure Managed Redis SKU (e.g. Balanced_B0, Balanced_B1, Balanced_B3)"
  type        = string
  default     = "Balanced_B1"
}

variable "redis_high_availability_enabled" {
  description = "Whether Azure Managed Redis is deployed with high availability (primary + replica). Disable only for cheap sandbox/dev."
  type        = bool
  default     = true
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

# Secrets
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

variable "backend_api_key" {
  description = "Shared API key used by the frontend to authenticate requests to the backend (required, must not be empty; min 32 characters)"
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

variable "auth_invitations" {
  description = "Auth invitations provider (e.g. workos). Set to enable invitation flows."
  type        = string
  default     = ""
}

variable "super_admin_emails" {
  description = "Super Admin allowlist. Comma-separated emails. When set, user must be in this list AND have isSuperAdmin=true in DB."
  type        = string
  default     = ""
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

variable "auth_cookie_same_site" {
  description = "Session cookie SameSite: lax (default) or none. Use 'none' for iframe embedding (requires HTTPS)."
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
  description = "Observability provider (langsmith or langfuse). Self-hosted Langfuse forces langfuse."
  type        = string
  default     = "langsmith"
}

variable "enable_langfuse" {
  description = "Enable Langfuse as the observability backend (secrets + Helm injection). Pair with langfuse_self_hosted for in-cluster Langfuse, or false for Langfuse Cloud / BYO URL."
  type        = bool
  default     = false
}

variable "langfuse_self_hosted" {
  description = "When enable_langfuse is true, install the official Langfuse Helm subchart and provision Postgres DB, blob container, and ClickHouse/Valkey."
  type        = bool
  default     = true
}

variable "langfuse_web_enabled" {
  description = "Expose Langfuse UI on langfuse_domain_name and set LANGFUSE_UI_URL for the Super Admin launch page."
  type        = bool
  default     = true
}

variable "langfuse_domain_name" {
  description = "Public hostname for the Langfuse UI. Empty defaults to langfuse.<domain_name>."
  type        = string
  default     = ""
}

variable "langfuse_db_name" {
  description = "Postgres database name for Langfuse."
  type        = string
  default     = "langfuse"
}

variable "langfuse_db_username" {
  description = "Postgres user for Langfuse. Empty reuses db_username."
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_db_password" {
  description = "Postgres password for Langfuse. Empty reuses db_password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "langfuse_init_user_email" {
  description = "Langfuse UI admin email. Empty defaults to langfuse-admin@<domain_name>."
  type        = string
  default     = ""
}

variable "langfuse_init_org_id" {
  description = "LANGFUSE_INIT_ORG_ID for first-boot org/project."
  type        = string
  default     = "sligo"
}

variable "langfuse_init_project_id" {
  description = "LANGFUSE_INIT_PROJECT_ID for first-boot project."
  type        = string
  default     = "sligo"
}

variable "install_cert_manager" {
  description = "Install cert-manager when Langfuse is self-hosted. Set false if cert-manager already exists."
  type        = bool
  default     = true
}

variable "install_clickhouse_operator" {
  description = "Install the ClickHouse operator when Langfuse is self-hosted."
  type        = bool
  default     = true
}

variable "langfuse_clickhouse_replicas" {
  description = "ClickHouse server replicas. 1 for staging; 3 for production."
  type        = number
  default     = 1
}

variable "langfuse_keeper_replicas" {
  description = "ClickHouse Keeper replicas. Must be odd."
  type        = number
  default     = 1
}

variable "langfuse_storage_class" {
  description = "StorageClass for Langfuse ClickHouse, Keeper, and Valkey PVCs."
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
# Amazon Bedrock (optional; nextjs + backend; temporal-worker reuses backend-secrets)
variable "bedrock_aws_region" {
  type        = string
  default     = ""
  description = "Bedrock source region (e.g. us-east-1). Injected when bedrock_aws_bearer_token is set."
}
variable "bedrock_aws_bearer_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Long-term Bedrock API key (not an IAM access key)."
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

# Postmark email
variable "postmark_server_token" {
  description = "Postmark server token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "email_from" {
  description = "Default verified sender address"
  type        = string
  default     = ""
}

variable "email_inbound_domain" {
  description = "Domain used for inbound email replies"
  type        = string
  default     = ""
}

variable "email_inbound_webhook_secret" {
  description = "Shared secret used to authenticate inbound email webhooks"
  type        = string
  default     = ""
  sensitive   = true
}
