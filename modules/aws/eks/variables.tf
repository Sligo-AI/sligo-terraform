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

# When non-empty, these IAM principals receive AmazonEKSClusterAdminPolicy (cluster scope) via EKS access entries,
# and enable_cluster_creator_admin_permissions is turned off so apply identity (e.g. GitHub OIDC) no longer replaces
# the cluster_creator entry. Principals not listed here are unchanged; console-created access entries stay unless you
# import them into Terraform.
variable "eks_cluster_admin_principal_arns" {
  description = "IAM role/user ARNs that should always have cluster-admin access via EKS access entries (SSO admin, CI role, etc.). Leave empty to keep legacy behavior: cluster_creator tracks whoever runs Terraform."
  type        = list(string)
  default     = []
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

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for the application domain (e.g. sligo.ai). When set, Terraform will create ACM DNS validation records and optionally CNAME records for the app and api subdomain pointing to the ALB. Leave empty to manage DNS manually."
  type        = string
  default     = ""
}

variable "alb_hostname" {
  description = "ALB hostname for app DNS (e.g. k8s-sligo-xxxx.elb.us-east-1.amazonaws.com). When set with route53_zone_id, Terraform creates CNAME records for domain_name and api.<domain_name> pointing to this hostname. Get the value after first apply with: kubectl get ingress -n sligo -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
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
  description = "Optional value to force a Helm upgrade (runs release-setup job: Prisma migrate, sync). Change this (e.g. timestamp or increment) and apply to trigger the pre-upgrade job without changing app_version."
  type        = string
  default     = ""
}

variable "helm_extra_values" {
  description = "Additional YAML merged into the sligo-cloud Helm release after module-rendered values (Helm: later values override earlier). Use for chart keys not modeled as module variables; do not put secrets here—use Kubernetes secrets or External Secrets."
  type        = string
  default     = ""
}

variable "enable_control_plane_exporter" {
  description = "When true, Helm enables controlPlaneExporter (GCS telemetry). Bucket is sligo-tfstate-{client} where client is client_repository_name with suffix -containers removed; GCS prefix is basename(path.cwd) from the Terraform working directory."
  type        = bool
  default     = false
}

variable "sligo_service_account_key_path" {
  description = "Path to Sligo service account key JSON file"
  type        = string
  sensitive   = true
}

variable "enable_external_secrets_operator" {
  description = "When true, install External Secrets Operator and a ClusterSecretStore for Google Secret Manager in secret_manager_project_id (auth uses the same JSON key file as GAR)."
  type        = bool
  default     = false
}

variable "use_eso_managed_app_secrets" {
  description = "When true, app/backend/mcp secrets are synced from GSM via External Secrets instead of Terraform kubernetes_secret resources. Requires enable_external_secrets_operator."
  type        = bool
  default     = false
}

variable "secret_names" {
  description = "Base secret names (without prefix). Full GSM secret IDs are computed as secret_name_prefix plus name."
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
    "together-ai-api-key",
    "backend-api-key",
    "gateway-secret",
    "mdi-gcp-key",
    "langsmith-api-key",
    "langsmith-project",
    "langsmith-tracing",
    "langsmith-endpoint"
  ]
}

variable "secret_manager_project_id" {
  description = "GCP project ID hosting GSM secrets (central platform project)."
  type        = string
  default     = "sligo-ai-platform"
}

variable "secret_name_prefix" {
  description = "Prefix for GSM secret IDs to isolate by client or environment. Leave empty to derive from cluster_name."
  type        = string
  default     = ""
}

variable "create_secret_placeholders" {
  description = "When true, the GCP GKE module can create GSM secret placeholders in secret_manager_project_id. EKS does not create GSM resources; use sligo-onboarding or manual provisioning in GCP."
  type        = bool
  default     = false
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

variable "backend_api_key" {
  description = "Shared API key used by the frontend to authenticate requests to the backend (required, must not be empty)"
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

variable "auth_invitations" {
  description = "Auth invitations provider (e.g. workos, oidc). Set to enable invitation flows."
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

variable "together_ai_api_key" {
  description = "Together AI API key"
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

variable "node_env" {
  description = "NODE_ENV for app and backend (e.g. development, production)"
  type        = string
  default     = "production"
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

variable "super_admin_emails" {
  description = "Super Admin allowlist. Comma-separated emails. When set, user must be in this list AND have isSuperAdmin=true in DB."
  type        = string
  default     = ""
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

# Networking (Optional - can use existing VPC)
variable "vpc_id" {
  description = "VPC ID (optional, will create if not provided)"
  type        = string
  default     = ""
}

# When true, Terraform creates security group rules allowing ALB to reach app/backend/mcp-gateway pods.
# Count must be known at plan time; the ALB SG is created by the LB controller after first apply, so
# these rules are optional (controller also manages access). Set to true only if you need them and run
# apply twice (second apply creates the rules after ALB SG exists).
variable "create_alb_sg_rules" {
  description = "Create security group rules for ALB to reach pods (default false; AWS LB controller manages access). Set true and run apply twice if you need these rules."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Subnet IDs (optional, will create if not provided)"
  type        = list(string)
  default     = []
}

# Storage provider: gcs or s3 (optional; app defaults to gcs when unset)
variable "storage_provider" {
  description = "Storage provider: gcs or s3 (optional; app defaults to gcs when unset)"
  type        = string
  default     = ""
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
