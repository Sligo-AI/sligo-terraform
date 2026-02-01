# Provider Configuration
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "redis.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com"
  ])

  project = var.gcp_project_id
  service = each.value

  disable_on_destroy = false
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.required_apis]
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.gcp_region
  project  = var.gcp_project_id

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Enable network policy
  network_policy {
    enabled = true
  }

  # Enable vertical pod autoscaling
  vertical_pod_autoscaling {
    enabled = true
  }

  depends_on = [
    google_project_service.required_apis,
    google_compute_subnetwork.subnet
  ]
}

# Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.primary.name
  project    = var.gcp_project_id
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "e2-medium"

    # Google recommends custom service accounts that have cloud-platform scope and permissions
    service_account = google_service_account.gke_node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  autoscaling {
    min_node_count = 2
    max_node_count = 4
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service Account for GKE nodes
resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-gke-node"
  display_name = "GKE Node Service Account"
  project      = var.gcp_project_id
}

# Cloud SQL PostgreSQL Database
resource "google_sql_database_instance" "postgres" {
  name             = "${var.cluster_name}-postgres"
  database_version = "POSTGRES_15"
  region           = var.gcp_region
  project          = var.gcp_project_id

  settings {
    tier                        = var.db_tier
    deletion_protection_enabled = false

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }
  }

  depends_on = [
    google_project_service.required_apis,
    google_compute_network.vpc
  ]
}

# Cloud SQL Database
resource "google_sql_database" "database" {
  name     = "sligo"
  instance = google_sql_database_instance.postgres.name
  project  = var.gcp_project_id
}

# Cloud SQL User
resource "google_sql_user" "user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
  project  = var.gcp_project_id
}

# Memorystore Redis
resource "google_redis_instance" "redis" {
  name           = "${var.cluster_name}-redis"
  tier           = "BASIC"
  memory_size_gb = var.redis_memory_size_gb
  region         = var.gcp_region
  project        = var.gcp_project_id

  authorized_network = google_compute_network.vpc.id

  depends_on = [
    google_project_service.required_apis,
    google_compute_network.vpc
  ]
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Helm Provider Configuration
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

# Data source for GCP client config
data "google_client_config" "provider" {}

# Wait for cluster to be fully ready before Kubernetes operations
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    google_container_cluster.primary,
    google_container_node_pool.primary_nodes
  ]

  create_duration = "30s"
}

# Kubernetes Namespace
resource "kubernetes_namespace" "sligo" {
  metadata {
    name = "sligo"
    labels = {
      app = "sligo-cloud"
    }
  }

  depends_on = [time_sleep.wait_for_cluster]
}

# Image Pull Secret for GAR
resource "kubernetes_secret" "gar_pull_secret" {
  metadata {
    name      = "gar-pull-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "us-central1-docker.pkg.dev" = {
          username = "_json_key"
          password = file(var.sligo_service_account_key_path)
          auth     = base64encode("_json_key:${file(var.sligo_service_account_key_path)}")
        }
      }
    })
  }
}

