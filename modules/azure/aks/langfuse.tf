locals {
  langfuse_enabled     = var.enable_langfuse
  langfuse_self_hosted = var.enable_langfuse && var.langfuse_self_hosted
  langfuse_domain      = var.langfuse_domain_name != "" ? var.langfuse_domain_name : "langfuse.${var.domain_name}"
  langfuse_db_user     = var.langfuse_db_username != "" ? var.langfuse_db_username : var.db_username
  langfuse_db_password = var.langfuse_db_password != "" ? var.langfuse_db_password : var.db_password
  langfuse_db_host     = azurerm_postgresql_flexible_server.postgres.fqdn
  langfuse_init_email = (
    var.langfuse_init_user_email != "" ? var.langfuse_init_user_email : "langfuse-admin@${var.domain_name}"
  )
  langfuse_public_key_effective    = local.langfuse_self_hosted ? "lf_pk_${random_id.langfuse_pk[0].hex}" : var.langfuse_public_key
  langfuse_secret_key_effective    = local.langfuse_self_hosted ? "lf_sk_${random_id.langfuse_sk[0].hex}" : (var.langfuse_secret_key != "" ? var.langfuse_secret_key : "")
  langfuse_base_url_effective      = local.langfuse_self_hosted ? "http://langfuse-web:3000" : var.langfuse_base_url
  observability_provider_effective = local.langfuse_self_hosted ? "langfuse" : var.observability_provider
  langfuse_storage_key             = var.use_existing_storage_account ? var.azure_storage_account_key : azurerm_storage_account.main[0].primary_access_key

  langfuse_ui_env = local.langfuse_self_hosted && var.langfuse_web_enabled ? {
    LANGFUSE_UI_URL             = "https://${local.langfuse_domain}"
    LANGFUSE_INIT_USER_EMAIL    = local.langfuse_init_email
    LANGFUSE_INIT_USER_PASSWORD = random_password.langfuse_init_user[0].result
  } : {}

  langfuse_ingress_hosts = local.langfuse_self_hosted && var.langfuse_web_enabled ? [
    {
      host = local.langfuse_domain
      paths = [
        {
          path     = "/"
          pathType = "Prefix"
          backend  = "langfuse"
        }
      ]
    }
  ] : []

  langfuse_helm_values = {
    langfuse = {
      enabled    = local.langfuse_enabled
      selfHosted = local.langfuse_self_hosted
      uiUrl      = local.langfuse_self_hosted && var.langfuse_web_enabled ? "https://${local.langfuse_domain}" : ""
      baseUrl    = local.langfuse_self_hosted ? "http://langfuse-web:3000" : var.langfuse_base_url
      web = {
        enabled = local.langfuse_self_hosted && var.langfuse_web_enabled
      }
    }
  }

  langfuse_self_hosted_helm_values = {
    "langfuse-server" = {
      langfuse = {
        nextauth = {
          url = "https://${local.langfuse_domain}"
          secret = {
            secretKeyRef = {
              name = "langfuse-general"
              key  = "nextauth-secret"
            }
          }
        }
        salt = {
          secretKeyRef = {
            name = "langfuse-general"
            key  = "salt"
          }
        }
        encryptionKey = {
          secretKeyRef = {
            name = "langfuse-general"
            key  = "encryption-key"
          }
        }
        additionalEnv = [
          { name = "LANGFUSE_INIT_ORG_ID", value = var.langfuse_init_org_id },
          { name = "LANGFUSE_INIT_ORG_NAME", value = "Sligo" },
          { name = "LANGFUSE_INIT_PROJECT_ID", value = var.langfuse_init_project_id },
          { name = "LANGFUSE_INIT_PROJECT_NAME", value = "Sligo" },
          { name = "LANGFUSE_INIT_PROJECT_PUBLIC_KEY", value = local.langfuse_public_key_effective },
          { name = "LANGFUSE_INIT_PROJECT_SECRET_KEY", value = local.langfuse_secret_key_effective },
          { name = "LANGFUSE_INIT_USER_EMAIL", value = local.langfuse_init_email },
          { name = "LANGFUSE_INIT_USER_NAME", value = "Langfuse Admin" },
          { name = "LANGFUSE_INIT_USER_PASSWORD", value = random_password.langfuse_init_user[0].result }
        ]
      }
      postgresql = {
        deploy = false
        host   = local.langfuse_db_host
        auth = {
          username       = local.langfuse_db_user
          existingSecret = "langfuse-db-credentials"
          secretKeys = {
            userPasswordKey = "password"
          }
          database = var.langfuse_db_name
        }
      }
      redis = {
        dataStorage = {
          className = var.langfuse_storage_class
          keepPvc   = true
        }
      }
      clickhouse = {
        auth = {
          existingSecret    = "langfuse-clickhouse-auth"
          existingSecretKey = "password"
        }
        cluster = {
          replicas = var.langfuse_clickhouse_replicas
          storage = {
            className = var.langfuse_storage_class
            size      = "100Gi"
          }
        }
        keeper = {
          replicas = var.langfuse_keeper_replicas
          storage = {
            className = var.langfuse_storage_class
            size      = "20Gi"
          }
        }
      }
      s3 = {
        deploy          = false
        storageProvider = "azure"
        bucket          = "langfuse"
        endpoint        = "https://${local.storage_account_name}.blob.core.windows.net"
        accessKeyId = {
          value = local.storage_account_name
        }
        secretAccessKey = {
          secretKeyRef = {
            name = "langfuse-azure-auth"
            key  = "accountKey"
          }
        }
      }
    }
  }
}

