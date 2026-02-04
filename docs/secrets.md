---
layout: page
title: "Secrets Management"
description: "Securely provide secrets to Terraform (db_password, jwt_secret, api_key) for Sligo Enterprise."
---

## Option 1: terraform.tfvars (Development)

Store secrets in `terraform.tfvars` (add to `.gitignore`):

```hcl
db_password    = "your-secure-password"
jwt_secret     = "your-jwt-secret"
api_key        = "your-api-key"
encryption_key = "64-hex-chars-from-openssl-rand-hex-32"
```

Generate `encryption_key`:

```bash
openssl rand -hex 32
```

---

## Option 2: Environment Variables

```bash
export TF_VAR_db_password="your-secure-password"
export TF_VAR_jwt_secret="your-jwt-secret"
# ... etc
terraform apply
```

Useful for CI/CD — secrets stay out of files.

---

## Option 3: Cloud Secrets Manager (Production)

### AWS (Secrets Manager)

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "sligo/prod/db-password"
}

variable "db_password" {
  default = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

### GCP (Secret Manager)

```hcl
data "google_secret_manager_secret_version" "db_password" {
  secret  = "sligo-db-password"
  project = var.gcp_project_id
}

variable "db_password" {
  default = data.google_secret_manager_secret_version.db_password.secret_data
}
```

### Azure (Key Vault)

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

## Required Secrets

| Secret | Description |
|--------|-------------|
| `db_password` | Database password |
| `jwt_secret` | Backend JWT signing |
| `api_key` | API authentication |
| `nextauth_secret` | NextAuth.js |
| `gateway_secret` | MCP Gateway |
| `encryption_key` | 64 hex characters (AES-256) |

---

[← Back to overview](../)
