locals {
  postmark_env = local.eff_strings["postmark_server_token"] != "" ? merge(
    { POSTMARK_SERVER_TOKEN = local.eff_strings["postmark_server_token"] },
    local.eff_strings["email_from"] != "" ? {
      EMAIL_FROM               = local.eff_strings["email_from"]
      EMAIL_FROM_TRANSACTIONAL = local.eff_strings["email_from"]
    } : {},
    local.eff_strings["email_inbound_domain"] != "" ? { EMAIL_INBOUND_DOMAIN = local.eff_strings["email_inbound_domain"] } : {}
  ) : {}

  postmark_backend_env = local.eff_strings["postmark_server_token"] != "" ? merge(
    local.postmark_env,
    local.eff_strings["email_inbound_webhook_secret"] != "" ? { EMAIL_INBOUND_WEBHOOK_SECRET = local.eff_strings["email_inbound_webhook_secret"] } : {}
  ) : {}
}
