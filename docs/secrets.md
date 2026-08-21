---
layout: page
title: "Secrets Management"
description: "Securely provide secrets to Terraform for Sligo Enterprise. Aligned with Sligo Helm chart secrets."
---

The Terraform modules create Kubernetes secrets (`nextjs-secrets`, `backend-secrets`, `mcp-gateway-secrets`, plus database/redis) and pass them to the [Sligo Helm chart](https://github.com/Sligo-AI/sligo-helm-charts). For the full list of keys and options (e.g. vector stores, storage, auth), see the Helm chart [SECRETS.md](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/SECRETS.md).

---

## How to supply secrets to Terraform

### Option 1: terraform.tfvars (Development)

Store secrets in `terraform.tfvars` (add to `.gitignore`):

```hcl
db_password    = "your-secure-password"
jwt_secret     = "your-jwt-secret"
api_key        = "your-api-key"
backend_api_key = "your-frontend-backend-shared-key-min-32-chars"
encryption_key = "64-hex-chars-from-openssl-rand-hex-32"
nextauth_secret = "your-nextauth-secret"
gateway_secret  = "your-gateway-secret"
workos_cookie_password = "your-workos-cookie-password"  # when using WorkOS
# When using OIDC/SAML: auth_session_secret (min 32 chars)
```

Generate values:

```bash
openssl rand -hex 32    # encryption_key
openssl rand -base64 32 # workos_cookie_password, auth_session_secret
```

---

### Option 2: Environment Variables

```bash
export TF_VAR_db_password="your-secure-password"
export TF_VAR_jwt_secret="your-jwt-secret"
# ... etc
terraform apply
```

Useful for CI/CD — secrets stay out of files.

---

### Option 3: Cloud Secrets Manager (Production)

#### AWS (Secrets Manager)

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "sligo/prod/db-password"
}

