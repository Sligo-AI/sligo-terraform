locals {
  postmark_env = var.postmark_server_token != "" ? merge(
    { POSTMARK_SERVER_TOKEN = var.postmark_server_token },
    var.email_from != "" ? {
      EMAIL_FROM               = var.email_from
      EMAIL_FROM_TRANSACTIONAL = var.email_from
    } : {},
    var.email_inbound_domain != "" ? { EMAIL_INBOUND_DOMAIN = var.email_inbound_domain } : {}
  ) : {}

  postmark_backend_env = var.postmark_server_token != "" ? merge(
    local.postmark_env,
    var.email_inbound_webhook_secret != "" ? { EMAIL_INBOUND_WEBHOOK_SECRET = var.email_inbound_webhook_secret } : {}
  ) : {}
}
