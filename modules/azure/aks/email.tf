# Email provider wiring. Env vars follow the app contract:
# EMAIL_PROVIDER (postmark|ses), EMAIL_FROM, EMAIL_INBOUND_DOMAIN,
# POSTMARK_SERVER_TOKEN, AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for SES.
# No email env is injected until credentials are configured.
locals {
  email_configured = var.email_provider == "ses" ? (var.ses_access_key_id != "" && var.ses_secret_access_key != "") : var.postmark_server_token != ""

  email_env = local.email_configured ? merge(
    { EMAIL_PROVIDER = var.email_provider },
    var.email_from != "" ? {
      EMAIL_FROM               = var.email_from
      EMAIL_FROM_TRANSACTIONAL = var.email_from
    } : {},
    var.email_inbound_domain != "" ? { EMAIL_INBOUND_DOMAIN = var.email_inbound_domain } : {},
    var.email_provider == "postmark" ? { POSTMARK_SERVER_TOKEN = var.postmark_server_token } : {},
    var.email_provider == "ses" ? merge({
      AWS_ACCESS_KEY_ID     = var.ses_access_key_id
      AWS_SECRET_ACCESS_KEY = var.ses_secret_access_key
    }, var.ses_region != "" ? { AWS_REGION = var.ses_region } : {}) : {}
  ) : {}

  email_env_backend = local.email_configured ? merge(
    local.email_env,
    var.email_inbound_webhook_secret != "" ? { EMAIL_INBOUND_WEBHOOK_SECRET = var.email_inbound_webhook_secret } : {}
  ) : {}
}