variable "db_password" {
  default = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

#### GCP (Secret Manager)

```hcl
data "google_secret_manager_secret_version" "db_password" {
  secret  = "sligo-db-password"
  project = var.gcp_project_id
}

variable "db_password" {
  default = data.google_secret_manager_secret_version.db_password.secret_data
}
```

#### Azure (Key Vault)

```hcl
data "azurerm_key_vault_secret" "db_password" {
  name         = "sligo-db-password"
  key_vault_id = azurerm_key_vault.main.id
}

variable "db_password" {
  default = data.azurerm_key_vault_secret.db_password.value
}
```

---

## Terraform → Kubernetes secrets (alignment with Helm)

| Terraform creates | Used by Helm as | Main Terraform variables |
|-------------------|-----------------|---------------------------|
| `nextjs-secrets` | app frontend | `frontend_url`, `next_public_api_url`, `backend_api_key`, `encryption_key`, `auth_provider`, `auth_invitations`, `super_admin_emails`, WorkOS/OIDC/SAML vars, `openai_api_key`, bucket names, `storage_provider`, GCP/S3, Pinecone/SingleStore, etc. |
| `backend-secrets` | backend API | `jwt_secret`, `api_key`, `backend_api_key`, `encryption_key`, `openai_api_key`, `anthropic_api_key`, `google_vertex_ai_web_credentials`, LangSmith (`langsmith_*`), storage, etc. |
| `mcp-gateway-secrets` | MCP gateway | `gateway_secret`, `DATABASE_URL` (PI serving tools), `openai_api_key`, SpendHQ/Perplexity/Tavily, LangSmith, storage, Pinecone/SingleStore, etc. |
| `database-secret` | database (external) | From RDS/Aurora (host, port, database, username, password) |
| `redis-secret` | redis (external) | From ElastiCache (host, port) |
| `temporal-db-credentials` | Temporal subchart (default store) | When `enable_temporal = true` **and** `temporal_self_hosted = true`; host/port/database/username/password from managed Postgres |
| `temporal-visibility-db-credentials` | Temporal subchart (visibility store) | Same as above |

When **`enable_temporal = true`**, Terraform also:

- Enables the `temporal-worker` Helm Deployment and injects `TEMPORAL_*` into `nextjs-secrets`, `backend-secrets`, and `mcp-gateway-secrets`
- If **`temporal_self_hosted = true`** (default): creates Postgres databases `temporal` / `temporal_visibility`, Temporal DB credential secrets, and Helm values for the official Temporal server subchart
- If **`temporal_self_hosted = false`**: points clients at Temporal Cloud (`temporal_frontend_address` + `temporal_api_key`); does **not** create Temporal Postgres DBs or install the server subchart

See [examples/gcp-gke/terraform.tfvars.temporal.example](../examples/gcp-gke/terraform.tfvars.temporal.example) and the Helm chart [TEMPORAL.md](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/TEMPORAL.md).

### Temporal Terraform variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_temporal` | `false` | Enable Temporal clients + sligo-temporal-worker |
| `temporal_self_hosted` | `true` | Install in-cluster Temporal server + Postgres DBs; set `false` for Temporal Cloud |
| `temporal_frontend_address` | *(empty)* | Cloud/external frontend `host:port` (required when not self-hosted) |
| `temporal_api_key` | *(empty)* | Temporal Cloud API key (required when not self-hosted) |
| `temporal_tls` | *(empty)* | Override `TEMPORAL_TLS` (`"true"`/`"false"`); empty = false self-hosted, true Cloud |
| `temporal_namespace` | `sligo-prod` | Temporal logical namespace |
| `temporal_task_queue` | `sligo-workflows` | Worker task queue |
| `temporal_history_shard_count` | `512` | History shards (immutable after first deploy; self-hosted only) |
| `temporal_db_name` | `temporal` | Default store database name (self-hosted only) |
| `temporal_visibility_db_name` | `temporal_visibility` | Visibility store database name (self-hosted only) |
| `temporal_db_username` | *(empty → `db_username`)* | Optional dedicated DB user |
| `temporal_db_password` | *(empty → `db_password`)* | Optional dedicated DB password |
| `temporal_web_enabled` | `true` | Deploy Temporal Web UI (self-hosted only; ClusterIP; Super Admin proxy in app) |

### Proactive Insights

When **`enable_proactive_insights = true`**, Terraform:

- Sets `proactiveInsights.enabled = true` in the Helm release (which sets `PROACTIVE_INSIGHTS_ENABLED` on the app pods)
- Adds `SPENDHQ_SS_HOST` / `SPENDHQ_SS_USERNAME` / `SPENDHQ_SS_PASSWORD` / `SPENDHQ_SS_PORT` to `backend-secrets` (in addition to `mcp-gateway-secrets`)

`mcp-gateway-secrets` always includes `DATABASE_URL` (same Postgres URL as backend) so SpendHQ Proactive Insights serving tools can read the Prisma store.

Proactive Insights runs on the Temporal worker, so it requires `enable_temporal = true` and the `spendhq_ss_*` variables to be set. The org must also be enabled in Super Admin.

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_proactive_insights` | `false` | Enable Proactive Insights (requires `enable_temporal` and `spendhq_ss_*`) |


| Variable | Description |
|----------|-------------|
| `db_password` | Database password (Aurora/Cloud SQL/Azure) |
| `jwt_secret` | Backend JWT signing |
| `api_key` | API authentication |
| `backend_api_key` | Shared frontend↔backend service key (required; min 32 characters) |
| `nextauth_secret` | NextAuth/legacy session |
| `gateway_secret` | MCP Gateway secret |
| `encryption_key` | 64 hex characters (AES-256) |
| `workos_cookie_password` | When `auth_provider = "workos"` (generate with `openssl rand -base64 32`) |
| `auth_session_secret` | When `auth_provider = "oidc"` or `"saml"` (min 32 chars) |
| `super_admin_emails` | Optional comma-separated super-admin allowlist |
| `auth_invitations` | Optional invitations provider (e.g. `workos`) |

For all app env vars (e.g. `STORAGE_PROVIDER`, vector stores, OIDC/SAML, Azure AI Search), see the [Helm SECRETS.md](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/SECRETS.md). Module variables include **`storage_provider`** (`gcs` or `s3`); the app defaults to `gcs` when unset.

### Optional: Azure AI Search and Azure OpenAI

Terraform supports:

- **Azure AI Search** (nextjs + mcp-gateway): set `azure_aisearch_endpoint` (and optionally `azure_aisearch_key`, `azure_aisearch_index`, `azure_aisearch_query_type`) to inject `RAG_VECTOR_STORE=azureaisearch` and the `AZURE_AISEARCH_*` keys.
- **Azure OpenAI** (backend): set `azure_openai_api_key` (and optionally `azure_openai_api_instance_name`, `azure_openai_api_version`, `azure_openai_base_path`) to inject the `AZURE_OPENAI_*` keys.

### Gaps vs current Helm secrets doc

The following are in the Helm secrets spec but **not yet** exposed as Terraform variables in this repo:

- **Sirion** (mcp-gateway): `SIRION_BASE_URL`, `SIRION_CLIENT_ID`, `SIRION_CLIENT_SECRET`
- **Backend**: optional `LANGCHAIN_CALLBACKS_BACKGROUND`

If you need these, you can create or patch the Kubernetes secrets after apply, or extend the module variables and secret resources.

---

[← Back to overview](../)
