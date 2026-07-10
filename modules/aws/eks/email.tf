# Email provider wiring. Env vars follow the app contract:
# EMAIL_PROVIDER (postmark|ses), EMAIL_FROM, EMAIL_INBOUND_DOMAIN,
# POSTMARK_SERVER_TOKEN, AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY for SES.
# No email env is injected until credentials are configured.
locals {
  email_provider = local.eff_strings["email_provider"]
  ses_create     = local.email_provider == "ses" && var.create_ses_resources
  ses_domain     = local.eff_strings["ses_domain"] != "" ? local.eff_strings["ses_domain"] : try(split("@", local.eff_strings["email_from"])[1], "")

  # SES sending credentials: the created sender key wins, then deployment AWS credentials.
  email_aws_access_key_id     = local.ses_create ? aws_iam_access_key.ses_sender[0].id : local.eff_strings["aws_access_key_id"]
  email_aws_secret_access_key = local.ses_create ? aws_iam_access_key.ses_sender[0].secret : local.eff_strings["aws_secret_access_key"]

  email_configured = local.email_provider == "ses" ? (local.email_aws_access_key_id != "" && local.email_aws_secret_access_key != "") : local.eff_strings["postmark_server_token"] != ""

  email_env = local.email_configured ? merge(
    { EMAIL_PROVIDER = local.email_provider },
    local.eff_strings["email_from"] != "" ? {
      EMAIL_FROM               = local.eff_strings["email_from"]
      EMAIL_FROM_TRANSACTIONAL = local.eff_strings["email_from"]
    } : {},
    local.eff_strings["email_inbound_domain"] != "" ? { EMAIL_INBOUND_DOMAIN = local.eff_strings["email_inbound_domain"] } : {},
    local.email_provider == "postmark" ? { POSTMARK_SERVER_TOKEN = local.eff_strings["postmark_server_token"] } : {},
    local.email_provider == "ses" ? {
      AWS_ACCESS_KEY_ID     = local.email_aws_access_key_id
      AWS_SECRET_ACCESS_KEY = local.email_aws_secret_access_key
    } : {}
  ) : {}

  email_env_backend = local.email_configured ? merge(
    local.email_env,
    local.eff_strings["email_inbound_webhook_secret"] != "" ? { EMAIL_INBOUND_WEBHOOK_SECRET = local.eff_strings["email_inbound_webhook_secret"] } : {}
  ) : {}
}

# SES resources — only when email_provider is ses and create_ses_resources is true.
# Domain verification and DKIM records are returned as outputs for the operator to publish.
resource "aws_ses_domain_identity" "email" {
  count  = local.ses_create ? 1 : 0
  domain = local.ses_domain
}

resource "aws_ses_domain_dkim" "email" {
  count  = local.ses_create ? 1 : 0
  domain = aws_ses_domain_identity.email[0].domain
}

resource "aws_iam_user" "ses_sender" {
  count = local.ses_create ? 1 : 0
  name  = "${var.cluster_name}-ses-sender"
}

resource "aws_iam_user_policy" "ses_sender" {
  count = local.ses_create ? 1 : 0
  name  = "ses-send"
  user  = aws_iam_user.ses_sender[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = aws_ses_domain_identity.email[0].arn
      }
    ]
  })
}

resource "aws_iam_access_key" "ses_sender" {
  count = local.ses_create ? 1 : 0
  user  = aws_iam_user.ses_sender[0].name
}
