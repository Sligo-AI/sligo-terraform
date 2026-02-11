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

# Node Group Configuration
variable "node_group_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 4
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the EKS node group. Should be >= 3 for zero-downtime rolling updates with current resource requests."
  type        = number
  default     = 3
}

variable "node_group_instance_types" {
  description = "EC2 instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

# Application Configuration
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS (optional, leave empty to use HTTP only)"
  type        = string
  default     = ""
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

# Database Configuration (Aurora Serverless v2)
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

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

# S3 Storage Configuration
variable "s3_bucket_name" {
  description = "S3 bucket name for file manager storage (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "s3_bucket_agent_avatars_name" {
  description = "S3 bucket name for agent avatars (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "s3_bucket_logos_name" {
  description = "S3 bucket name for MCP logos (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "s3_bucket_rag_name" {
  description = "S3 bucket name for RAG storage (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "s3_bucket_versioning" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}

variable "s3_bucket_encryption" {
  description = "Enable encryption on S3 buckets"
  type        = bool
  default     = true
}

variable "use_existing_s3_bucket" {
  description = "If true, use existing S3 buckets instead of creating new ones. Requires s3_bucket_*_name to be set."
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

# Additional secrets (optional - provide via terraform.tfvars if needed)
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
  sensitive   = true
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

variable "encryption_key" {
  description = "Encryption key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_project_id" {
  description = "Google Cloud Project ID"
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

# Networking (Optional - can use existing VPC)
variable "vpc_id" {
  description = "VPC ID (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs (optional, will create if not provided)"
  type        = list(string)
  default     = []
}

# AWS S3 credentials (optional – omit when using IRSA / pod IAM roles)
variable "aws_access_key_id" {
  description = "AWS access key for S3 (optional; use IRSA when empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret key for S3 (optional; use IRSA when empty)"
  type        = string
  default     = ""
  sensitive   = true
}