resource "random_id" "langfuse_pk" {
  count       = local.langfuse_self_hosted ? 1 : 0
  byte_length = 16
}

resource "random_id" "langfuse_sk" {
  count       = local.langfuse_self_hosted ? 1 : 0
  byte_length = 24
}

resource "random_password" "langfuse_init_user" {
  count   = local.langfuse_self_hosted ? 1 : 0
  length  = 32
  special = true
}

resource "random_password" "langfuse_nextauth" {
  count   = local.langfuse_self_hosted ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "langfuse_salt" {
  count   = local.langfuse_self_hosted ? 1 : 0
  length  = 32
  special = false
}

resource "random_id" "langfuse_encryption" {
  count       = local.langfuse_self_hosted ? 1 : 0
  byte_length = 32
}

resource "random_password" "langfuse_clickhouse" {
  count   = local.langfuse_self_hosted ? 1 : 0
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server_database" "langfuse" {
  count     = local.langfuse_self_hosted ? 1 : 0
  name      = var.langfuse_db_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_storage_container" "langfuse" {
  count                 = local.langfuse_self_hosted ? 1 : 0
  name                  = "langfuse"
  storage_account_name  = local.storage_account_name
  container_access_type = "private"
}

resource "kubernetes_secret" "langfuse_db_credentials" {
  count = local.langfuse_self_hosted ? 1 : 0

  metadata {
    name      = "langfuse-db-credentials"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    host     = local.langfuse_db_host
    port     = "5432"
    database = var.langfuse_db_name
    username = local.langfuse_db_user
    password = local.langfuse_db_password
  }
}

resource "kubernetes_secret" "langfuse_general" {
  count = local.langfuse_self_hosted ? 1 : 0

  metadata {
    name      = "langfuse-general"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    salt            = random_password.langfuse_salt[0].result
    nextauth-secret = random_password.langfuse_nextauth[0].result
    encryption-key  = random_id.langfuse_encryption[0].hex
  }
}

resource "kubernetes_secret" "langfuse_clickhouse_auth" {
  count = local.langfuse_self_hosted ? 1 : 0

  metadata {
    name      = "langfuse-clickhouse-auth"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    password = random_password.langfuse_clickhouse[0].result
  }
}

resource "kubernetes_secret" "langfuse_azure_auth" {
  count = local.langfuse_self_hosted ? 1 : 0

  metadata {
    name      = "langfuse-azure-auth"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    accountKey = local.langfuse_storage_key
  }
}

resource "helm_release" "cert_manager" {
  count            = local.langfuse_self_hosted && var.install_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.2"
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [time_sleep.wait_for_cluster]
}

resource "helm_release" "clickhouse_operator" {
  count            = local.langfuse_self_hosted && var.install_clickhouse_operator ? 1 : 0
  name             = "clickhouse-operator"
  chart            = "oci://ghcr.io/clickhouse/clickhouse-operator-helm"
  version          = "0.0.5"
  namespace        = "clickhouse-operator"
  create_namespace = true
  timeout          = 600

  depends_on = [
    time_sleep.wait_for_cluster,
    helm_release.cert_manager,
  ]
}

check "langfuse_cloud_config" {
  assert {
    condition = (
      !local.langfuse_enabled ||
      local.langfuse_self_hosted ||
      (var.langfuse_base_url != "" && var.langfuse_public_key != "" && var.langfuse_secret_key != "")
    )
    error_message = "When enable_langfuse=true and langfuse_self_hosted=false, set langfuse_base_url, langfuse_public_key, and langfuse_secret_key."
  }
}
