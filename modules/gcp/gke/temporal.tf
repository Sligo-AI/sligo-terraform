locals {
  temporal_enabled     = var.enable_temporal
  temporal_db_user     = var.temporal_db_username != "" ? var.temporal_db_username : var.db_username
  temporal_db_password = var.temporal_db_password != "" ? var.temporal_db_password : var.db_password
  temporal_db_host     = google_sql_database_instance.postgres.private_ip_address

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
      enabled    = local.temporal_enabled
      selfHosted = local.temporal_enabled
      namespace  = var.temporal_namespace
      taskQueue  = var.temporal_task_queue
      webAddress = "http://temporal-web:8080"
      web = {
        enabled = local.temporal_enabled && var.temporal_web_enabled
      }
      persistence = {
        host = local.temporal_db_host
        port = 5432
        user = local.temporal_db_user
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
          create = local.temporal_enabled
          namespace = local.temporal_enabled ? [
            {
              name      = var.temporal_namespace
              retention = "720h"
            }
          ] : []
        }
      }
      web = {
        enabled = local.temporal_enabled && var.temporal_web_enabled
      }
    }
  }
}

resource "google_sql_database" "temporal" {
  count    = local.temporal_enabled ? 1 : 0
  name     = var.temporal_db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.gcp_project_id
}

resource "google_sql_database" "temporal_visibility" {
  count    = local.temporal_enabled ? 1 : 0
  name     = var.temporal_visibility_db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.gcp_project_id
}

resource "kubernetes_secret" "temporal_db_credentials" {
  count = local.temporal_enabled ? 1 : 0

  metadata {
    name      = "temporal-db-credentials"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = local.temporal_db_secret_data
}

resource "kubernetes_secret" "temporal_visibility_db_credentials" {
  count = local.temporal_enabled ? 1 : 0

  metadata {
    name      = "temporal-visibility-db-credentials"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = local.temporal_visibility_db_secret_data
}
