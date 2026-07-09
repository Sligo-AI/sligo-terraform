# Provider Configuration
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Short prefix for service account account_id (GCP max 30 chars: ^[a-z](?:[-a-z0-9]{4,28}[a-z0-9])$)
locals {
  sa_account_id_prefix   = substr(replace(var.cluster_name, "_", "-"), 0, min(19, length(replace(var.cluster_name, "_", "-"))))
  existing_subnet_region = var.existing_subnet_region != "" ? var.existing_subnet_region : var.gcp_region
  client_name            = replace(var.client_repository_name, "-containers", "")
  cp_exporter_gcs_bucket = "sligo-tfstate-${local.client_name}"
}

# Data source for existing network (when use_existing_network=true)
data "google_compute_network" "existing" {
  count   = var.use_existing_network ? 1 : 0
  name    = var.existing_network_name
  project = var.gcp_project_id
}

data "google_compute_subnetwork" "existing" {
  count   = var.use_existing_network ? 1 : 0
  name    = var.existing_subnet_name
  region  = local.existing_subnet_region
  project = var.gcp_project_id
}

locals {
  network_id   = var.use_existing_network ? data.google_compute_network.existing[0].id : google_compute_network.vpc[0].id
  network_name = var.use_existing_network ? data.google_compute_network.existing[0].name : google_compute_network.vpc[0].name
  subnet_id    = var.use_existing_network ? data.google_compute_subnetwork.existing[0].id : google_compute_subnetwork.subnet[0].id
  subnet_name  = var.use_existing_network ? data.google_compute_subnetwork.existing[0].name : google_compute_subnetwork.subnet[0].name
}

# Add secondary IP ranges to existing subnet (when use_existing_network=true and CIDRs are provided)
resource "null_resource" "subnet_secondary_ranges" {
  count = var.use_existing_network && var.secondary_pod_cidr != "" && var.secondary_service_cidr != "" ? 1 : 0

  triggers = {
    subnet             = var.existing_subnet_name
    pod_range_name     = var.secondary_pod_range_name
    pod_cidr           = var.secondary_pod_cidr
    service_range_name = var.secondary_service_range_name
    service_cidr       = var.secondary_service_cidr
  }

  provisioner "local-exec" {
    command = <<-EOT
      CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE=$GOOGLE_APPLICATION_CREDENTIALS \
      gcloud compute networks subnets update ${var.existing_subnet_name} \
        --region=${local.existing_subnet_region} \
        --project=${var.gcp_project_id} \
        --add-secondary-ranges="${var.secondary_pod_range_name}=${var.secondary_pod_cidr},${var.secondary_service_range_name}=${var.secondary_service_cidr}"
    EOT
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "aiplatform.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com"
  ])

  project = var.gcp_project_id
  service = each.value

  disable_on_destroy = false
}

# VPC Network (only when not using existing)
resource "google_compute_network" "vpc" {
  count                   = var.use_existing_network ? 0 : 1
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.required_apis]
}

# Subnet (only when not using existing)
resource "google_compute_subnetwork" "subnet" {
  count         = var.use_existing_network ? 0 : 1
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.gcp_region
  network       = google_compute_network.vpc[0].id
}

# Reserved IP range for private service connection (Cloud SQL, etc.) - skipped when use_existing_psa=true (client provides PSA)
resource "google_compute_global_address" "private_ip_range" {
  count         = var.use_existing_psa ? 0 : 1
  name          = "${var.cluster_name}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = local.network_id
  project       = var.gcp_project_id

  depends_on = [google_project_service.required_apis]
}

# Service Networking connection (required for Cloud SQL private IP) - skipped when use_existing_psa=true (client provides PSA)
resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.use_existing_psa ? 0 : 1
  network                 = local.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range[0].name]

  depends_on = [google_project_service.required_apis]
}

# Ensures PSA is ready before Cloud SQL (workaround for static depends_on)
resource "null_resource" "psa_ready" {
  triggers = var.use_existing_psa ? {} : { connection = google_service_networking_connection.private_vpc_connection[0].id }
}

# On destroy, Cloud SQL must fully release private service access before the VPC peering can be
# deleted; otherwise servicenetworking returns "Producer services are still using this connection".
resource "time_sleep" "wait_after_sql_destroy" {
  depends_on = [null_resource.psa_ready]

  create_duration  = "0s"
  destroy_duration = var.private_service_access_destroy_wait
}

# Cloud Router + NAT so private GKE nodes/pods can reach the internet (e.g. WorkOS api.workos.com)
# Skipped when use_existing_network=true — the client's VPC already has a NAT covering ALL_SUBNETWORKS_ALL_IP_RANGES
resource "google_compute_router" "router" {
  count   = var.use_existing_network ? 0 : 1
  name    = "${var.cluster_name}-router"
  region  = var.gcp_region
  network = local.network_id
  project = var.gcp_project_id
}

