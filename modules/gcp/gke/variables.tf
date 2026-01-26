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
  description = "GCS bucket name for application storage (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "gcs_bucket_location" {
  description = "GCS bucket location"
  type        = string
  default     = "US"
}

variable "gcs_bucket_versioning" {
  description = "Enable versioning on GCS bucket"
  type        = bool
  default     = true
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
