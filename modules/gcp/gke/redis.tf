# Redis backends (mutually exclusive with redis_url vs Memorystore):
# - in-cluster Redis Stack (Helm) — default
# - Memorystore for Redis Cluster (PSC) — use_memorystore_redis_cluster=true
# - external URL (Redis Cloud, etc.) — redis_url set
#
# Memorystore for Redis Cluster 8.0+ provides RedisJSON-compatible JSON commands.
# The app must use a cluster-aware client (REDIS_CLUSTER_MODE=true). A standalone
# REDIS_URL client will not work correctly against the discovery endpoint.
#
# Durability on google provider 5.x is replica_count (HA). AOF/RDB persistence_config
# requires google provider 6+ and is not set here.

locals {
  use_external_redis = trimspace(var.redis_url) != ""
  use_memorystore    = var.use_memorystore_redis_cluster
  use_internal_redis = !local.use_external_redis && !local.use_memorystore
  redis_cluster_mode = local.use_memorystore ? "true" : "false"
  memorystore_tls    = var.memorystore_transit_encryption_mode == "TRANSIT_ENCRYPTION_MODE_SERVER_AUTHENTICATION"
  memorystore_host   = local.use_memorystore ? google_redis_cluster.sligo[0].discovery_endpoints[0].address : ""
  memorystore_port   = local.use_memorystore ? google_redis_cluster.sligo[0].discovery_endpoints[0].port : 0
  memorystore_scheme = local.memorystore_tls ? "rediss" : "redis"
  redis_url = local.use_external_redis ? trimspace(var.redis_url) : (
    local.use_memorystore
    ? "${local.memorystore_scheme}://${local.memorystore_host}:${local.memorystore_port}"
    : "redis://redis.${kubernetes_namespace.sligo.metadata[0].name}.svc.cluster.local:6379"
  )
  redis_cluster_env = local.use_memorystore ? {
    REDIS_DISCOVERY_HOST = local.memorystore_host
    REDIS_DISCOVERY_PORT = tostring(local.memorystore_port)
  } : {}

  # Single object shape for Helm (Terraform rejects mismatched conditional branch types).
  redis_helm_values = {
    enabled = local.use_internal_redis
    type    = local.use_internal_redis ? "internal" : "external"
    internal = {
      persistence = {
        enabled      = local.use_internal_redis
        size         = var.redis_persistence_size
        storageClass = var.redis_persistence_storage_class
      }
    }
  }

  memorystore_cluster_id = substr(replace("${var.cluster_name}-redis", "_", "-"), 0, 63)
}

resource "null_resource" "redis_backend_guard" {
  triggers = {
    redis_url   = trimspace(var.redis_url) != "" ? "external" : "unset"
    memorystore = tostring(var.use_memorystore_redis_cluster)
  }

  lifecycle {
    precondition {
      condition     = !(trimspace(var.redis_url) != "" && var.use_memorystore_redis_cluster)
      error_message = "Set redis_url or use_memorystore_redis_cluster, not both."
    }
  }
}

# One Service Connection Policy per VPC + region + service class. Skip when the
# client already created gcp-memorystore-redis on this network.
resource "google_network_connectivity_service_connection_policy" "memorystore" {
  count         = local.use_memorystore && !var.use_existing_memorystore_connection_policy ? 1 : 0
  name          = "${var.cluster_name}-memorystore-redis"
  location      = var.gcp_region
  service_class = "gcp-memorystore-redis"
  description   = "PSC policy for Memorystore Redis Cluster (${var.cluster_name})"
  network       = local.network_id
  project       = var.gcp_project_id

  psc_config {
    subnetworks = [local.subnet_id]
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_redis_cluster" "sligo" {
  count         = local.use_memorystore ? 1 : 0
  name          = local.memorystore_cluster_id
  region        = var.gcp_region
  project       = var.gcp_project_id
  shard_count   = var.memorystore_shard_count
  replica_count = var.memorystore_replica_count
  node_type     = var.memorystore_node_type

  authorization_mode      = var.memorystore_authorization_mode
  transit_encryption_mode = var.memorystore_transit_encryption_mode

  psc_configs {
    network = local.network_id
  }

  zone_distribution_config {
    mode = "MULTI_ZONE"
  }

  depends_on = [
    google_project_service.required_apis,
    google_network_connectivity_service_connection_policy.memorystore,
  ]
}
