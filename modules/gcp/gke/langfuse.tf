locals {
  langfuse_enabled      = var.enable_langfuse
  langfuse_self_hosted  = var.enable_langfuse && var.langfuse_self_hosted
  langfuse_ui_upstream  = "http://langfuse-web:3000"
  langfuse_sdk_base     = "${local.langfuse_ui_upstream}/super-admin/langfuse"
  langfuse_nextauth_url = "${trimsuffix(var.frontend_url, "/")}/super-admin/langfuse/api/auth"
  langfuse_db_user      = var.langfuse_db_username != "" ? var.langfuse_db_username : var.db_username
  langfuse_db_password  = var.langfuse_db_password != "" ? var.langfuse_db_password : var.db_password
  langfuse_db_host      = google_sql_database_instance.postgres.private_ip_address
  langfuse_init_email = (
    var.langfuse_init_user_email != "" ? var.langfuse_init_user_email : "langfuse-admin@${var.domain_name}"
  )
  # try(): this local is always evaluated; the password resource has count=0 when Langfuse is off.
  langfuse_init_user_password      = try(random_password.langfuse_init_user[0].result, "")
  langfuse_public_key_effective    = local.langfuse_self_hosted ? "lf_pk_${random_id.langfuse_pk[0].hex}" : var.langfuse_public_key
  langfuse_secret_key_effective    = local.langfuse_self_hosted ? "lf_sk_${random_id.langfuse_sk[0].hex}" : (var.langfuse_secret_key != "" ? var.langfuse_secret_key : "")
  langfuse_base_url_effective      = local.langfuse_self_hosted ? local.langfuse_sdk_base : var.langfuse_base_url
  observability_provider_effective = local.langfuse_self_hosted ? "langfuse" : var.observability_provider
  # Langfuse Helm concatenates postgresql://user:password@host without encoding.
  # Passwords with /, +, = (etc.) make Prisma report P1013 "invalid port number".
  langfuse_database_url = format(
    "postgresql://%s:%s@%s:5432/%s",
    urlencode(local.langfuse_db_user),
    urlencode(local.langfuse_db_password),
    local.langfuse_db_host,
    var.langfuse_db_name
  )
  langfuse_client_env = {
    LANGFUSE_BASE_URL      = local.langfuse_base_url_effective
    LANGFUSE_PUBLIC_KEY    = local.langfuse_public_key_effective
    LANGFUSE_SECRET_KEY    = local.langfuse_secret_key_effective
    OBSERVABILITY_PROVIDER = local.observability_provider_effective
  }

  langfuse_ui_env = local.langfuse_self_hosted && var.langfuse_web_enabled ? {
    LANGFUSE_UI_URL             = local.langfuse_ui_upstream
    LANGFUSE_INIT_USER_EMAIL    = local.langfuse_init_email
    LANGFUSE_INIT_USER_PASSWORD = local.langfuse_init_user_password
  } : {}

  langfuse_helm_values = {
    langfuse = {
      enabled    = local.langfuse_enabled
      selfHosted = local.langfuse_self_hosted
      uiUrl      = local.langfuse_self_hosted && var.langfuse_web_enabled ? local.langfuse_ui_upstream : ""
      baseUrl    = local.langfuse_self_hosted ? local.langfuse_sdk_base : var.langfuse_base_url
      web = {
        enabled = local.langfuse_self_hosted && var.langfuse_web_enabled
      }
    }
  }

  langfuse_self_hosted_helm_values = {
    "langfuse-server" = {
      langfuse = {
        nextauth = {
          url = local.langfuse_nextauth_url
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
          { name = "DATABASE_URL", value = local.langfuse_database_url },
          { name = "DIRECT_URL", value = local.langfuse_database_url },
          { name = "REDIS_PORT", value = "6379" },
          { name = "LANGFUSE_INIT_ORG_ID", value = var.langfuse_init_org_id },
          { name = "LANGFUSE_INIT_ORG_NAME", value = "Sligo" },
          { name = "LANGFUSE_INIT_PROJECT_ID", value = var.langfuse_init_project_id },
          { name = "LANGFUSE_INIT_PROJECT_NAME", value = "Sligo" },
          { name = "LANGFUSE_INIT_PROJECT_PUBLIC_KEY", value = local.langfuse_public_key_effective },
          { name = "LANGFUSE_INIT_PROJECT_SECRET_KEY", value = local.langfuse_secret_key_effective },
          { name = "LANGFUSE_INIT_USER_EMAIL", value = local.langfuse_init_email },
          { name = "LANGFUSE_INIT_USER_NAME", value = "Langfuse Admin" },
          { name = "LANGFUSE_INIT_USER_PASSWORD", value = local.langfuse_init_user_password }
        ]
        image = {
          pullSecrets = [
            { name = "gar-pull-secret" }
          ]
        }
        web = {
          image = {
            repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-langfuse-web"
            tag        = "4.24.0"
          }
          service = {
            type = "ClusterIP"
          }
          livenessProbe = {
            path = "/super-admin/langfuse/api/public/health"
          }
          readinessProbe = {
            path = "/super-admin/langfuse/api/public/ready"
          }
        }
        serviceAccount = {
          create = false
          name   = "langfuse-gcs"
        }
      }
      postgresql = {
        deploy = false
        host   = local.langfuse_db_host
        port   = 5432
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
        deploy = true
        port   = 6379
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
        storageProvider = "gcs"
        bucket          = local.langfuse_gcs_bucket
      }
    }
  }

  langfuse_gcs_bucket = local.langfuse_self_hosted ? google_storage_bucket.langfuse[0].name : ""
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

resource "google_sql_database" "langfuse" {
  count    = local.langfuse_self_hosted ? 1 : 0
  name     = var.langfuse_db_name
  instance = google_sql_database_instance.postgres.name
  project  = var.gcp_project_id
}

resource "google_storage_bucket" "langfuse" {
  count         = local.langfuse_self_hosted ? 1 : 0
  name          = "${var.cluster_name}-langfuse-${random_id.bucket_suffix.hex}"
  location      = var.gcs_bucket_location
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.gcs_bucket_versioning
  }

  labels = {
    name        = "${var.cluster_name}-langfuse"
    environment = "production"
    purpose     = "langfuse"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_storage_bucket_iam_member" "langfuse_gcs_access" {
  count  = local.langfuse_self_hosted ? 1 : 0
  bucket = google_storage_bucket.langfuse[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs_access.email}"
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

resource "kubernetes_service_account" "langfuse_gcs" {
  count = local.langfuse_self_hosted ? 1 : 0

  metadata {
    name      = "langfuse-gcs"
    namespace = kubernetes_namespace.sligo.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gcs_access.email
    }
  }
}

resource "google_service_account_iam_member" "langfuse_gcs_workload_identity" {
  count              = local.langfuse_self_hosted ? 1 : 0
  service_account_id = google_service_account.gcs_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${kubernetes_namespace.sligo.metadata[0].name}/${kubernetes_service_account.langfuse_gcs[0].metadata[0].name}]"
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