resource "google_compute_router_nat" "nat" {
  count                              = var.use_existing_network ? 0 : 1
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router[0].name
  region                             = var.gcp_region
  project                            = var.gcp_project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name                = var.cluster_name
  location            = var.gcp_region
  project             = var.gcp_project_id
  deletion_protection = var.gke_deletion_protection
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = local.network_name
  subnetwork = local.subnet_name

  dynamic "ip_allocation_policy" {
    for_each = var.use_existing_network ? [1] : []
    content {
      cluster_secondary_range_name  = var.secondary_pod_range_name
      services_secondary_range_name = var.secondary_service_range_name
    }
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  # Enable private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Required when enable_private_endpoint = true
  dynamic "master_authorized_networks_config" {
    for_each = var.enable_private_endpoint ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_cidrs
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
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
    null_resource.subnet_secondary_ranges
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
    machine_type = var.node_machine_type

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
  account_id   = "${local.sa_account_id_prefix}-gke-node"
  display_name = "GKE Node Service Account (${var.cluster_name})"
  project      = var.gcp_project_id
}

# Cloud SQL PostgreSQL Database
resource "google_sql_database_instance" "postgres" {
  name                = "${var.cluster_name}-postgres"
  database_version    = "POSTGRES_15"
  region              = var.gcp_region
  project             = var.gcp_project_id
  deletion_protection = var.cloud_sql_deletion_protection

  settings {
    tier                        = var.db_tier
    deletion_protection_enabled = var.cloud_sql_deletion_protection

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = local.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }
  }

  depends_on = [google_project_service.required_apis, time_sleep.wait_after_sql_destroy]
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

# GKE uses in-cluster Redis Stack (from Helm) with persistence. Memorystore is not used.

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

# GKE ingress prerequisites (ManagedCertificate, BackendConfig).
# Use Helm instead of kubernetes_manifest so first-time bootstraps can plan without
# a live Kubernetes API / CRD schema discovery (kubernetes_manifest fails at plan).
resource "helm_release" "gke_ingress_prereqs" {
  name      = "gke-ingress-prereqs"
  chart     = "${path.module}/charts/gke-ingress-prereqs"
  namespace = kubernetes_namespace.sligo.metadata[0].name
  timeout   = 600

  values = [yamlencode({
    managedSslCertificate = {
      enabled = var.use_managed_ssl_certificate
      name    = "sligo-managed-cert-app"
      domains = [var.domain_name]
    }
    backendConfig = {
      name       = "sligo-app-backendconfig"
      timeoutSec = 60
    }
  })]

  depends_on = [
    time_sleep.wait_for_cluster,
    kubernetes_namespace.sligo,
  ]
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
  count = var.use_eso_managed_app_secrets ? 0 : 1

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
    REDIS_URL                      = local.redis_url
    BACKEND_URL                    = "http://sligo-backend:3001"
    BACKEND_API_KEY                = var.backend_api_key
    MCP_GATEWAY_URL                = "http://mcp-gateway:3002"
    DATABASE_URL                   = "postgresql://${urlencode(google_sql_user.user.name)}:${urlencode(google_sql_user.user.password)}@${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.database.name}"
    AUTH_PROVIDER                  = var.auth_provider
    AUTH_INVITATIONS               = var.auth_invitations != "" ? var.auth_invitations : ""
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
    LANGSMITH_TRACING              = var.langsmith_tracing
    LANGSMITH_PROJECT              = var.langsmith_project
    LANGSMITH_ENDPOINT             = var.langsmith_endpoint
    LANGSMITH_API_KEY              = var.langsmith_api_key != "" ? var.langsmith_api_key : ""
    LANGFUSE_BASE_URL              = var.langfuse_base_url
    LANGFUSE_PUBLIC_KEY            = var.langfuse_public_key
    LANGFUSE_SECRET_KEY            = var.langfuse_secret_key != "" ? var.langfuse_secret_key : ""
    OBSERVABILITY_PROVIDER         = var.observability_provider
    BUCKET_NAME_AGENT_AVATARS      = local.gcs_bucket_agent_avatars_id
    BUCKET_NAME_FILE_MANAGER       = local.gcs_bucket_file_manager_id
    BUCKET_NAME_LOGOS              = local.gcs_bucket_logos_id
    BUCKET_NAME_RAG                = local.gcs_bucket_rag_id
    NODE_ENV                       = "production"
    SKIP_ENV_VALIDATION            = "true"
    GOOGLE_PROJECTID               = var.google_project_id != "" ? var.google_project_id : var.gcp_project_id
    SUPER_ADMIN_EMAILS             = var.super_admin_emails != "" ? var.super_admin_emails : ""
    # Same JSON as GAR pull — GCS client for MDI default seed (mdi-defaults bucket).
    MDI_GCP_KEY                                        = file(var.sligo_service_account_key_path)
    }, var.storage_provider != "" ? { STORAGE_PROVIDER = var.storage_provider } : {}, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, local.rag_sa_key != "" ? { RAG_SA_KEY = local.rag_sa_key } : {}, var.auth_provider == "oidc" ? {
    AUTH_SESSION_SECRET                                = var.auth_session_secret != "" ? var.auth_session_secret : "placeholder"
    OIDC_ISSUER                                        = var.oidc_issuer
    OIDC_CLIENT_ID                                     = var.oidc_client_id
    OIDC_CLIENT_SECRET                                 = var.oidc_client_secret != "" ? var.oidc_client_secret : "placeholder"
    OIDC_SCOPES                                        = var.oidc_scopes
    OIDC_DEFAULT_ORG_ID                                = var.oidc_default_org_id
    OIDC_DEFAULT_ORG_NAME                              = var.oidc_default_org_name
    } : {}, var.auth_provider == "saml" ? {
    AUTH_SESSION_SECRET                                     = var.auth_session_secret != "" ? var.auth_session_secret : "placeholder"
    SAML_ENTRYPOINT                                         = var.saml_entrypoint
    SAML_ISSUER                                             = var.saml_issuer
    SAML_CERT                                               = var.saml_cert != "" ? var.saml_cert : "placeholder"
    SAML_DEFAULT_ORG_ID                                     = var.saml_default_org_id
    SAML_DEFAULT_ORG_NAME                                   = var.saml_default_org_name
    } : {}, var.rag_vector_store != "" ? { RAG_VECTOR_STORE = var.rag_vector_store } : {}, var.pinecone_environment != "" ? { PINECONE_ENVIRONMENT = var.pinecone_environment } : {}, var.singlestore_host != "" ? {
    SINGLESTORE_HOST                                        = var.singlestore_host
    SINGLESTORE_PORT                                        = var.singlestore_port
    SINGLESTORE_USER                                        = var.singlestore_user
    SINGLESTORE_PASSWORD                                    = var.singlestore_password != "" ? var.singlestore_password : "placeholder"
    SINGLESTORE_DATABASE                                    = var.singlestore_database
    } : {}, var.azure_aisearch_endpoint != "" ? {
    RAG_VECTOR_STORE          = "azureaisearch"
    AZURE_AISEARCH_ENDPOINT   = var.azure_aisearch_endpoint
    AZURE_AISEARCH_KEY        = var.azure_aisearch_key != "" ? var.azure_aisearch_key : "placeholder"
    AZURE_AISEARCH_INDEX      = var.azure_aisearch_index
    AZURE_AISEARCH_QUERY_TYPE = var.azure_aisearch_query_type
  } : {}, var.langsmith_api_base_url != "" ? { LANGSMITH_API_BASE_URL = var.langsmith_api_base_url } : {}, var.auth_base_url != "" ? { AUTH_BASE_URL = var.auth_base_url } : {}, var.auth_cookie_name != "" ? { AUTH_COOKIE_NAME = var.auth_cookie_name } : {}, var.auth_cookie_same_site != "" ? { AUTH_COOKIE_SAME_SITE = var.auth_cookie_same_site } : {})
}

