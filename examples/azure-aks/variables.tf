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
