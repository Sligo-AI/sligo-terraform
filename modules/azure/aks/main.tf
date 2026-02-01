# Provider Configuration
provider "azurerm" {
  features {}
}

# Resource Group
locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.cluster_name}-rg"
}

resource "azurerm_resource_group" "main" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = local.resource_group_name
  location = var.location

  tags = {
    Name = var.cluster_name
  }
}

data "azurerm_resource_group" "selected" {
  count = var.resource_group_name != "" ? 1 : 0
  name  = var.resource_group_name
}

locals {
  rg_name     = var.resource_group_name != "" ? data.azurerm_resource_group.selected[0].name : azurerm_resource_group.main[0].name
  rg_location = var.resource_group_name != "" ? data.azurerm_resource_group.selected[0].location : azurerm_resource_group.main[0].location
}

# VNet and Subnet for AKS
resource "azurerm_virtual_network" "main" {
  name                = "${var.cluster_name}-vnet"
  location            = local.rg_location
  resource_group_name = local.rg_name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.cluster_name}-aks-subnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# PostgreSQL Flexible Server (Azure Database for PostgreSQL)
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "${replace(var.cluster_name, "-", "")}-pg"
  resource_group_name    = local.rg_name
  location               = local.rg_location
  version                = "15"
  administrator_login    = var.db_username
  administrator_password = var.db_password
  sku_name               = var.postgres_sku_name
  storage_mb             = var.postgres_storage_mb

  # Public access with firewall for simpler setup; can switch to private later
  public_network_access_enabled = true
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "allow-azure"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