resource "kubernetes_secret" "backend_secrets" {
  count = var.use_eso_managed_app_secrets ? 0 : 1

  metadata {
    name      = "backend-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    JWT_SECRET                                         = var.jwt_secret
    API_KEY                                            = var.api_key
    BACKEND_API_KEY                                    = var.backend_api_key
    PORT                                               = "3001"
    DATABASE_URL                                       = "postgresql://${urlencode(google_sql_user.user.name)}:${urlencode(google_sql_user.user.password)}@${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.database.name}"
    REDIS_URL                                          = local.redis_url
    MCP_GATEWAY_URL                                    = "http://mcp-gateway:3002"
    SQL_CONNECTION_STRING_DECRYPTION_IV                = var.sql_connection_string_decryption_iv != "" ? var.sql_connection_string_decryption_iv : "placeholder"
    SQL_CONNECTION_STRING_DECRYPTION_KEY               = var.sql_connection_string_decryption_key != "" ? var.sql_connection_string_decryption_key : "placeholder"
    ENCRYPTION_KEY                                     = var.encryption_key != "" ? var.encryption_key : "placeholder"
    OPENAI_API_KEY                                     = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    OPENAI_BASE_URL                                    = var.openai_base_url
    ANTHROPIC_API_KEY                                  = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    TOGETHER_AI_API_KEY                                = var.together_ai_api_key != "" ? var.together_ai_api_key : "placeholder"
    VERBOSE_LOGGING                                    = tostring(var.verbose_logging)
    BACKEND_REQUEST_TIMEOUT_MS                         = tostring(var.backend_request_timeout_ms)
    LANGSMITH_TRACING                                  = var.langsmith_tracing
    LANGSMITH_PROJECT                                  = var.langsmith_project
    LANGSMITH_ENDPOINT                                 = var.langsmith_endpoint
    LANGSMITH_API_KEY                                  = var.langsmith_api_key != "" ? var.langsmith_api_key : ""
    LANGFUSE_BASE_URL                                  = var.langfuse_base_url
    LANGFUSE_PUBLIC_KEY                                = var.langfuse_public_key
    LANGFUSE_SECRET_KEY                                = var.langfuse_secret_key != "" ? var.langfuse_secret_key : ""
    OBSERVABILITY_PROVIDER                             = var.observability_provider
    BUCKET_NAME_FILE_MANAGER                           = local.gcs_bucket_file_manager_id
    NODE_ENV                                           = "production"
    SKIP_ENV_VALIDATION                                = "true"
    GOOGLE_PROJECTID                                   = var.google_project_id != "" ? var.google_project_id : ""
    }, var.storage_provider != "" ? { STORAGE_PROVIDER = var.storage_provider } : {}, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {}, var.azure_openai_api_key != "" ? {
    AZURE_OPENAI_API_KEY                               = var.azure_openai_api_key
    AZURE_OPENAI_API_INSTANCE_NAME                     = var.azure_openai_api_instance_name
    AZURE_OPENAI_API_VERSION                           = var.azure_openai_api_version
    AZURE_OPENAI_BASE_PATH                             = var.azure_openai_base_path
  } : {})
}