# Application Secrets (same structure as AWS EKS)
resource "kubernetes_secret" "nextjs_secrets" {
  metadata {
    name      = "nextjs-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    NEXT_PUBLIC_API_URL            = var.next_public_api_url
    NEXT_PUBLIC_URL                = var.frontend_url
    FRONTEND_URL                   = var.frontend_url
    NEXTAUTH_SECRET                = var.nextauth_secret
    PORT                           = "3000"
    REDIS_URL                      = "rediss://${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
    BACKEND_URL                    = "http://sligo-backend:3001"
    MCP_GATEWAY_URL                = "http://mcp-gateway:3002"
    DATABASE_URL                   = "postgresql://${urlencode(google_sql_user.user.name)}:${urlencode(google_sql_user.user.password)}@${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.database.name}"
    WORKOS_API_KEY                 = var.workos_api_key != "" ? var.workos_api_key : "placeholder"
    WORKOS_CLIENT_ID               = var.workos_client_id != "" ? var.workos_client_id : "placeholder"
    WORKOS_COOKIE_PASSWORD         = var.workos_cookie_password != "" ? var.workos_cookie_password : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_ID   = var.next_public_google_client_id != "" ? var.next_public_google_client_id : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_KEY  = var.next_public_google_client_key != "" ? var.next_public_google_client_key : "placeholder"
    NEXT_PUBLIC_ONEDRIVE_CLIENT_ID = var.next_public_onedrive_client_id != "" ? var.next_public_onedrive_client_id : "placeholder"
    PINECONE_API_KEY               = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX                 = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    GOOGLE_CLIENT_SECRET           = var.google_client_secret != "" ? var.google_client_secret : "placeholder"
    ONEDRIVE_CLIENT_SECRET         = var.onedrive_client_secret != "" ? var.onedrive_client_secret : "placeholder"
    OPENAI_API_KEY                 = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    ENCRYPTION_KEY                 = var.encryption_key != "" ? var.encryption_key : "placeholder"
    BUCKET_NAME_AGENT_AVATARS      = local.gcs_bucket_agent_avatars_id
    BUCKET_NAME_FILE_MANAGER       = local.gcs_bucket_file_manager_id
    BUCKET_NAME_LOGOS              = local.gcs_bucket_logos_id
    BUCKET_NAME_RAG                = local.gcs_bucket_rag_id
    NODE_ENV                       = "production"
    SKIP_ENV_VALIDATION            = "true"
    GOOGLE_PROJECTID               = var.google_project_id != "" ? var.google_project_id : var.gcp_project_id
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.rag_sa_key != "" ? { RAG_SA_KEY = var.rag_sa_key } : {})
}

resource "kubernetes_secret" "backend_secrets" {
  metadata {
    name      = "backend-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    JWT_SECRET                           = var.jwt_secret
    API_KEY                              = var.api_key
    PORT                                 = "3001"
    DATABASE_URL                         = "postgresql://${urlencode(google_sql_user.user.name)}:${urlencode(google_sql_user.user.password)}@${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.database.name}"
    REDIS_URL                            = "rediss://${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
    MCP_GATEWAY_URL                      = "http://mcp-gateway:3002"
    SQL_CONNECTION_STRING_DECRYPTION_IV  = var.sql_connection_string_decryption_iv != "" ? var.sql_connection_string_decryption_iv : "placeholder"
    SQL_CONNECTION_STRING_DECRYPTION_KEY = var.sql_connection_string_decryption_key != "" ? var.sql_connection_string_decryption_key : "placeholder"
    ENCRYPTION_KEY                       = var.encryption_key != "" ? var.encryption_key : "placeholder"
    OPENAI_API_KEY                       = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    OPENAI_BASE_URL                      = var.openai_base_url
    ANTHROPIC_API_KEY                    = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    VERBOSE_LOGGING                      = tostring(var.verbose_logging)
    BACKEND_REQUEST_TIMEOUT_MS           = tostring(var.backend_request_timeout_ms)
    LANGSMITH_API_KEY                    = var.langsmith_api_key != "" ? var.langsmith_api_key : ""
    BUCKET_NAME_FILE_MANAGER             = local.gcs_bucket_file_manager_id
    NODE_ENV                             = "production"
    SKIP_ENV_VALIDATION                  = "true"
    GOOGLE_PROJECTID                     = var.google_project_id != "" ? var.google_project_id : ""
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {})
}

