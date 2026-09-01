locals {
  temporal_enabled          = var.enable_temporal
  temporal_self_hosted      = var.enable_temporal && var.temporal_self_hosted
  temporal_db_user          = var.temporal_db_username != "" ? var.temporal_db_username : var.db_username
  temporal_db_password      = var.temporal_db_password != "" ? var.temporal_db_password : var.db_password
  temporal_db_host          = azurerm_postgresql_flexible_server.postgres.fqdn
  temporal_sql_connect_addr = "${local.temporal_db_host}:5432"

  temporal_frontend_address = local.temporal_self_hosted ? "temporal-frontend:7233" : var.temporal_frontend_address
  temporal_tls_value = (
    var.temporal_tls != "" ? var.temporal_tls : (local.temporal_self_hosted ? "false" : "true")
  )

  temporal_client_env = local.temporal_enabled ? merge(
    {
      TEMPORAL_ADDRESS    = local.temporal_frontend_address
      TEMPORAL_NAMESPACE  = var.temporal_namespace
      TEMPORAL_TASK_QUEUE = var.temporal_task_queue
      TEMPORAL_TLS        = local.temporal_tls_value
    },
    var.temporal_api_key != "" ? { TEMPORAL_API_KEY = var.temporal_api_key } : {}
  ) : {}

  temporal_db_secret_data = {
    host     = local.temporal_db_host
    port     = "5432"
    database = var.temporal_db_name
    username = local.temporal_db_user
    password = local.temporal_db_password
  }

  temporal_visibility_db_secret_data = {
    host     = local.temporal_db_host
    port     = "5432"
    database = var.temporal_visibility_db_name
    username = local.temporal_db_user
    password = local.temporal_db_password
  }

  temporal_helm_values = {
    temporal = {
      enabled         = local.temporal_enabled
      selfHosted      = local.temporal_self_hosted
      type            = "external"
      frontendAddress = local.temporal_frontend_address
      namespace       = var.temporal_namespace
      taskQueue       = var.temporal_task_queue
      web = {
        enabled = local.temporal_self_hosted && var.temporal_web_enabled
      }
    }
    temporalWorker = {
      enabled      = local.temporal_enabled
      replicaCount = local.temporal_enabled ? 2 : 0
      image = {
        repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-temporal-worker"
        tag        = var.app_version
        pullPolicy = "Always"
      }
      secretName = local.backend_secret_name
    }
    temporal-server = {
      server = {
        config = {
          persistence = {
            numHistoryShards = var.temporal_history_shard_count
            datastores = {
              default = {
                sql = {
                  host        = local.temporal_db_host
                  connectAddr = local.temporal_sql_connect_addr
                  user        = local.temporal_db_user
                }
              }
              visibility = {
                sql = {
                  host        = local.temporal_db_host
                  connectAddr = local.temporal_sql_connect_addr
                  user        = local.temporal_db_user
                }
              }
            }
          }
        }
        # Subchart namespace Job races frontend. sligo-cloud 1.2.4+ creates
        # var.temporal_namespace via post-install Job.
        namespaces = {
          create    = false
          namespace = []
        }
      }
      web = {
        enabled = local.temporal_self_hosted && var.temporal_web_enabled
      }
    }
  }

  # Applied as an extra Helm values document only when self-hosted, because a
  # conditional object with attributes absent from the other branch fails
  # Terraform type unification.
  temporal_self_hosted_helm_values = {
    temporal = {
      webAddress = "http://temporal-web:8080"
      persistence = {
        host = local.temporal_db_host
        port = 5432
        user = local.temporal_db_user
      }
    }
  }
}

check "temporal_cloud_config" {
  assert {
    condition = (
      !local.temporal_enabled ||
      local.temporal_self_hosted ||
      (var.temporal_frontend_address != "" && var.temporal_api_key != "")
    )
    error_message = "When enable_temporal=true and temporal_self_hosted=false (Temporal Cloud), set temporal_frontend_address and temporal_api_key."
  }
}

resource "azurerm_postgresql_flexible_server_database" "temporal" {
  count     = local.temporal_self_hosted ? 1 : 0
  name      = var.temporal_db_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_database" "temporal_visibility" {
  count     = local.temporal_self_hosted ? 1 : 0
  name      = var.temporal_visibility_db_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "kubernetes_secret" "temporal_db_credentials" {
  count = local.temporal_self_hosted ? 1 : 0

  metadata {
    name      = "temporal-db-credentials"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = local.temporal_db_secret_data
}

resource "kubernetes_secret" "temporal_visibility_db_credentials" {
  count = local.temporal_self_hosted ? 1 : 0

  metadata {
    name      = "temporal-visibility-db-credentials"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = local.temporal_visibility_db_secret_data
}
