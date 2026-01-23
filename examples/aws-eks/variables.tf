# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Application Configuration
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS (optional, leave empty to use HTTP only). If not provided, a certificate will be created automatically."
  type        = string
  default     = ""
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

variable "sligo_service_account_key_path" {
  description = "Path to Sligo service account key JSON file"
  type        = string
  sensitive   = true
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
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

variable "prisma_accelerate_url" {
  description = "Prisma Accelerate connection URL (format: prisma://accelerate.prisma-data.net/?api_key=...) or prisma+postgres://..."
  type        = string
  default     = ""
  sensitive   = true
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
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
  description = "Encryption key - must be 64 hex characters (32 bytes) for AES-256"
  type        = string
  default     = ""
  sensitive   = true
}

# Google Cloud Configuration
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

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_project_id" {
  description = "Google Cloud Project ID"
  type        = string
  default     = ""
}

variable "google_api_key" {
  description = "Google API Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_storage_bucket" {
  description = "Google Storage bucket name"
  type        = string
  default     = ""
}

variable "google_storage_agent_avatars_bucket" {
  description = "Google Storage bucket for agent avatars"
  type        = string
  default     = ""
}

variable "google_storage_mcp_logos_bucket" {
  description = "Google Storage bucket for MCP logos"
  type        = string
  default     = ""
}

variable "google_storage_rag_sa_key" {
  description = "Google Storage RAG Service Account Key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "file_manager_google_projectid" {
  description = "File Manager Google Project ID"
  type        = string
  default     = ""
}

# Pinecone Configuration
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

# S3 Storage Configuration (optional)
variable "s3_bucket_name" {
  description = "S3 bucket name for application storage (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "s3_bucket_versioning" {
  description = "Enable versioning on S3 bucket"
  type        = bool
  default     = true
}

variable "s3_bucket_encryption" {
  description = "Enable encryption on S3 bucket"
  type        = bool
  default     = true
}

variable "use_existing_s3_bucket" {
  description = "If true, use an existing S3 bucket instead of creating a new one. Requires s3_bucket_name to be set."
  type        = bool
  default     = false
}