resource "kubernetes_secret" "mcp_gateway_secrets" {
  metadata {
    name      = "mcp-gateway-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    SECRET                       = var.gateway_secret
    PORT                         = "3002"
    FRONTEND_URL                 = var.frontend_url
    BUCKET_NAME_FILE_MANAGER     = local.gcs_bucket_file_manager_id
    REDIS_URL                    = "rediss://${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
    REDIS_URL_STRUCTURED_OUTPUTS = "rediss://${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
    PINECONE_API_KEY             = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX               = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    OPENAI_API_KEY               = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    PERPLEXITY_API_KEY           = var.perplexity_api_key != "" ? var.perplexity_api_key : "placeholder"
    TAVILY_API_KEY               = var.tavily_api_key != "" ? var.tavily_api_key : "placeholder"
    SPENDHQ_BASE_URL             = var.spendhq_base_url != "" ? var.spendhq_base_url : "placeholder"
    SPENDHQ_CLIENT_ID            = var.spendhq_client_id != "" ? var.spendhq_client_id : "placeholder"
    SPENDHQ_CLIENT_SECRET        = var.spendhq_client_secret != "" ? var.spendhq_client_secret : "placeholder"
    SPENDHQ_TOKEN_URL            = var.spendhq_token_url != "" ? var.spendhq_token_url : "placeholder"
    SPENDHQ_SS_HOST              = var.spendhq_ss_host != "" ? var.spendhq_ss_host : "placeholder"
    SPENDHQ_SS_USERNAME          = var.spendhq_ss_username != "" ? var.spendhq_ss_username : "placeholder"
    SPENDHQ_SS_PASSWORD          = var.spendhq_ss_password != "" ? var.spendhq_ss_password : "placeholder"
    SPENDHQ_SS_PORT              = var.spendhq_ss_port != "" ? var.spendhq_ss_port : "3306"
    ANTHROPIC_API_KEY            = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    GOOGLE_PROJECTID             = var.google_project_id != "" ? var.google_project_id : ""
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {})
}

# Database Secret
resource "kubernetes_secret" "database_secret" {
  metadata {
    name      = "database-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    host     = google_sql_database_instance.postgres.private_ip_address
    port     = "5432"
    database = google_sql_database.database.name
    username = google_sql_user.user.name
    password = google_sql_user.user.password
  }
}

# Redis Secret
resource "kubernetes_secret" "redis_secret" {
  metadata {
    name      = "redis-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    host = google_redis_instance.redis.host
    port = tostring(google_redis_instance.redis.port)
  }
}