resource "kubernetes_secret" "mcp_gateway_secrets" {
  count = var.use_eso_managed_app_secrets ? 0 : 1

  metadata {
    name      = "mcp-gateway-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    SECRET                                             = var.gateway_secret
    PORT                                               = "3002"
    FRONTEND_URL                                       = var.frontend_url
    BUCKET_NAME_FILE_MANAGER                           = local.gcs_bucket_file_manager_id
    REDIS_URL                                          = local.redis_url
    REDIS_URL_STRUCTURED_OUTPUTS                       = local.redis_url
    PINECONE_API_KEY                                   = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX                                     = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    OPENAI_API_KEY                                     = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    PERPLEXITY_API_KEY                                 = var.perplexity_api_key != "" ? var.perplexity_api_key : "placeholder"
    TAVILY_API_KEY                                     = var.tavily_api_key != "" ? var.tavily_api_key : "placeholder"
    SPENDHQ_BASE_URL                                   = var.spendhq_base_url != "" ? var.spendhq_base_url : "placeholder"
    SPENDHQ_CLIENT_ID                                  = var.spendhq_client_id != "" ? var.spendhq_client_id : "placeholder"
    SPENDHQ_CLIENT_SECRET                              = var.spendhq_client_secret != "" ? var.spendhq_client_secret : "placeholder"
    SPENDHQ_TOKEN_URL                                  = var.spendhq_token_url != "" ? var.spendhq_token_url : "placeholder"
    SPENDHQ_SS_HOST                                    = var.spendhq_ss_host != "" ? var.spendhq_ss_host : "placeholder"
    SPENDHQ_SS_USERNAME                                = var.spendhq_ss_username != "" ? var.spendhq_ss_username : "placeholder"
    SPENDHQ_SS_PASSWORD                                = var.spendhq_ss_password != "" ? var.spendhq_ss_password : "placeholder"
    SPENDHQ_SS_PORT                                    = var.spendhq_ss_port != "" ? var.spendhq_ss_port : "3306"
    ANTHROPIC_API_KEY                                  = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    LANGSMITH_TRACING                                  = var.langsmith_tracing
    LANGSMITH_PROJECT                                  = var.langsmith_project
    LANGSMITH_ENDPOINT                                 = var.langsmith_endpoint
    LANGSMITH_API_KEY                                  = var.langsmith_api_key != "" ? var.langsmith_api_key : ""
    GOOGLE_PROJECTID                                   = var.google_project_id != "" ? var.google_project_id : ""
    }, var.storage_provider != "" ? { STORAGE_PROVIDER = var.storage_provider } : {}, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {}, var.rag_vector_store != "" ? { RAG_VECTOR_STORE = var.rag_vector_store } : {}, var.pinecone_environment != "" ? { PINECONE_ENVIRONMENT = var.pinecone_environment } : {}, var.singlestore_host != "" ? {
    SINGLESTORE_HOST                                   = var.singlestore_host
    SINGLESTORE_PORT                                   = var.singlestore_port
    SINGLESTORE_USER                                   = var.singlestore_user
    SINGLESTORE_PASSWORD                               = var.singlestore_password != "" ? var.singlestore_password : "placeholder"
    SINGLESTORE_DATABASE                               = var.singlestore_database
    } : {}, var.azure_aisearch_endpoint != "" ? {
    RAG_VECTOR_STORE          = "azureaisearch"
    AZURE_AISEARCH_ENDPOINT   = var.azure_aisearch_endpoint
    AZURE_AISEARCH_KEY        = var.azure_aisearch_key != "" ? var.azure_aisearch_key : "placeholder"
    AZURE_AISEARCH_INDEX      = var.azure_aisearch_index
    AZURE_AISEARCH_QUERY_TYPE = var.azure_aisearch_query_type
  } : {})
}

