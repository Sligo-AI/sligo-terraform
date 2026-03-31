# Cluster Configuration
variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zones" {
  description = "GCP zones for the cluster"
  type        = list(string)
  default     = ["us-central1-a"]
}

variable "cluster_version" {
  description = "Kubernetes version for GKE cluster"
  type        = string
  default     = "1.28"
}

variable "node_machine_type" {
  description = "Machine type for GKE node pool (e.g. e2-medium, e2-standard-2). Use at least e2-standard-2 so Sligo pods (backend requests 1 CPU) can schedule."
  type        = string
  default     = "e2-standard-2"
}

# Existing Network (when client provides VPC/subnet)
variable "use_existing_network" {
  description = "When true, use existing VPC and subnet instead of creating new ones"
  type        = bool
  default     = false
}

variable "existing_network_name" {
  description = "Name of existing VPC network (required when use_existing_network=true)"
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of existing subnet (required when use_existing_network=true)"
  type        = string
  default     = ""
}

variable "existing_subnet_region" {
  description = "Region of existing subnet (defaults to gcp_region when empty)"
  type        = string
  default     = ""
}

variable "secondary_pod_range_name" {
  description = "Name of subnet secondary range for GKE pods (required when use_existing_network=true)"
  type        = string
  default     = "pods"
}

variable "secondary_service_range_name" {
  description = "Name of subnet secondary range for GKE services (required when use_existing_network=true)"
  type        = string
  default     = "services"
}

variable "secondary_pod_cidr" {
  description = "CIDR for the pod secondary range (required when use_existing_network=true and Terraform manages the ranges)"
  type        = string
  default     = ""
}

variable "secondary_service_cidr" {
  description = "CIDR for the service secondary range (required when use_existing_network=true and Terraform manages the ranges)"
  type        = string
  default     = ""
}

variable "enable_private_endpoint" {
  description = "When true, the cluster master is only accessible from within the VPC. Required by some org policies."
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE master's internal IP range (must be /28 and not overlap with existing ranges)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  description = "List of CIDR blocks authorized to reach the private master endpoint (required when enable_private_endpoint=true)"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "use_existing_psa" {
  description = "When true, do not create PSA resources (google_compute_global_address, google_service_networking_connection). Client provides PSA ranges. Cloud SQL and Redis will use the existing Service Networking connection."
  type        = bool
  default     = false
}

# Application Configuration
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "use_managed_ssl_certificate" {
  description = "When true, Terraform creates a GKE ManagedCertificate (Google-managed SSL) for domain_name and api.<domain_name>, and attaches it to the GCE Ingress. DNS must point to the load balancer for the cert to be issued. Set to false for HTTP-only."
  type        = bool
  default     = true
}

variable "client_repository_name" {
  description = "Client-specific GAR repository name (provided by Sligo)"
  type        = string
}

variable "app_version" {
  description = "Sligo Cloud application version tag (e.g., 'v1.0.0', 'v1.2.3'). This should match a version tag pushed to the container registry. Use 'latest' for development only."
  type        = string
  default     = "latest"
}

variable "chart_version" {
  description = "sligo-cloud Helm chart version (e.g., '1.0.1'). Chart 1.0.1+ supports extraVolumes/extraVolumeMounts for GCP credentials. Ignored when chart_path is set."
  type        = string
  default     = "1.0.1"
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

variable "super_admin_emails" {
  description = "Super Admin allowlist. Comma-separated emails. When set, user must be in this list AND have isSuperAdmin=true in DB."
  type        = string
  default     = ""
}

variable "sligo_service_account_key_path" {
  description = "Path to Sligo service account key JSON file"
  type        = string
  sensitive   = true
}

# Database Configuration
variable "db_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-f1-micro"
}

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

# Redis Configuration (in-cluster Redis Stack, always persistent)
variable "redis_persistence_size" {
  description = "PersistentVolumeClaim size for Redis Stack data"
  type        = string
  default     = "1Gi"
}

variable "redis_persistence_storage_class" {
  description = "Storage class for Redis Stack PVC (e.g. standard-rwo on GKE)"
  type        = string
  default     = "standard-rwo"
}

