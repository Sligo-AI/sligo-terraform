# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"
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

# Database Configuration (Aurora Serverless v2)
variable "db_username" {
  description = "Database username"
  type        = string
  default     = "sligo"
  sensitive   = true
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity in ACU (Aurora Capacity Units). 0.5 ACU = 1 GB RAM, 2 vCPU"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity in ACU (Aurora Capacity Units). 0.5 ACU = 1 GB RAM, 2 vCPU"
  type        = number
  default     = 16
}

variable "aurora_instance_class" {
  description = "Aurora Serverless v2 cluster instance class (e.g., db.r6g.large, db.r6g.xlarge). Scaling is controlled by aurora_min_capacity/aurora_max_capacity."
  type        = string
  default     = "db.r6g.large"
}

variable "db_password" {
  description = "Database password"
  type        = string
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
