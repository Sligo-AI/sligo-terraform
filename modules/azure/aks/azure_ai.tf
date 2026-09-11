# Optional Azure AI (OpenAI-compatible account) + Azure AI Search.
# Does not create model deployments or the Search index (app / LangChain does that).
# Mutually exclusive with BYO azure_openai_* / azure_aisearch_* credentials.

locals {
  create_azure_ai       = var.create_azure_ai
  create_azure_aisearch = var.create_azure_aisearch
  azure_ai_location     = trimspace(var.azure_ai_location) != "" ? var.azure_ai_location : local.rg_location

  azure_openai_key_effective      = local.create_azure_ai ? azurerm_cognitive_account.azure_ai[0].primary_access_key : var.azure_openai_api_key
  azure_openai_instance_effective = local.create_azure_ai ? azurerm_cognitive_account.azure_ai[0].custom_subdomain_name : var.azure_openai_api_instance_name
  azure_openai_enabled            = trimspace(local.azure_openai_key_effective) != ""

  azure_aisearch_name               = substr(lower(replace("${var.cluster_name}srch", "-", "")), 0, 60)
  azure_aisearch_endpoint_effective = local.create_azure_aisearch ? "https://${azurerm_search_service.sligo[0].name}.search.windows.net" : var.azure_aisearch_endpoint
  azure_aisearch_key_effective      = local.create_azure_aisearch ? azurerm_search_service.sligo[0].primary_key : var.azure_aisearch_key
  azure_aisearch_enabled            = trimspace(local.azure_aisearch_endpoint_effective) != ""

  azure_openai_env = local.azure_openai_enabled ? {
    AZURE_OPENAI_API_KEY           = local.azure_openai_key_effective
    AZURE_OPENAI_API_INSTANCE_NAME = local.azure_openai_instance_effective
    AZURE_OPENAI_API_VERSION       = var.azure_openai_api_version
    AZURE_OPENAI_BASE_PATH         = var.azure_openai_base_path
  } : {}

  azure_aisearch_env = local.azure_aisearch_enabled ? {
    RAG_VECTOR_STORE          = "azureaisearch"
    AZURE_AISEARCH_ENDPOINT   = local.azure_aisearch_endpoint_effective
    AZURE_AISEARCH_KEY        = local.azure_aisearch_key_effective != "" ? local.azure_aisearch_key_effective : "placeholder"
    AZURE_AISEARCH_INDEX      = var.azure_aisearch_index
    AZURE_AISEARCH_QUERY_TYPE = var.azure_aisearch_query_type
  } : {}
}

resource "null_resource" "azure_ai_guard" {
  triggers = {
    create_ai     = tostring(var.create_azure_ai)
    create_search = tostring(var.create_azure_aisearch)
    byo_ai        = trimspace(var.azure_openai_api_key) != "" ? "set" : "unset"
    byo_search    = trimspace(var.azure_aisearch_endpoint) != "" ? "set" : "unset"
  }

  lifecycle {
    precondition {
      condition     = !(var.create_azure_ai && trimspace(var.azure_openai_api_key) != "")
      error_message = "Set create_azure_ai or azure_openai_api_key, not both."
    }
    precondition {
      condition     = !(var.create_azure_aisearch && trimspace(var.azure_aisearch_endpoint) != "")
      error_message = "Set create_azure_aisearch or azure_aisearch_endpoint, not both."
    }
  }
}

resource "azurerm_cognitive_account" "azure_ai" {
  count                 = local.create_azure_ai ? 1 : 0
  name                  = substr(var.cluster_name, 0, 64)
  location              = local.azure_ai_location
  resource_group_name   = local.rg_name
  kind                  = "OpenAI"
  sku_name              = var.azure_ai_sku_name
  custom_subdomain_name = substr(lower("${replace(var.cluster_name, "_", "-")}-${random_id.storage_suffix.hex}"), 0, 64)

  public_network_access_enabled = var.azure_ai_public_network_access
  local_auth_enabled            = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_search_service" "sligo" {
  count                         = local.create_azure_aisearch ? 1 : 0
  name                          = local.azure_aisearch_name
  location                      = local.azure_ai_location
  resource_group_name           = local.rg_name
  sku                           = var.azure_aisearch_sku
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = var.azure_ai_public_network_access
  local_authentication_enabled  = true
}

resource "azurerm_private_dns_zone" "openai" {
  count               = local.create_azure_ai && !var.azure_ai_public_network_access ? 1 : 0
  name                = "privatelink.openai.azure.com"
  resource_group_name = local.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  count                 = local.create_azure_ai && !var.azure_ai_public_network_access ? 1 : 0
  name                  = "${var.cluster_name}-openai-dns-link"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.openai[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_endpoint" "openai" {
  count               = local.create_azure_ai && !var.azure_ai_public_network_access ? 1 : 0
  name                = "${var.cluster_name}-openai-pe"
  location            = local.azure_ai_location
  resource_group_name = local.rg_name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.cluster_name}-openai-psc"
    private_connection_resource_id = azurerm_cognitive_account.azure_ai[0].id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.openai[0].id]
  }
}

resource "azurerm_private_dns_zone" "search" {
  count               = local.create_azure_aisearch && !var.azure_ai_public_network_access ? 1 : 0
  name                = "privatelink.search.windows.net"
  resource_group_name = local.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "search" {
  count                 = local.create_azure_aisearch && !var.azure_ai_public_network_access ? 1 : 0
  name                  = "${var.cluster_name}-search-dns-link"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.search[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_private_endpoint" "search" {
  count               = local.create_azure_aisearch && !var.azure_ai_public_network_access ? 1 : 0
  name                = "${var.cluster_name}-search-pe"
  location            = local.azure_ai_location
  resource_group_name = local.rg_name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.cluster_name}-search-psc"
    private_connection_resource_id = azurerm_search_service.sligo[0].id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.search[0].id]
  }
}
