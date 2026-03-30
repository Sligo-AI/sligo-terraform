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
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

# Redis Configuration
variable "redis_sku_name" {
  type    = string
  default = "Standard"
}

variable "redis_family" {
  type    = string
  default = "C"
}

variable "redis_capacity" {
  type    = number
  default = 1
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

variable "storage_provider" {
  description = "Storage provider: gcs or s3 (optional; app defaults to gcs when unset)"
  type        = string
  default     = ""
}
