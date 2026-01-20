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
    "compute.googleapis.com"
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

# Kubernetes Namespace
resource "kubernetes_namespace" "sligo" {
  metadata {
    name = "sligo"
    labels = {
      app = "sligo-cloud"
    }
  }
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
        "us-docker.pkg.dev" = {
          username = "_json_key"
          password = file(var.sligo_service_account_key_path)
          auth     = base64encode("_json_key:${file(var.sligo_service_account_key_path)}")
        }
      }
    })
  }
}

# Application Secrets
resource "kubernetes_secret" "nextjs_secrets" {
  metadata {
    name      = "nextjs-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    NEXT_PUBLIC_API_URL = var.next_public_api_url
    FRONTEND_URL        = var.frontend_url
    NEXTAUTH_SECRET     = var.nextauth_secret
  }
}

resource "kubernetes_secret" "backend_secrets" {
  metadata {
    name      = "backend-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    JWT_SECRET = var.jwt_secret
    API_KEY    = var.api_key
  }
}

resource "kubernetes_secret" "mcp_gateway_secrets" {
  metadata {
    name      = "mcp-gateway-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    SECRET = var.gateway_secret
  }
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

# GCS Bucket for Application Storage
locals {
  gcs_bucket_name = var.gcs_bucket_name != "" ? var.gcs_bucket_name : "${var.cluster_name}-storage-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "app_storage" {
  name          = local.gcs_bucket_name
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  versioning {
    enabled = var.gcs_bucket_versioning
  }

  uniform_bucket_level_access = true

  labels = {
    name        = "${var.cluster_name}-storage"
    environment = "production"
  }

  depends_on = [google_project_service.required_apis]
}

# Service Account for GCS Access (for use by pods)
resource "google_service_account" "gcs_access" {
  account_id   = "${var.cluster_name}-gcs-access"
  display_name = "GCS Access Service Account"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "gcs_access" {
  project = var.gcp_project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.gcs_access.email}"
}

resource "google_project_iam_member" "gcs_bucket_access" {
  project = var.gcp_project_id
  role    = "roles/storage.legacyBucketReader"
  member  = "serviceAccount:${google_service_account.gcs_access.email}"
}

# GCS Bucket Secret for Kubernetes
resource "kubernetes_secret" "gcs_secret" {
  metadata {
    name      = "gcs-storage-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    bucket_name           = google_storage_bucket.app_storage.name
    bucket_url            = google_storage_bucket.app_storage.url
    project_id            = var.gcp_project_id
    service_account_email = google_service_account.gcs_access.email
  }
}

# Helm Release for Sligo Cloud
resource "helm_release" "sligo_cloud" {
  name       = "sligo-cloud"
  repository = "https://sligo-ai.github.io/sligo-helm-charts"
  chart      = "sligo-cloud"
  version    = var.app_version
  namespace  = kubernetes_namespace.sligo.metadata[0].name

  values = [
    yamlencode({
      ingress = {
        enabled = true
        hosts = [
          {
            host  = var.domain_name
            paths = ["/"]
          }
        ]
        annotations = {
          "kubernetes.io/ingress.class" = "gce"
        }
      }

      imagePullSecrets = [
        {
          name = kubernetes_secret.gar_pull_secret.metadata[0].name
        }
      ]

      app = {
        image = {
          repository = "us-docker.pkg.dev/${var.client_repository_name}/nextjs"
          tag        = var.app_version
        }
        secretName = kubernetes_secret.nextjs_secrets.metadata[0].name
      }

      backend = {
        image = {
          repository = "us-docker.pkg.dev/${var.client_repository_name}/backend"
          tag        = var.app_version
        }
        envFrom = [
          {
            secretRef = {
              name = kubernetes_secret.backend_secrets.metadata[0].name
            }
          }
        ]
        database = {
          host     = google_sql_database_instance.postgres.private_ip_address
          port     = 5432
          database = google_sql_database.database.name
          username = google_sql_user.user.name
          password = google_sql_user.user.password
        }
        redis = {
          host = google_redis_instance.redis.host
          port = google_redis_instance.redis.port
        }
      }

      mcpGateway = {
        image = {
          repository = "us-docker.pkg.dev/${var.client_repository_name}/mcp-gateway"
          tag        = var.app_version
        }
        envFrom = [
          {
            secretRef = {
              name = kubernetes_secret.mcp_gateway_secrets.metadata[0].name
            }
          }
        ]
      }
    })
  ]

  depends_on = [
    kubernetes_secret.gar_pull_secret,
    kubernetes_secret.nextjs_secrets,
    kubernetes_secret.backend_secrets,
    kubernetes_secret.mcp_gateway_secrets,
    kubernetes_secret.database_secret,
    kubernetes_secret.redis_secret
  ]
}
