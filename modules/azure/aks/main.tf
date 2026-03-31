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

# Delegated subnet for PostgreSQL Flexible Server (required for VNet integration)
resource "azurerm_subnet" "postgres" {
  name                 = "${var.cluster_name}-pg-subnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "pg-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Subnet for private endpoints (Redis, etc.)
resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.cluster_name}-pe-subnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Private DNS zone for PostgreSQL Flexible Server name resolution within VNet
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = local.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.cluster_name}-pg-dns-link"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# PostgreSQL Flexible Server (Azure Database for PostgreSQL)
# Private VNet integration: accessible only from AKS cluster subnet, no public exposure
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "${replace(var.cluster_name, "-", "")}-pg"
  resource_group_name    = local.rg_name
  location               = local.rg_location
  version                = "15"
  administrator_login    = var.db_username
  administrator_password = var.db_password
  sku_name               = var.postgres_sku_name
  storage_mb             = var.postgres_storage_mb

  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
}

resource "azurerm_postgresql_flexible_server_database" "sligo" {
  name      = "sligo"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Azure Cache for Redis
# Private endpoint: accessible only from VNet, no public exposure
resource "azurerm_redis_cache" "redis" {
  name                          = "${replace(var.cluster_name, "-", "")}-redis"
  location                      = local.rg_location
  resource_group_name           = local.rg_name
  capacity                      = var.redis_capacity
  family                        = var.redis_family
  sku_name                      = var.redis_sku_name
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
}

# Private DNS zone for Redis name resolution within VNet
resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = local.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${var.cluster_name}-redis-dns-link"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_endpoint" "redis" {
  name                = "${var.cluster_name}-redis-pe"
  location            = local.rg_location
  resource_group_name = local.rg_name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.cluster_name}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }
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

  blob_properties {
    cors_rule {
      allowed_origins    = [var.frontend_url]
      allowed_methods    = ["GET", "HEAD", "PUT", "POST", "DELETE", "OPTIONS"]
      allowed_headers    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  # Restrict to VNet: deny public access, allow only AKS subnet
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }
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

locals {
  nextjs_secret_name      = "nextjs-secrets"
  backend_secret_name     = "backend-secrets"
  mcp_gateway_secret_name = "mcp-gateway-secrets"
  default_gsm_prefix      = "sligo-${replace(var.cluster_name, "_", "-")}-"
  gsm_secret_prefix       = var.secret_name_prefix != "" ? var.secret_name_prefix : local.default_gsm_prefix
  gsm_secret_ids          = { for name in var.secret_names : name => "${local.gsm_secret_prefix}${name}" }
}

resource "helm_release" "external_secrets" {
  count            = var.enable_external_secrets_operator ? 1 : 0
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.11"
  namespace        = "external-secrets"
  create_namespace = true

  depends_on = [time_sleep.wait_for_cluster]
}

resource "kubernetes_secret" "eso_gcp_sm_credentials" {
  count = var.enable_external_secrets_operator ? 1 : 0

  metadata {
    name      = "eso-gcp-sm-credentials"
    namespace = "external-secrets"
  }

  data = {
    "secret-access-credentials" = file(var.sligo_service_account_key_path)
  }

  depends_on = [helm_release.external_secrets]
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
            secretRef = {
              secretAccessKeySecretRef = {
                name      = "eso-gcp-sm-credentials"
                namespace = "external-secrets"
                key       = "secret-access-credentials"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.eso_gcp_sm_credentials]
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
        { secretKey = "ENCRYPTION_KEY", remoteRef = { key = local.gsm_secret_ids["encryption-key"] } }
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
        { secretKey = "ENCRYPTION_KEY", remoteRef = { key = local.gsm_secret_ids["encryption-key"] } }
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

# Application Secrets (same structure as AWS/GCP)
resource "kubernetes_secret" "nextjs_secrets" {
  count = var.use_eso_managed_app_secrets ? 0 : 1

  metadata {
    name      = "nextjs-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  data = merge({
    NEXT_PUBLIC_API_URL                                = var.next_public_api_url
    NEXT_PUBLIC_URL                                    = var.frontend_url
    FRONTEND_URL                                       = var.frontend_url
    NEXTAUTH_SECRET                                    = var.nextauth_secret
    PORT                                               = "3000"
    REDIS_URL                                          = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
    BACKEND_URL                                        = "http://sligo-backend:3001"
    MCP_GATEWAY_URL                                    = "http://mcp-gateway:3002"
    DATABASE_URL                                       = "postgresql://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.sligo.name}?sslmode=require"
    AUTH_PROVIDER                                      = var.auth_provider
    WORKOS_API_KEY                                     = var.workos_api_key != "" ? var.workos_api_key : "placeholder"
    WORKOS_CLIENT_ID                                   = var.workos_client_id != "" ? var.workos_client_id : "placeholder"
    WORKOS_COOKIE_PASSWORD                             = var.workos_cookie_password != "" ? var.workos_cookie_password : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_ID                       = var.next_public_google_client_id != "" ? var.next_public_google_client_id : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_KEY                      = var.next_public_google_client_key != "" ? var.next_public_google_client_key : "placeholder"
    NEXT_PUBLIC_ONEDRIVE_CLIENT_ID                     = var.next_public_onedrive_client_id != "" ? var.next_public_onedrive_client_id : "placeholder"
    PINECONE_API_KEY                                   = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX                                     = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    GOOGLE_CLIENT_SECRET                               = var.google_client_secret != "" ? var.google_client_secret : "placeholder"
    ONEDRIVE_CLIENT_SECRET                             = var.onedrive_client_secret != "" ? var.onedrive_client_secret : "placeholder"
    OPENAI_API_KEY                                     = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    ENCRYPTION_KEY                                     = var.encryption_key != "" ? var.encryption_key : "placeholder"
    BUCKET_NAME_AGENT_AVATARS                          = local.blob_agent_avatars
    BUCKET_NAME_FILE_MANAGER                           = local.blob_file_manager
    BUCKET_NAME_LOGOS                                  = local.blob_logos
    BUCKET_NAME_RAG                                    = local.blob_rag
    NODE_ENV                                           = "production"
    SKIP_ENV_VALIDATION                                = "true"
    AZURE_STORAGE_ACCOUNT_NAME                         = local.storage_account_name
    AZURE_STORAGE_ACCOUNT_KEY                          = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
    GOOGLE_PROJECTID                                   = var.google_project_id != "" ? var.google_project_id : ""
    }, var.storage_provider != "" ? { STORAGE_PROVIDER = var.storage_provider } : {}, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.rag_sa_key != "" ? { RAG_SA_KEY = var.rag_sa_key } : {}, var.auth_provider == "oidc" ? {
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
  } : {}, var.auth_base_url != "" ? { AUTH_BASE_URL = var.auth_base_url } : {}, var.auth_cookie_name != "" ? { AUTH_COOKIE_NAME = var.auth_cookie_name } : {})
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
    PORT                                               = "3001"
    DATABASE_URL                                       = "postgresql://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.sligo.name}?sslmode=require"
    REDIS_URL                                          = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
    MCP_GATEWAY_URL                                    = "http://mcp-gateway:3002"
    SQL_CONNECTION_STRING_DECRYPTION_IV                = var.sql_connection_string_decryption_iv != "" ? var.sql_connection_string_decryption_iv : "placeholder"
    SQL_CONNECTION_STRING_DECRYPTION_KEY               = var.sql_connection_string_decryption_key != "" ? var.sql_connection_string_decryption_key : "placeholder"
    ENCRYPTION_KEY                                     = var.encryption_key != "" ? var.encryption_key : "placeholder"
    OPENAI_API_KEY                                     = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    OPENAI_BASE_URL                                    = var.openai_base_url
    ANTHROPIC_API_KEY                                  = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    VERBOSE_LOGGING                                    = tostring(var.verbose_logging)
    BACKEND_REQUEST_TIMEOUT_MS                         = tostring(var.backend_request_timeout_ms)
    LANGSMITH_API_KEY                                  = var.langsmith_api_key != "" ? var.langsmith_api_key : ""
    BUCKET_NAME_FILE_MANAGER                           = local.blob_file_manager
    NODE_ENV                                           = "production"
    SKIP_ENV_VALIDATION                                = "true"
    AZURE_STORAGE_ACCOUNT_NAME                         = local.storage_account_name
    AZURE_STORAGE_ACCOUNT_KEY                          = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
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
    BUCKET_NAME_FILE_MANAGER                           = local.blob_file_manager
    REDIS_URL                                          = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
    REDIS_URL_STRUCTURED_OUTPUTS                       = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}"
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
    AZURE_STORAGE_ACCOUNT_NAME                         = local.storage_account_name
    AZURE_STORAGE_ACCOUNT_KEY                          = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key
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
        secretName = local.nextjs_secret_name
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
        secretName = local.backend_secret_name
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
        secretName = local.mcp_gateway_secret_name
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
        secretName = local.backend_secret_name
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
    kubernetes_secret.redis_secret,
    kubernetes_manifest.external_secret_nextjs,
    kubernetes_manifest.external_secret_backend,
    kubernetes_manifest.external_secret_mcp_gateway,
  ]
}