# GCS Buckets for Application Storage (4 buckets - same architecture as AWS S3)
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "file_manager" {
  count         = var.use_existing_gcs_bucket ? 0 : 1
  name          = var.gcs_bucket_name != "" ? var.gcs_bucket_name : "${var.cluster_name}-file-manager-${random_id.bucket_suffix.hex}"
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  versioning {
    enabled = var.gcs_bucket_versioning
  }

  uniform_bucket_level_access = true

  labels = {
    name        = "${var.cluster_name}-file-manager"
    environment = "production"
    purpose     = "file-manager"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket" "agent_avatars" {
  count         = var.use_existing_gcs_bucket ? 0 : 1
  name          = var.gcs_bucket_agent_avatars_name != "" ? var.gcs_bucket_agent_avatars_name : "${var.cluster_name}-agent-avatars-${random_id.bucket_suffix.hex}"
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  versioning {
    enabled = var.gcs_bucket_versioning
  }

  uniform_bucket_level_access = true

  labels = {
    name        = "${var.cluster_name}-agent-avatars"
    environment = "production"
    purpose     = "agent-avatars"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket" "logos" {
  count         = var.use_existing_gcs_bucket ? 0 : 1
  name          = var.gcs_bucket_logos_name != "" ? var.gcs_bucket_logos_name : "${var.cluster_name}-logos-${random_id.bucket_suffix.hex}"
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  versioning {
    enabled = var.gcs_bucket_versioning
  }

  uniform_bucket_level_access = true

  labels = {
    name        = "${var.cluster_name}-logos"
    environment = "production"
    purpose     = "mcp-logos"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket" "rag" {
  count         = var.use_existing_gcs_bucket ? 0 : 1
  name          = var.gcs_bucket_rag_name != "" ? var.gcs_bucket_rag_name : "${var.cluster_name}-rag-${random_id.bucket_suffix.hex}"
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  versioning {
    enabled = var.gcs_bucket_versioning
  }

  uniform_bucket_level_access = true

  labels = {
    name        = "${var.cluster_name}-rag"
    environment = "production"
    purpose     = "rag-storage"
  }

  depends_on = [google_project_service.required_apis]
}

locals {
  gcs_bucket_file_manager_id  = var.use_existing_gcs_bucket ? var.gcs_bucket_name : google_storage_bucket.file_manager[0].name
  gcs_bucket_agent_avatars_id = var.use_existing_gcs_bucket ? var.gcs_bucket_agent_avatars_name : google_storage_bucket.agent_avatars[0].name
  gcs_bucket_logos_id         = var.use_existing_gcs_bucket ? var.gcs_bucket_logos_name : google_storage_bucket.logos[0].name
  gcs_bucket_rag_id           = var.use_existing_gcs_bucket ? var.gcs_bucket_rag_name : google_storage_bucket.rag[0].name
}

# Service Account for GCS Access (for use by pods)
resource "google_service_account" "gcs_access" {
  account_id   = "${var.cluster_name}-gcs-access"
  display_name = "GCS Access Service Account"
  project      = var.gcp_project_id
}

resource "google_storage_bucket_iam_member" "gcs_file_manager" {
  count  = var.use_existing_gcs_bucket ? 0 : 1
  bucket = google_storage_bucket.file_manager[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
}

resource "google_storage_bucket_iam_member" "gcs_agent_avatars" {
  count  = var.use_existing_gcs_bucket ? 0 : 1
  bucket = google_storage_bucket.agent_avatars[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
}

resource "google_storage_bucket_iam_member" "gcs_logos" {
  count  = var.use_existing_gcs_bucket ? 0 : 1
  bucket = google_storage_bucket.logos[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
}

resource "google_storage_bucket_iam_member" "gcs_rag" {
  count  = var.use_existing_gcs_bucket ? 0 : 1
  bucket = google_storage_bucket.rag[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
}

# GCS Bucket Secret for Kubernetes
resource "kubernetes_secret" "gcs_secret" {
  metadata {
    name      = "gcs-storage-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    bucket_name_file_manager  = local.gcs_bucket_file_manager_id
    bucket_name_agent_avatars = local.gcs_bucket_agent_avatars_id
    bucket_name_logos         = local.gcs_bucket_logos_id
    bucket_name_rag           = local.gcs_bucket_rag_id
    project_id                = var.gcp_project_id
    service_account_email     = google_service_account.gcs_access.email
  }
}

# Helm Release for Sligo Cloud (same structure as AWS EKS)
resource "helm_release" "sligo_cloud" {
  name       = "sligo-cloud"
  repository = "https://sligo-ai.github.io/sligo-helm-charts"
  chart      = "sligo-cloud"
  version    = var.app_version
  namespace  = kubernetes_namespace.sligo.metadata[0].name
  timeout    = 600 # 10 minutes timeout

  values = [
    yamlencode({
      global = {
        imagePullSecrets = [
          kubernetes_secret.gar_pull_secret.metadata[0].name
        ]
      }

      ingress = {
        enabled   = true
        className = "gce"
        annotations = {
          "kubernetes.io/ingress.class" = "gce"
        }
        hosts = [
          {
            host = var.domain_name
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend  = "app"
              }
            ]
          }
        ]
      }

      app = {
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-frontend"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = kubernetes_secret.nextjs_secrets.metadata[0].name
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }

      backend = {
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-backend"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = kubernetes_secret.backend_secrets.metadata[0].name
        resources = {
          requests = {
            cpu    = "1000m"
            memory = "2Gi"
          }
          limits = {
            cpu    = "2000m"
            memory = "4Gi"
          }
        }
      }

      mcpGateway = {
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-mcp-gateway"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = kubernetes_secret.mcp_gateway_secrets.metadata[0].name
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }

      # Pre-install/pre-upgrade Job: Prisma migrate + sync AI models + sync MCP servers (same as build-and-publish)
      releaseSetup = {
        enabled = true
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-release-setup"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = kubernetes_secret.backend_secrets.metadata[0].name
      }

      database = {
        enabled = true
        type    = "external"
        external = {
          host       = google_sql_database_instance.postgres.private_ip_address
          port       = 5432
          database   = google_sql_database.database.name
          secretName = kubernetes_secret.database_secret.metadata[0].name
        }
      }

      redis = {
        enabled = true
        type    = "external"
        external = {
          host       = google_redis_instance.redis.host
          port       = google_redis_instance.redis.port
          secretName = kubernetes_secret.redis_secret.metadata[0].name
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster,
    kubernetes_secret.gar_pull_secret,
    kubernetes_secret.nextjs_secrets,
    kubernetes_secret.backend_secrets,
    kubernetes_secret.mcp_gateway_secrets,
    kubernetes_secret.database_secret,
    kubernetes_secret.redis_secret
  ]
}
