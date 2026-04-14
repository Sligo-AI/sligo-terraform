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
  default     = "1.0.0"
}

variable "helm_extra_values" {
  description = "Optional extra YAML for the sligo-cloud Helm chart (merged after module defaults). See modules/gcp/gke variable helm_extra_values."
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
variable "use_existing_gcs_bucket" {
  description = "If true, use existing GCS buckets instead of creating new ones"
  type        = bool
  default     = false
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

variable "super_admin_emails" {
  description = "Super Admin allowlist. Comma-separated emails."
  type        = string
  default     = ""
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

# Azure AI Search (optional; nextjs + mcp-gateway)
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
# Azure OpenAI (optional; backend)
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