resource "azurerm_postgresql_flexible_server_database" "sligo" {
  name      = "sligo"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Azure Cache for Redis
resource "azurerm_redis_cache" "redis" {
  name                 = "${replace(var.cluster_name, "-", "")}-redis"
  location             = local.rg_location
  resource_group_name  = local.rg_name
  capacity             = var.redis_capacity
  family               = var.redis_family
  sku_name             = var.redis_sku_name
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"
}

# Storage Account and Blob Containers (4 containers - same as AWS S3/GCS)
resource "random_id" "storage_suffix" {
  byte_length = 4
}

resource "azurerm_storage_account" "main" {
  count                    = var.use_existing_storage_account ? 0 : 1
  name                     = lower(replace("${replace(var.cluster_name, "-", "")}${random_id.storage_suffix.hex}", "-", ""))
  resource_group_name      = local.rg_name
  location                 = local.rg_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "file_manager" {
  count                 = var.use_existing_storage_account ? 0 : 1
  name                  = "file-manager"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

resource "azurerm_storage_container" "agent_avatars" {
  count                 = var.use_existing_storage_account ? 0 : 1
  name                  = "agent-avatars"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logos" {
  count                 = var.use_existing_storage_account ? 0 : 1
  name                  = "logos"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

resource "azurerm_storage_container" "rag" {
  count                 = var.use_existing_storage_account ? 0 : 1
  name                  = "rag"
  storage_account_name  = azurerm_storage_account.main[0].name
  container_access_type = "private"
}

locals {
  storage_account_name = var.use_existing_storage_account ? var.storage_account_name : azurerm_storage_account.main[0].name
  blob_file_manager    = var.use_existing_storage_account ? "file-manager" : azurerm_storage_container.file_manager[0].name
  blob_agent_avatars   = var.use_existing_storage_account ? "agent-avatars" : azurerm_storage_container.agent_avatars[0].name
  blob_logos           = var.use_existing_storage_account ? "logos" : azurerm_storage_container.logos[0].name
  blob_rag             = var.use_existing_storage_account ? "rag" : azurerm_storage_container.rag[0].name
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = local.rg_location
  resource_group_name = local.rg_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.cluster_version

  default_node_pool {
    name                 = "default"
    vm_size              = var.node_pool_vm_size
    vnet_subnet_id       = azurerm_subnet.aks.id
    auto_scaling_enabled = true
    min_count            = var.node_pool_min_count
    max_count            = var.node_pool_max_count
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
}

# Wait for cluster to be ready
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [azurerm_kubernetes_cluster.main]
  create_duration = "30s"
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  }
}

# Kubernetes Namespace
resource "kubernetes_namespace" "sligo" {
  metadata {
    name   = "sligo"
    labels = { app = "sligo-cloud" }
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

# Application Secrets (same structure as AWS/GCP)
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
    REDIS_URL                      = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
    BACKEND_URL                    = "http://sligo-backend:3001"
    MCP_GATEWAY_URL                = "http://mcp-gateway:3002"
    DATABASE_URL                   = "postgresql://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.sligo.name}?sslmode=require"
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
    BUCKET_NAME_AGENT_AVATARS      = local.blob_agent_avatars
    BUCKET_NAME_FILE_MANAGER       = local.blob_file_manager
    BUCKET_NAME_LOGOS              = local.blob_logos
    BUCKET_NAME_RAG                = local.blob_rag
    NODE_ENV                       = "production"
    SKIP_ENV_VALIDATION            = "true"
    AZURE_STORAGE_ACCOUNT_NAME     = local.storage_account_name
    AZURE_STORAGE_ACCOUNT_KEY      = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
    GOOGLE_PROJECTID               = var.google_project_id != "" ? var.google_project_id : ""
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
    DATABASE_URL                         = "postgresql://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.sligo.name}?sslmode=require"
    REDIS_URL                            = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
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
    BUCKET_NAME_FILE_MANAGER             = local.blob_file_manager
    NODE_ENV                             = "production"
    SKIP_ENV_VALIDATION                  = "true"
    AZURE_STORAGE_ACCOUNT_NAME           = local.storage_account_name
    AZURE_STORAGE_ACCOUNT_KEY            = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
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
    BUCKET_NAME_FILE_MANAGER     = local.blob_file_manager
    REDIS_URL                    = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
    REDIS_URL_STRUCTURED_OUTPUTS = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
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
    AZURE_STORAGE_ACCOUNT_NAME   = local.storage_account_name
    AZURE_STORAGE_ACCOUNT_KEY    = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
    GOOGLE_PROJECTID             = var.google_project_id != "" ? var.google_project_id : ""
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {})
}

resource "kubernetes_secret" "database_secret" {
  metadata {
    name      = "database-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  data = {
    host     = azurerm_postgresql_flexible_server.postgres.fqdn
    port     = "5432"
    database = azurerm_postgresql_flexible_server_database.sligo.name
    username = var.db_username
    password = var.db_password
  }
}

resource "kubernetes_secret" "redis_secret" {
  metadata {
    name      = "redis-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  data = {
    host     = azurerm_redis_cache.redis.hostname
    port     = tostring(azurerm_redis_cache.redis.ssl_port)
    password = azurerm_redis_cache.redis.primary_access_key
  }
}

resource "kubernetes_secret" "blob_secret" {
  metadata {
    name      = "blob-storage-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  data = {
    storage_account_name    = local.storage_account_name
    storage_account_key     = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
    container_file_manager  = local.blob_file_manager
    container_agent_avatars = local.blob_agent_avatars
    container_logos         = local.blob_logos
    container_rag           = local.blob_rag
  }
}

# Nginx Ingress Controller (required for AKS - no built-in L7 ingress like GKE)
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "4.8.3"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [time_sleep.wait_for_cluster]
}

# Helm Release for Sligo Cloud
resource "helm_release" "sligo_cloud" {
  name       = "sligo-cloud"
  repository = "https://sligo-ai.github.io/sligo-helm-charts"
  chart      = "sligo-cloud"
  version    = var.app_version
  namespace  = kubernetes_namespace.sligo.metadata[0].name
  timeout    = 600

  values = [
    yamlencode({
      global = {
        imagePullSecrets = [kubernetes_secret.gar_pull_secret.metadata[0].name]
      }
      ingress = {
        enabled   = true
        className = "nginx"
        annotations = {
          "kubernetes.io/ingress.class" = "nginx"
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
          requests = { cpu = "500m", memory = "1Gi" }
          limits   = { cpu = "1000m", memory = "2Gi" }
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
          requests = { cpu = "1000m", memory = "2Gi" }
          limits   = { cpu = "2000m", memory = "4Gi" }
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
          requests = { cpu = "500m", memory = "1Gi" }
          limits   = { cpu = "1000m", memory = "2Gi" }
        }
      }
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
          host       = azurerm_postgresql_flexible_server.postgres.fqdn
          port       = 5432
          database   = azurerm_postgresql_flexible_server_database.sligo.name
          secretName = kubernetes_secret.database_secret.metadata[0].name
        }
      }
      redis = {
        enabled = true
        type    = "external"
        external = {
          host       = azurerm_redis_cache.redis.hostname
          port       = azurerm_redis_cache.redis.ssl_port
          secretName = kubernetes_secret.redis_secret.metadata[0].name
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster,
    helm_release.nginx_ingress,
    kubernetes_secret.gar_pull_secret,
    kubernetes_secret.nextjs_secrets,
    kubernetes_secret.backend_secrets,
    kubernetes_secret.mcp_gateway_secrets,
    kubernetes_secret.database_secret,
    kubernetes_secret.redis_secret
  ]
}