# GCS Storage Configuration
variable "gcs_bucket_name" {
  description = "GCS bucket name for file manager (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "gcs_bucket_agent_avatars_name" {
  description = "GCS bucket name for agent avatars (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "gcs_bucket_logos_name" {
  description = "GCS bucket name for MCP logos (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "gcs_bucket_rag_name" {
  description = "GCS bucket name for RAG storage (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "gcs_bucket_location" {
  description = "GCS bucket location"
  type        = string
  default     = "US"
}

variable "gcs_bucket_versioning" {
  description = "Enable versioning on GCS buckets"
  type        = bool
  default     = true
}

variable "use_existing_gcs_bucket" {
  description = "If true, use existing GCS buckets instead of creating new ones. Requires gcs_bucket_*_name to be set."
  type        = bool
  default     = false
}

variable "gcs_allow_public_agent_avatars_logos" {
  description = "If true, grant allUsers objectViewer on agent-avatars and logos buckets (public read). Set to false when the project has Public Access Prevention enforced; avatars/logos will need to be served via signed URLs by the app."
  type        = bool
  default     = false
}

variable "use_existing_agent_avatars_bucket" {
  description = "If true, use an existing external bucket for agent avatars (e.g. your own public bucket). Set gcs_bucket_agent_avatars_name to the bucket name. No bucket or IAM is created for agent avatars."
  type        = bool
  default     = false
}

variable "enable_external_secrets_operator" {
  description = "When true, install External Secrets Operator and provision GCP Secret Manager placeholders for app secrets."
  type        = bool
  default     = false
}

variable "use_eso_managed_app_secrets" {
  description = "When true, app/backend/mcp Kubernetes secrets are sourced from External Secrets instead of Terraform plaintext kubernetes_secret resources."
  type        = bool
  default     = false
}

variable "secret_names" {
  description = "Base secret names (without prefix). Full GSM secret IDs are computed as <secret_name_prefix><name>."
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
    "backend-api-key",
    "gateway-secret"
  ]
}

variable "secret_manager_project_id" {
  description = "Project ID hosting GSM secrets for this deployment. Defaults to Sligo shared platform project."
  type        = string
  default     = "sligo-ai-platform"
}

variable "secret_name_prefix" {
  description = "Prefix applied to all secret_names to isolate by client/environment (for example sligo-qxo-staging-). Leave empty to auto-derive from cluster_name."
  type        = string
  default     = ""
}

variable "create_secret_placeholders" {
  description = "When true, create missing GSM secret placeholders in secret_manager_project_id. Keep false when secrets are centrally pre-provisioned."
  type        = bool
  default     = false
}

