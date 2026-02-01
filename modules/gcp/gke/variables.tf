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
  description = "Sligo Cloud application version tag (e.g., 'v1.0.0', 'v1.2.3'). This should match a version tag pushed to the container registry. Use 'latest' for development only."
  type        = string
  default     = "latest"
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

# Redis Configuration
variable "redis_memory_size_gb" {
  description = "Memorystore Redis memory size in GB"
  type        = number
  default     = 1
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

variable "onedrive_client_secret" {
  description = "OneDrive OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
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
