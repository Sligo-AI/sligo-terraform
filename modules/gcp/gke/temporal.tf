locals {
  temporal_enabled = var.enable_temporal
  # Self-hosted server (Postgres DBs + temporal-server subchart). Independent of the
  # Sligo worker: set temporal_self_hosted=false to run against Temporal Cloud.
  temporal_self_hosted = var.enable_temporal && var.temporal_self_hosted
  temporal_db_user     = var.temporal_db_username != "" ? var.temporal_db_username : var.db_username
  temporal_db_password = var.temporal_db_password != "" ? var.temporal_db_password : var.db_password
  temporal_db_host     = google_sql_database_instance.postgres.private_ip_address

  temporal_frontend_address = local.temporal_self_hosted ? "temporal-frontend:7233" : var.temporal_frontend_address
  temporal_tls_value = (
    var.temporal_tls != "" ? var.temporal_tls : (local.temporal_self_hosted ? "false" : "true")
  )

  # Injected into nextjs / backend / mcp-gateway secrets (worker reuses backend-secrets).
  # Helm may still override ADDRESS / NAMESPACE / TASK_QUEUE when temporal.enabled is true.
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
                  host = local.temporal_db_host
                  user = local.temporal_db_user
                }
              }
              visibility = {
                sql = {
                  host = local.temporal_db_host
                  user = local.temporal_db_user
                }
              }
            }
          }
        }
        namespaces = {
          create = local.temporal_self_hosted
          namespace = local.temporal_self_hosted ? [
            {
              name      = var.temporal_namespace
              retention = "720h"
            }
          ] : []
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

resource "google_sql_database" "temporal" {
  count    = local.temporal_self_hosted ? 1 : 0
  name     = var.temporal_db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.gcp_project_id
}

resource "google_sql_database" "temporal_visibility" {
  count    = local.temporal_self_hosted ? 1 : 0
  name     = var.temporal_visibility_db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.gcp_project_id
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