variable "gcs_bucket_agent_avatars_project" {
  description = "When use_existing_agent_avatars_bucket is true and the bucket lives in a different GCP project, set this to that project ID. Passed to the app so it can target the correct project for that bucket (e.g. for SDK calls or signed URLs). Leave empty if the bucket is in the same project as the cluster."
  type        = string
  default     = ""
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
  description = "Shared API key used by the frontend to authenticate requests to the backend (required, must not be empty)"
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

# Additional secrets (optional - same as AWS EKS)
variable "workos_api_key" {
  description = "WorkOS API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "workos_client_id" {
  description = "WorkOS Client ID"
  type        = string
  default     = ""
}

variable "workos_cookie_password" {
  description = "WorkOS Cookie Password"
  type        = string
  default     = ""
  sensitive   = true
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
  description = "OIDC scopes (when auth_provider=oidc). Default: openid profile email"
  type        = string
  default     = "openid profile email"
}

variable "oidc_default_org_id" {
  description = "OIDC default organization ID (optional)"
  type        = string
  default     = ""
}

variable "oidc_default_org_name" {
  description = "OIDC default organization name (optional)"
  type        = string
  default     = ""
}

variable "saml_entrypoint" {
  description = "SAML IdP SSO URL (when auth_provider=saml)"
  type        = string
  default     = ""
}

variable "saml_issuer" {
  description = "SAML SP entity ID / issuer (when auth_provider=saml)"
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
  description = "SAML default organization ID (optional)"
  type        = string
  default     = ""
}

variable "saml_default_org_name" {
  description = "SAML default organization name (optional)"
  type        = string
  default     = ""
}

variable "encryption_key" {
  description = "Encryption key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "next_public_google_client_id" {
  description = "Google OAuth Client ID (public)"
  type        = string
  default     = ""
}

variable "next_public_google_client_key" {
  description = "Google OAuth Client Key (public)"
  type        = string
  default     = ""
}

variable "next_public_onedrive_client_id" {
  description = "OneDrive OAuth Client ID (public)"
  type        = string
  default     = ""
}

variable "pinecone_api_key" {
  description = "Pinecone API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pinecone_index" {
  description = "Pinecone index name"
  type        = string
  default     = ""
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
  description = "SQL connection string decryption IV"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sql_connection_string_decryption_key" {
  description = "SQL connection string decryption key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_project_id" {
  description = "Google Cloud Project ID (for AI features, may differ from gcp_project_id)"
  type        = string
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "perplexity_api_key" {
  description = "Perplexity API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tavily_api_key" {
  description = "Tavily API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "storage_provider" {
  description = "Storage provider: gcs or s3 (optional; app defaults to gcs when unset)"
  type        = string
  default     = ""
}

variable "gcp_sa_key" {
  description = "GCP Service Account Key (JSON)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rag_sa_key" {
  description = "RAG Service Account Key (JSON string)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_vertex_ai_web_credentials" {
  description = "Google Vertex AI Web Credentials (JSON string)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "verbose_logging" {
  description = "Enable verbose logging for backend"
  type        = bool
  default     = true
}

variable "backend_request_timeout_ms" {
  description = "Backend request timeout in milliseconds"
  type        = number
  default     = 300000
}

variable "openai_base_url" {
  description = "OpenAI API base URL"
  type        = string
  default     = "https://api.openai.com/v1"
}

variable "langsmith_api_key" {
  description = "LangSmith API key"
  type        = string
  default     = ""
  sensitive   = true
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

variable "onedrive_client_secret" {
  description = "OneDrive OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

# Azure AI Search (optional; for nextjs + mcp-gateway when using RAG vector store azureaisearch)
variable "azure_aisearch_endpoint" {
  description = "Azure AI Search endpoint URL (e.g. https://your-service.search.windows.net)"
  type        = string
  default     = ""
}

variable "azure_aisearch_key" {
  description = "Azure AI Search admin key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_aisearch_index" {
  description = "Azure AI Search index name (optional, default: vectorsearch)"
  type        = string
  default     = "vectorsearch"
}

variable "azure_aisearch_query_type" {
  description = "Azure AI Search query type (optional: similarity, similarity_hybrid, semantic_hybrid)"
  type        = string
  default     = "similarity_hybrid"
}

# Azure OpenAI (optional; for backend)
variable "azure_openai_api_key" {
  description = "Azure OpenAI API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_openai_api_instance_name" {
  description = "Azure OpenAI instance/deployment name"
  type        = string
  default     = ""
}

variable "azure_openai_api_version" {
  description = "Azure OpenAI API version (e.g. 2024-02-15-preview)"
  type        = string
  default     = "2024-02-15-preview"
}

variable "azure_openai_base_path" {
  description = "Azure OpenAI base path (e.g. https://your-resource.openai.azure.com/openai/deployments/your-deployment)"
  type        = string
  default     = ""
}

# SPENDHQ Configuration (for mcp-gateway)
variable "spendhq_base_url" {
  description = "SPENDHQ base URL"
  type        = string
  default     = ""
}

variable "spendhq_client_id" {
  description = "SPENDHQ client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "spendhq_client_secret" {
  description = "SPENDHQ client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "spendhq_token_url" {
  description = "SPENDHQ token URL"
  type        = string
  default     = ""
}

variable "spendhq_ss_host" {
  description = "SPENDHQ SingleStore host"
  type        = string
  default     = ""
}

variable "spendhq_ss_username" {
  description = "SPENDHQ SingleStore username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "spendhq_ss_password" {
  description = "SPENDHQ SingleStore password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "spendhq_ss_port" {
  description = "SPENDHQ SingleStore port"
  type        = string
  default     = "3306"
}