# GCP credentials as a file for ADC (Application Default Credentials) - same flow as SHQ/AWS.
# Mounted at /secrets/gcp/credentials.json so backend/mcp-gateway use explicit SA for Vertex AI.
resource "kubernetes_secret" "gcp_credentials" {
  count = (var.gcp_sa_key != "" || var.google_vertex_ai_web_credentials != "") ? 1 : 0

  metadata {
    name      = "gcp-credentials"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    "credentials.json" = var.gcp_sa_key != "" ? var.gcp_sa_key : var.google_vertex_ai_web_credentials
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

  cors {
    origin          = [var.frontend_url]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

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
  count         = (var.use_existing_gcs_bucket || var.use_existing_agent_avatars_bucket) ? 0 : 1
  name          = var.gcs_bucket_agent_avatars_name != "" ? var.gcs_bucket_agent_avatars_name : "${var.cluster_name}-agent-avatars-${random_id.bucket_suffix.hex}"
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  cors {
    origin          = [var.frontend_url]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

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

  cors {
    origin          = [var.frontend_url]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

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

  cors {
    origin          = [var.frontend_url]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

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
  gcs_bucket_agent_avatars_id = var.use_existing_gcs_bucket ? var.gcs_bucket_agent_avatars_name : (var.use_existing_agent_avatars_bucket ? var.gcs_bucket_agent_avatars_name : google_storage_bucket.agent_avatars[0].name)
  gcs_bucket_logos_id         = var.use_existing_gcs_bucket ? var.gcs_bucket_logos_name : google_storage_bucket.logos[0].name
  gcs_bucket_rag_id           = var.use_existing_gcs_bucket ? var.gcs_bucket_rag_name : google_storage_bucket.rag[0].name

  # Redis URL: external (Redis Cloud, etc.) or in-cluster Redis Stack (Helm)
  use_external_redis = trimspace(var.redis_url) != ""
  redis_url          = local.use_external_redis ? trimspace(var.redis_url) : "redis://redis.${kubernetes_namespace.sligo.metadata[0].name}.svc.cluster.local:6379"

  # Single object shape for Helm (Terraform rejects mismatched conditional branch types).
  redis_helm_values = {
    enabled = !local.use_external_redis
    type    = "internal"
    internal = {
      persistence = {
        enabled      = !local.use_external_redis
        size         = var.redis_persistence_size
        storageClass = var.redis_persistence_storage_class
      }
    }
  }
}

# Service Account for GCS Access (for use by pods)
resource "google_service_account" "gcs_access" {
  account_id   = "${local.sa_account_id_prefix}-gcs-access"
  display_name = "GCS Access Service Account (${var.cluster_name})"
  project      = var.gcp_project_id
}

resource "google_storage_bucket_iam_member" "gcs_file_manager" {
  count  = var.use_existing_gcs_bucket ? 0 : 1
  bucket = google_storage_bucket.file_manager[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
}

resource "google_storage_bucket_iam_member" "gcs_agent_avatars" {
  count  = (var.use_existing_gcs_bucket || var.use_existing_agent_avatars_bucket) ? 0 : 1
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

# Agent avatars and logos: optional public read. Skip when Public Access Prevention is enforced or using external agent avatars bucket.
resource "google_storage_bucket_iam_member" "gcs_agent_avatars_public" {
  count  = (!var.use_existing_gcs_bucket && !var.use_existing_agent_avatars_bucket && var.gcs_allow_public_agent_avatars_logos) ? 1 : 0
  bucket = google_storage_bucket.agent_avatars[0].name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "gcs_logos_public" {
  count  = (!var.use_existing_gcs_bucket && var.gcs_allow_public_agent_avatars_logos) ? 1 : 0
  bucket = google_storage_bucket.logos[0].name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_iam_member" "gcs_rag" {
  count  = var.use_existing_gcs_bucket ? 0 : 1
  bucket = google_storage_bucket.rag[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
}

# Workload Identity: allow app pod to use gcs_access GCP SA (no key needed; org may block iam.serviceAccountKeys.create)
resource "kubernetes_service_account" "app_gcs" {
  metadata {
    name      = "sligo-app-gcs"
    namespace = kubernetes_namespace.sligo.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gcs_access.email
    }
  }
}

resource "google_service_account_iam_member" "app_gcs_workload_identity" {
  service_account_id = google_service_account.gcs_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${kubernetes_namespace.sligo.metadata[0].name}/${kubernetes_service_account.app_gcs.metadata[0].name}]"
}

# Allow gcs_access SA to call signBlob on itself - required for GCS signed URLs with Workload Identity.
# When the app (via Workload Identity) acts as gcs_access, the effective caller for signBlob is gcs_access.
resource "google_service_account_iam_member" "gcs_access_self_token_creator" {
  service_account_id = google_service_account.gcs_access.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.gcs_access.email}"
}

locals {
  # Use explicit rag_sa_key when set; otherwise rely on Workload Identity (app uses ADC → gcs_access SA)
  rag_sa_key = var.rag_sa_key != "" ? var.rag_sa_key : ""

  nextjs_secret_name      = "nextjs-secrets"
  backend_secret_name     = "backend-secrets"
  mcp_gateway_secret_name = "mcp-gateway-secrets"
  default_secret_prefix   = "sligo-${replace(var.cluster_name, "_", "-")}-"
  gsm_secret_prefix       = var.secret_name_prefix != "" ? var.secret_name_prefix : local.default_secret_prefix
  gsm_secret_ids          = { for name in var.secret_names : name => "${local.gsm_secret_prefix}${name}" }
}

data "google_project" "secret_manager" {
  count      = var.enable_external_secrets_operator ? 1 : 0
  project_id = var.secret_manager_project_id
}

resource "google_secret_manager_secret" "app_secrets" {
  for_each  = var.enable_external_secrets_operator && var.create_secret_placeholders ? local.gsm_secret_ids : {}
  secret_id = each.value
  project   = var.secret_manager_project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_project_iam_member" "app_secrets_access" {
  count   = var.enable_external_secrets_operator ? 1 : 0
  project = var.secret_manager_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gcs_access.email}"

  condition {
    title       = "Secret Manager prefix access"
    description = "Accessor only for secrets with deployment prefix"
    expression  = "resource.type == \"secretmanager.googleapis.com/Secret\" && resource.name.startsWith(\"projects/${data.google_project.secret_manager[0].number}/secrets/${local.gsm_secret_prefix}\")"
  }
}

resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  count              = var.enable_external_secrets_operator ? 1 : 0
  service_account_id = google_service_account.gcs_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[external-secrets/external-secrets]"
}

resource "helm_release" "external_secrets" {
  count            = var.enable_external_secrets_operator ? 1 : 0
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.11"
  namespace        = "external-secrets"
  create_namespace = true

  depends_on = [
    time_sleep.wait_for_cluster,
    google_service_account_iam_member.external_secrets_workload_identity
  ]
}

resource "kubernetes_manifest" "gcp_secret_manager_store" {
  count = var.enable_external_secrets_operator ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "gcp-secret-manager"
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = var.secret_manager_project_id
          auth = {
            workloadIdentity = {
              clusterLocation = var.gcp_region
              clusterName     = google_container_cluster.primary.name
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "kubernetes_manifest" "external_secret_nextjs" {
  count = var.enable_external_secrets_operator && var.use_eso_managed_app_secrets ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "nextjs-secrets"
      namespace = kubernetes_namespace.sligo.metadata[0].name
    }
    spec = {
      refreshInterval = "1m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = local.nextjs_secret_name
        creationPolicy = "Owner"
      }
      data = [
        { secretKey = "NEXTAUTH_SECRET", remoteRef = { key = local.gsm_secret_ids["nextauth-secret"] } },
        { secretKey = "BACKEND_API_KEY", remoteRef = { key = local.gsm_secret_ids["backend-api-key"] } },
        { secretKey = "WORKOS_API_KEY", remoteRef = { key = local.gsm_secret_ids["workos-api-key"] } },
        { secretKey = "OPENAI_API_KEY", remoteRef = { key = local.gsm_secret_ids["openai-api-key"] } },
        { secretKey = "ENCRYPTION_KEY", remoteRef = { key = local.gsm_secret_ids["encryption-key"] } },
        { secretKey = "MDI_GCP_KEY", remoteRef = { key = local.gsm_secret_ids["mdi-gcp-key"] } },
        { secretKey = "LANGSMITH_API_KEY", remoteRef = { key = local.gsm_secret_ids["langsmith-api-key"] } },
        { secretKey = "LANGSMITH_PROJECT", remoteRef = { key = local.gsm_secret_ids["langsmith-project"] } },
        { secretKey = "LANGSMITH_TRACING", remoteRef = { key = local.gsm_secret_ids["langsmith-tracing"] } },
        { secretKey = "LANGSMITH_ENDPOINT", remoteRef = { key = local.gsm_secret_ids["langsmith-endpoint"] } },
        { secretKey = "LANGFUSE_BASE_URL", remoteRef = { key = local.gsm_secret_ids["langfuse-base-url"] } },
        { secretKey = "LANGFUSE_PUBLIC_KEY", remoteRef = { key = local.gsm_secret_ids["langfuse-public-key"] } },
        { secretKey = "LANGFUSE_SECRET_KEY", remoteRef = { key = local.gsm_secret_ids["langfuse-secret-key"] } },
        { secretKey = "LANGSMITH_API_BASE_URL", remoteRef = { key = local.gsm_secret_ids["langsmith-api-base-url"] } },
        { secretKey = "OBSERVABILITY_PROVIDER", remoteRef = { key = local.gsm_secret_ids["observability-provider"] } }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gcp_secret_manager_store]
}

resource "kubernetes_manifest" "external_secret_backend" {
  count = var.enable_external_secrets_operator && var.use_eso_managed_app_secrets ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "backend-secrets"
      namespace = kubernetes_namespace.sligo.metadata[0].name
    }
    spec = {
      refreshInterval = "1m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = local.backend_secret_name
        creationPolicy = "Owner"
      }
      data = [
        { secretKey = "JWT_SECRET", remoteRef = { key = local.gsm_secret_ids["jwt-secret"] } },
        { secretKey = "API_KEY", remoteRef = { key = local.gsm_secret_ids["api-key"] } },
        { secretKey = "BACKEND_API_KEY", remoteRef = { key = local.gsm_secret_ids["backend-api-key"] } },
        { secretKey = "OPENAI_API_KEY", remoteRef = { key = local.gsm_secret_ids["openai-api-key"] } },
        { secretKey = "ANTHROPIC_API_KEY", remoteRef = { key = local.gsm_secret_ids["anthropic-api-key"] } },
        { secretKey = "TOGETHER_AI_API_KEY", remoteRef = { key = local.gsm_secret_ids["together-ai-api-key"] } },
        { secretKey = "ENCRYPTION_KEY", remoteRef = { key = local.gsm_secret_ids["encryption-key"] } },
        { secretKey = "LANGFUSE_BASE_URL", remoteRef = { key = local.gsm_secret_ids["langfuse-base-url"] } },
        { secretKey = "LANGFUSE_PUBLIC_KEY", remoteRef = { key = local.gsm_secret_ids["langfuse-public-key"] } },
        { secretKey = "LANGFUSE_SECRET_KEY", remoteRef = { key = local.gsm_secret_ids["langfuse-secret-key"] } },
        { secretKey = "OBSERVABILITY_PROVIDER", remoteRef = { key = local.gsm_secret_ids["observability-provider"] } }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gcp_secret_manager_store]
}

resource "kubernetes_manifest" "external_secret_mcp_gateway" {
  count = var.enable_external_secrets_operator && var.use_eso_managed_app_secrets ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "mcp-gateway-secrets"
      namespace = kubernetes_namespace.sligo.metadata[0].name
    }
    spec = {
      refreshInterval = "1m"
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = local.mcp_gateway_secret_name
        creationPolicy = "Owner"
      }
      data = [
        { secretKey = "SECRET", remoteRef = { key = local.gsm_secret_ids["gateway-secret"] } },
        { secretKey = "OPENAI_API_KEY", remoteRef = { key = local.gsm_secret_ids["openai-api-key"] } },
        { secretKey = "ANTHROPIC_API_KEY", remoteRef = { key = local.gsm_secret_ids["anthropic-api-key"] } }
      ]
    }
  }

  depends_on = [kubernetes_manifest.gcp_secret_manager_store]
}

# GCS Bucket Secret for Kubernetes
resource "kubernetes_secret" "gcs_secret" {
  metadata {
    name      = "gcs-storage-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    bucket_name_file_manager  = local.gcs_bucket_file_manager_id
    bucket_name_agent_avatars = local.gcs_bucket_agent_avatars_id
    bucket_name_logos         = local.gcs_bucket_logos_id
    bucket_name_rag           = local.gcs_bucket_rag_id
    project_id                = var.gcp_project_id
    service_account_email     = google_service_account.gcs_access.email
  }, var.gcs_bucket_agent_avatars_project != "" ? { bucket_agent_avatars_project = var.gcs_bucket_agent_avatars_project } : {})
}

# GCP ADC config: mount credentials as file for backend and mcpGateway (same as SHQ/AWS).
locals {
  gcp_adc_enabled = var.gcp_sa_key != "" || var.google_vertex_ai_web_credentials != ""
  gcp_adc_config = local.gcp_adc_enabled ? {
    extraVolumes = [{
      name = "gcp-credentials"
      secret = {
        secretName = kubernetes_secret.gcp_credentials[0].metadata[0].name
      }
    }]
    extraVolumeMounts = [{
      name      = "gcp-credentials"
      mountPath = "/secrets/gcp"
      readOnly  = true
    }]
    env = {
      GOOGLE_APPLICATION_CREDENTIALS = "/secrets/gcp/credentials.json"
    }
    } : {
    extraVolumes      = []
    extraVolumeMounts = []
    env               = {}
  }
}

# Helm Release for Sligo Cloud (same structure as AWS EKS)
resource "helm_release" "sligo_cloud" {
  name       = "sligo-cloud"
  repository = var.chart_path != "" ? "" : "https://sligo-ai.github.io/sligo-helm-charts"
  chart      = var.chart_path != "" ? var.chart_path : "sligo-cloud"
  version    = var.chart_path != "" ? null : var.chart_version
  namespace  = kubernetes_namespace.sligo.metadata[0].name
  timeout    = 1200 # 20 minutes (release-setup job + Redis Stack + pod rollouts can take long)

  values = concat(
    [yamlencode({
      global = {
        imagePullSecrets = [
          kubernetes_secret.gar_pull_secret.metadata[0].name
        ]
        releaseUpgradeTrigger = var.release_upgrade_trigger
      }

      controlPlaneExporter = {
        enabled   = var.enable_control_plane_exporter
        gcsBucket = local.cp_exporter_gcs_bucket
        gcsPrefix = basename(path.cwd)
      }

      ingress = {
        enabled   = true
        className = "gce"
        annotations = merge(
          { "kubernetes.io/ingress.class" = "gce" },
          var.use_managed_ssl_certificate ? { "networking.gke.io/managed-certificates" = "sligo-managed-cert-app" } : {}
        )
        # No spec.tls secret; use GKE ManagedCertificate via annotation when use_managed_ssl_certificate is true
        tls = []
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
        replicaCount       = 1
        serviceAccount     = kubernetes_service_account.app_gcs.metadata[0].name
        serviceAccountName = kubernetes_service_account.app_gcs.metadata[0].name
        service = {
          type = "NodePort"
          annotations = {
            "cloud.google.com/backend-config" = jsonencode({ "ports" = { "3000" = "sligo-app-backendconfig" } })
          }
        }
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-frontend"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = local.nextjs_secret_name
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

      backend = merge({
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-backend"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = local.backend_secret_name
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
      }, local.gcp_adc_config)

      mcpGateway = merge({
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-mcp-gateway"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = local.mcp_gateway_secret_name
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
      }, local.gcp_adc_config)

      # Pre-install/pre-upgrade Job: Prisma migrate + sync AI models + sync MCP servers (same as build-and-publish)
      releaseSetup = {
        enabled = true
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-release-setup"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = local.backend_secret_name
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

      redis = local.redis_helm_values
    })],
    [yamlencode(local.temporal_helm_values)],
    var.helm_extra_values != "" ? [var.helm_extra_values] : []
  )

  depends_on = [
    time_sleep.wait_for_cluster,
    helm_release.gke_ingress_prereqs,
    kubernetes_secret.gar_pull_secret,
    kubernetes_secret.nextjs_secrets,
    kubernetes_secret.backend_secrets,
    kubernetes_secret.mcp_gateway_secrets,
    kubernetes_secret.gcp_credentials,
    kubernetes_secret.database_secret,
    kubernetes_secret.temporal_db_credentials,
    kubernetes_secret.temporal_visibility_db_credentials,
    kubernetes_manifest.external_secret_nextjs,
    kubernetes_manifest.external_secret_backend,
    kubernetes_manifest.external_secret_mcp_gateway,
    kubernetes_service_account.app_gcs,
    google_service_account_iam_member.app_gcs_workload_identity
  ]
}

# Ingress address (IP or hostname) for DNS - may be pending until GCE LB is ready
data "kubernetes_ingress_v1" "sligo" {
  metadata {
    name      = "sligo-cloud"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  depends_on = [helm_release.sligo_cloud]
}

locals {
  ingress_address = try(
    data.kubernetes_ingress_v1.sligo.status[0].load_balancer[0].ingress[0].ip,
    data.kubernetes_ingress_v1.sligo.status[0].load_balancer[0].ingress[0].hostname,
    ""
  )
}
