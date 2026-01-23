# Sligo Cloud - AWS EKS Module

This Terraform module provisions a complete AWS infrastructure and deploys Sligo Cloud using Helm charts.

## Features

- **EKS Cluster** - Managed Kubernetes cluster
- **RDS PostgreSQL** - Managed database with automatic backups
- **ElastiCache Redis** - Managed Redis cache
- **S3 Storage** - Object storage buckets
- **ACM Certificate** - Automatic SSL/TLS certificate creation
- **Application Load Balancer** - Internet-facing ALB with HTTPS
- **AWS Load Balancer Controller** - Automatically installed and configured
- **Helm Chart Deployment** - Deploys Sligo Cloud application
- **Security Groups** - Automatically configured for ALB → pods communication
- **Health Checks** - Service-specific health check paths

## Usage

```hcl
module "sligo_aws" {
  source = "github.com/Sligo-AI/sligo-terraform//modules/aws/eks"

  # Cluster configuration
  cluster_name    = "sligo-production"
  cluster_version = "1.29"
  aws_region      = "us-east-1"

  # Application configuration
  domain_name              = "app.example.com"
  client_repository_name   = "your-client-containers"
  app_version              = "1.0.0"
  sligo_service_account_key_path = "./sligo-service-account-key.json"

  # Database configuration
  db_instance_class    = "db.t3.medium"
  db_allocated_storage = 100
  db_username          = "sligo"
  db_password          = var.db_password

  # Optional: Prisma Accelerate
  prisma_accelerate_url = var.prisma_accelerate_url  # or leave empty for direct PostgreSQL

  # Optional: ACM Certificate
  acm_certificate_arn = var.acm_certificate_arn  # or leave empty for auto-creation

  # Secrets
  jwt_secret          = var.jwt_secret
  api_key             = var.api_key
  nextauth_secret     = var.nextauth_secret
  gateway_secret      = var.gateway_secret
  frontend_url        = "https://app.example.com"
  next_public_api_url = "https://api.example.com"
  encryption_key      = var.encryption_key  # 64 hex characters

  # WorkOS (optional)
  workos_api_key         = var.workos_api_key
  workos_client_id       = var.workos_client_id
  workos_cookie_password = var.workos_cookie_password

  # Google Cloud (optional)
  next_public_google_client_id = var.next_public_google_client_id
  google_client_secret        = var.google_client_secret
  google_project_id           = var.google_project_id
  # ... other Google variables

  # Pinecone (optional)
  pinecone_api_key = var.pinecone_api_key
  pinecone_index   = var.pinecone_index
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| kubernetes | >= 2.23 |
| helm | >= 2.11 |

## Architecture

### Infrastructure Components

1. **EKS Cluster** - Managed Kubernetes cluster
2. **RDS PostgreSQL** - Managed database instance
3. **ElastiCache Redis** - Managed Redis cluster
4. **S3 Bucket** - Object storage for file management
5. **VPC & Networking** - VPC, subnets, security groups (optional, can use existing)
6. **ACM Certificate** - SSL/TLS certificate (auto-created or provided)
7. **Application Load Balancer** - Internet-facing ALB

### Kubernetes Resources

1. **Namespace** - `sligo` namespace
2. **Image Pull Secret** - For Google Artifact Registry
3. **Kubernetes Secrets** - Application environment variables
4. **Helm Release** - Sligo Cloud application
5. **AWS Load Balancer Controller** - Installed via Helm
6. **Ingress** - Routes traffic from ALB to pods
7. **Security Group Rules** - ALB → pods communication

### Network Flow

```
Internet → ALB (HTTPS) → Ingress → Next.js App (Port 3000)
                                    ├── /api/* routes
                                    └── Internal calls to:
                                        ├── Backend (Port 3001)
                                        └── MCP Gateway (Port 3002)
```

## Inputs

### Required

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `cluster_name` | EKS cluster name | `string` | n/a |
| `domain_name` | Domain name for application | `string` | n/a |
| `client_repository_name` | GAR repository name | `string` | n/a |
| `sligo_service_account_key_path` | Path to Sligo service account key | `string` | n/a |
| `db_password` | Database password | `string` | n/a |
| `jwt_secret` | JWT secret | `string` | n/a |
| `api_key` | API key | `string` | n/a |
| `nextauth_secret` | NextAuth secret | `string` | n/a |
| `gateway_secret` | MCP Gateway secret | `string` | n/a |
| `frontend_url` | Frontend URL | `string` | n/a |
| `next_public_api_url` | Public API URL | `string` | n/a |

### Optional

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `cluster_version` | Kubernetes version | `string` | `"1.28"` |
| `aws_region` | AWS region | `string` | `"us-east-1"` |
| `acm_certificate_arn` | Existing ACM certificate ARN | `string` | `""` |
| `prisma_accelerate_url` | Prisma Accelerate URL | `string` | `""` |
| `encryption_key` | 64-character hex encryption key | `string` | `""` |
| `workos_api_key` | WorkOS API key | `string` | `""` |
| `workos_client_id` | WorkOS Client ID | `string` | `""` |
| `workos_cookie_password` | WorkOS cookie password | `string` | `""` |
| `db_instance_class` | RDS instance class | `string` | `"db.t3.medium"` |
| `db_allocated_storage` | RDS storage in GB | `number` | `100` |
| `redis_node_type` | ElastiCache node type | `string` | `"cache.t3.micro"` |
| `s3_bucket_name` | S3 bucket name | `string` | `""` |
| `vpc_id` | Existing VPC ID | `string` | `""` |
| `subnet_ids` | Existing subnet IDs | `list(string)` | `[]` |

See [variables.tf](./variables.tf) for complete list of all variables.

## Outputs

| Name | Description |
|------|-------------|
| `cluster_endpoint` | Kubernetes cluster API endpoint |
| `database_endpoint` | RDS PostgreSQL endpoint |
| `application_url` | Application URL (https://domain_name) |
| `ingress_hostname` | ALB hostname for DNS configuration |
| `acm_certificate_arn` | ACM certificate ARN (if auto-created) |
| `acm_certificate_validation_records` | DNS validation records (if auto-created) |

## Key Features

### Automatic AWS Load Balancer Controller

The module automatically:
- Creates IAM role and policy for the controller
- Creates Kubernetes service account with IRSA (IAM Roles for Service Accounts)
- Installs AWS Load Balancer Controller via Helm
- Ensures controller is ready before deploying application

### Automatic ACM Certificate

If `acm_certificate_arn` is empty:
- Creates DNS-validated ACM certificate
- Outputs DNS validation records
- Configures HTTPS listeners and SSL redirect

### Ingress Configuration

- Routes all traffic (`/`) to Next.js app
- Next.js app handles all `/api/*` routes internally
- Backend and MCP Gateway accessed via internal service DNS
- Service-specific health check paths configured

### Security Group Rules

Automatically creates security group rules:
- ALB security group → Node security group (ports 3000, 3001, 3002)
- Allows ALB to reach all application pods

### Health Checks

- App: `/api/health` (port 3000)
- Backend: `/health` (port 3001)
- MCP Gateway: `/health` (port 3002)

## Dependencies

- **Helm Chart**: Uses `sligo-cloud` Helm chart
- **AWS Load Balancer Controller**: Installed via Helm
- **Prisma Accelerate**: Optional, can use direct PostgreSQL connection

## Examples

See [examples/aws-eks](../../examples/aws-eks) for complete working examples.

## Notes

- The module creates a new VPC if `vpc_id` is not provided
- Security group rules are automatically managed
- All secrets are stored as Kubernetes secrets
- Pods must be restarted after secret updates to pick up changes
