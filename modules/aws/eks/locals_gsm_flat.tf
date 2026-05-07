# When callers pass gsm_flat (e.g. entire GSM JSON), non-empty scalar values override matching module variables.
# Infra keys (cluster_name, subnet_ids, …) are not in eff_defaults, so they are ignored here.
locals {
  eff_defaults = {
    db_username                          = var.db_username
    db_password                          = var.db_password
    storage_provider                     = var.storage_provider
    jwt_secret                           = var.jwt_secret
    api_key                              = var.api_key
    nextauth_secret                      = var.nextauth_secret
    gateway_secret                       = var.gateway_secret
    frontend_url                         = var.frontend_url
    next_public_api_url                  = var.next_public_api_url
    workos_api_key                       = var.workos_api_key
    workos_client_id                     = var.workos_client_id
    workos_cookie_password               = var.workos_cookie_password
    auth_provider                        = var.auth_provider
    auth_invitations                     = var.auth_invitations
    auth_session_secret                  = var.auth_session_secret
    oidc_issuer                          = var.oidc_issuer
    oidc_client_id                       = var.oidc_client_id
    oidc_client_secret                   = var.oidc_client_secret
    oidc_scopes                          = var.oidc_scopes
    oidc_default_org_id                  = var.oidc_default_org_id
    oidc_default_org_name                = var.oidc_default_org_name
    saml_entrypoint                      = var.saml_entrypoint
    saml_issuer                          = var.saml_issuer
    saml_cert                            = var.saml_cert
    saml_default_org_id                  = var.saml_default_org_id
    saml_default_org_name                = var.saml_default_org_name
    next_public_google_client_id         = var.next_public_google_client_id
    next_public_google_client_key        = var.next_public_google_client_key
    next_public_onedrive_client_id       = var.next_public_onedrive_client_id
    pinecone_api_key                     = var.pinecone_api_key
    pinecone_index                       = var.pinecone_index
    pinecone_environment                 = var.pinecone_environment
    rag_vector_store                     = var.rag_vector_store
    singlestore_host                     = var.singlestore_host
    singlestore_port                     = var.singlestore_port
    singlestore_user                     = var.singlestore_user
    singlestore_password                 = var.singlestore_password
    singlestore_database                 = var.singlestore_database
    auth_base_url                        = var.auth_base_url
    auth_cookie_name                     = var.auth_cookie_name
    auth_cookie_same_site                = var.auth_cookie_same_site
    sql_connection_string_decryption_iv  = var.sql_connection_string_decryption_iv
    sql_connection_string_decryption_key = var.sql_connection_string_decryption_key
    encryption_key                       = var.encryption_key
    google_project_id                    = var.google_project_id
    openai_api_key                       = var.openai_api_key
    together_ai_api_key                  = var.together_ai_api_key
    perplexity_api_key                   = var.perplexity_api_key
    tavily_api_key                       = var.tavily_api_key
    backend_api_key                      = var.backend_api_key
    azure_openai_api_key                 = var.azure_openai_api_key
    azure_openai_api_instance_name       = var.azure_openai_api_instance_name
    azure_openai_api_version             = var.azure_openai_api_version
    azure_openai_base_path               = var.azure_openai_base_path
    langsmith_api_key                    = var.langsmith_api_key
    langsmith_tracing                    = var.langsmith_tracing
    langsmith_project                    = var.langsmith_project
    langsmith_endpoint                   = var.langsmith_endpoint
    langfuse_base_url                    = var.langfuse_base_url
    langfuse_public_key                  = var.langfuse_public_key
    langfuse_secret_key                  = var.langfuse_secret_key
    langsmith_api_base_url               = var.langsmith_api_base_url
    observability_provider               = var.observability_provider
    node_env                             = var.node_env
    super_admin_emails                   = var.super_admin_emails
    openai_base_url                      = var.openai_base_url
    google_client_secret                 = var.google_client_secret
    rag_sa_key                           = var.rag_sa_key
    anthropic_api_key                    = var.anthropic_api_key
    gcp_sa_key                           = var.gcp_sa_key
    google_vertex_ai_web_credentials     = var.google_vertex_ai_web_credentials
    onedrive_client_secret               = var.onedrive_client_secret
    aws_access_key_id                    = var.aws_access_key_id
    aws_secret_access_key                = var.aws_secret_access_key
    spendhq_base_url                     = var.spendhq_base_url
    spendhq_client_id                    = var.spendhq_client_id
    spendhq_client_secret                = var.spendhq_client_secret
    spendhq_token_url                    = var.spendhq_token_url
    spendhq_ss_host                      = var.spendhq_ss_host
    spendhq_ss_username                  = var.spendhq_ss_username
    spendhq_ss_password                  = var.spendhq_ss_password
    spendhq_ss_port                      = var.spendhq_ss_port
    azure_aisearch_endpoint              = var.azure_aisearch_endpoint
    azure_aisearch_key                   = var.azure_aisearch_key
    azure_aisearch_index                 = var.azure_aisearch_index
    azure_aisearch_query_type            = var.azure_aisearch_query_type
    domain_name                          = var.domain_name
  }

  gsm_string_overrides = {
    for k, raw in try(var.gsm_flat, {}) :
    k => trimspace(try(tostring(raw), ""))
    if contains(keys(local.eff_defaults), k) && trimspace(try(tostring(raw), "")) != ""
  }

  eff_strings = merge(local.eff_defaults, local.gsm_string_overrides)

  gsm_verbose_raw = try(var.gsm_flat["verbose_logging"], null)
  effective_verbose_logging = (
    local.gsm_verbose_raw == null ? var.verbose_logging : try(
      tobool(local.gsm_verbose_raw),
      var.verbose_logging
    )
  )

  gsm_backend_timeout_raw = try(var.gsm_flat["backend_request_timeout_ms"], null)
  effective_backend_request_timeout_ms = (
    local.gsm_backend_timeout_raw == null ? var.backend_request_timeout_ms : try(
      tonumber(local.gsm_backend_timeout_raw),
      var.backend_request_timeout_ms
    )
  )
}
