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

variable "sligo_service_account_key_path" {
  description = "Path to Sligo service account key JSON file"
  type        = string
  sensitive   = true
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

# Redis Configuration (Azure Cache for Redis)
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
variable "onedrive_client_secret" {
  type      = string
  default   = ""
  sensitive = true
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
