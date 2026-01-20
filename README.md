# Sligo Cloud - Terraform Modules

Official Terraform modules for deploying Sligo Cloud Platform on AWS EKS and Google Cloud GKE.

This repository provides production-ready Terraform configurations that provision infrastructure and deploy the [Sligo Cloud Helm Chart](https://github.com/Sligo-AI/sligo-helm-charts).

## 🎯 What This Repository Provides

- **Infrastructure as Code (IAC)** for Sligo Cloud deployments
- **Reusable Terraform modules** for AWS EKS and GCP GKE
- **Complete examples** with best practices
- **Automated provisioning** of:
  - Kubernetes clusters (EKS/GKE)
  - Managed databases (RDS/Cloud SQL)
  - Managed cache (ElastiCache/Memorystore)
  - Object storage buckets (S3/GCS)
  - Helm chart deployment
  - Secrets management
  - Ingress configuration

## 📋 Prerequisites

- **Terraform** >= 1.0
- **Helm** >= 3.10 (for Terraform Helm provider)
- **kubectl** configured with cluster access
- Cloud provider credentials configured:
  - AWS: `aws configure` or environment variables
  - GCP: `gcloud auth application-default login`
- **Sligo service account key** (contact support@sligo.ai)
- Domain name for application access

## 🏗️ Architecture

This repository uses Terraform to:

1. **Provision Infrastructure**
   - Kubernetes cluster (EKS or GKE)
   - Database (RDS PostgreSQL or Cloud SQL)
   - Cache (ElastiCache Redis or Memorystore)
   - Object storage (S3 buckets or GCS buckets)
   - Networking (VPC, subnets, security groups)

2. **Deploy Application**
   - Creates Kubernetes namespace
   - Sets up image pull secrets
   - Creates application secrets
   - Deploys [Sligo Cloud Helm Chart](https://github.com/Sligo-AI/sligo-helm-charts)

3. **Configure Access**
   - Sets up ingress with SSL certificates
   - Configures load balancers
   - Outputs endpoints for DNS configuration

## 🚀 Quick Start

### AWS EKS Deployment

```bash
# Clone the repository
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

# Navigate to AWS example
cd examples/aws-eks

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy everything
terraform apply
```

### GCP GKE Deployment

```bash
# Navigate to GCP example
cd examples/gcp-gke

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy everything
terraform apply
```

## 📁 Repository Structure

```
sligo-terraform/
├── modules/
│   ├── aws/
│   │   └── eks/              # AWS EKS module
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── gcp/
│       └── gke/              # GCP GKE module
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── examples/
│   ├── aws-eks/              # Complete AWS EKS example
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars.example
│   │   └── README.md
│   └── gcp-gke/              # Complete GCP GKE example
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── README.md
└── README.md                 # This file
```

## 🔧 Using the Modules

### AWS EKS Module

```hcl
module "sligo_aws" {
  source = "github.com/Sligo-AI/sligo-terraform//modules/aws/eks"

  # Cluster configuration
  cluster_name    = "sligo-production"
  cluster_version = "1.28"
  aws_region      = "us-east-1"

  # Application configuration
  domain_name              = "app.example.com"
  client_repository_name   = "your-client-containers"
  app_version              = "1.0.0"
  
  # Service account key (provided by Sligo)
  sligo_service_account_key_path = "./sligo-service-account-key.json"

  # Database configuration
  db_instance_class = "db.t3.medium"
  db_allocated_storage = 100

  # Redis configuration
  redis_node_type = "cache.t3.micro"

  # Secrets (use Terraform variables or secrets manager)
  db_password      = var.db_password
  jwt_secret       = var.jwt_secret
  api_key          = var.api_key
  nextauth_secret  = var.nextauth_secret
  gateway_secret   = var.gateway_secret
}
```

### GCP GKE Module

```hcl
module "sligo_gcp" {
  source = "github.com/Sligo-AI/sligo-terraform//modules/gcp/gke"

  # Cluster configuration
  cluster_name = "sligo-production"
  gcp_project_id = "your-project-id"
  gcp_region     = "us-central1"
  gcp_zones      = ["us-central1-a", "us-central1-b"]

  # Application configuration
  domain_name              = "app.example.com"
  client_repository_name   = "your-client-containers"
  app_version              = "1.0.0"
  
  # Service account key (provided by Sligo)
  sligo_service_account_key_path = "./sligo-service-account-key.json"

  # Database configuration
  db_tier = "db-f1-micro"

  # Redis configuration
  redis_memory_size_gb = 1

  # Secrets
  db_password      = var.db_password
  jwt_secret       = var.jwt_secret
  api_key          = var.api_key
  nextauth_secret  = var.nextauth_secret
  gateway_secret   = var.gateway_secret
}
```

## 🔗 Relationship to Helm Chart

This Terraform repository **uses** the [Sligo Cloud Helm Chart](https://github.com/Sligo-AI/sligo-helm-charts) for application deployment.

**How it works:**
1. Terraform provisions infrastructure (cluster, database, cache)
2. Terraform creates Kubernetes secrets
3. Terraform uses the Helm provider to deploy the chart from the public Helm repository
4. The Helm chart deploys the Sligo Cloud application

**Helm Chart Repository:**
```hcl
resource "helm_release" "sligo_cloud" {
  repository = "https://sligo-ai.github.io/sligo-helm-charts"
  chart      = "sligo-cloud"
  version    = "1.0.0"  # Pin to specific version
  # ... configuration
}
```

## 📝 Required Variables

### Common Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `domain_name` | Domain name for the application | Yes |
| `client_repository_name` | Your GAR repository name (from Sligo) | Yes |
| `sligo_service_account_key_path` | Path to Sligo service account key JSON | Yes |
| `app_version` | Sligo Cloud application version | Yes |
| `db_password` | Database password | Yes |
| `jwt_secret` | JWT secret for backend | Yes |
| `api_key` | API key | Yes |
| `nextauth_secret` | NextAuth secret | Yes |
| `gateway_secret` | MCP Gateway secret | Yes |

### AWS-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `cluster_name` | EKS cluster name | Required |
| `db_instance_class` | RDS instance class | `db.t3.medium` |
| `redis_node_type` | ElastiCache node type | `cache.t3.micro` |

### GCP-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gcp_project_id` | GCP project ID | Required |
| `gcp_region` | GCP region | `us-central1` |
| `gcp_zones` | GCP zones | `["us-central1-a"]` |
| `db_tier` | Cloud SQL tier | `db-f1-micro` |
| `redis_memory_size_gb` | Memorystore memory size | `1` |

## 🔐 Secrets Management

### Option 1: Terraform Variables (Development)

```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
```

Use `terraform.tfvars` (add to `.gitignore`):
```hcl
db_password = "your-secure-password"
```

### Option 2: Environment Variables

```bash
export TF_VAR_db_password="your-secure-password"
terraform apply
```

### Option 3: Cloud Secrets Manager (Production)

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "sligo/db-password"
}

variable "db_password" {
  default = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

## 📊 Outputs

After deployment, Terraform outputs:

```hcl
output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = module.sligo_aws.cluster_endpoint
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = module.sligo_aws.database_endpoint
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "ingress_hostname" {
  description = "Load balancer hostname"
  value       = module.sligo_aws.ingress_hostname
}
```

## 🔄 Upgrading

### Upgrade Helm Chart Version

```hcl
resource "helm_release" "sligo_cloud" {
  version = "1.1.0"  # Update version
  # ... rest of configuration
}
```

Then run:
```bash
terraform plan  # Review changes
terraform apply # Apply upgrade
```

### Upgrade Application Version

```hcl
module "sligo_aws" {
  app_version = "1.1.0"  # Update version
  # ... rest of configuration
}
```

## 🧪 Testing

### Validate Configuration

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Check plan
terraform plan
```

### Integration Testing

The repository includes GitHub Actions workflows that:
- Validate Terraform syntax
- Test module structure
- Verify Helm chart integration

## 📚 Documentation

- **[Helm Chart Repository](https://github.com/Sligo-AI/sligo-helm-charts)** - Application deployment charts
- **[Installation Guide](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/INSTALLATION.md)** - Manual Helm installation
- **[Terraform Integration Guide](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/TERRAFORM.md)** - Detailed Terraform examples
- **[Configuration Reference](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/CONFIGURATION.md)** - All Helm chart values
- **[Troubleshooting](https://github.com/Sligo-AI/sligo-helm-charts/blob/main/docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🤝 Support

- **Email**: support@sligo.ai
- **Issues**: [GitHub Issues](https://github.com/Sligo-AI/sligo-terraform/issues)
- **Helm Chart Issues**: [Helm Chart Issues](https://github.com/Sligo-AI/sligo-helm-charts/issues)

## 📄 License

[Specify your license]

## 🔄 Version Compatibility

| Terraform Module Version | Helm Chart Version | Kubernetes Version |
|-------------------------|-------------------|-------------------|
| 1.0.0 | 1.0.0 | 1.24+ |

## 🛠️ Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 🙏 Acknowledgments

This repository uses the [Sligo Cloud Helm Chart](https://github.com/Sligo-AI/sligo-helm-charts) for application deployment.

---

**Ready to deploy?** Start with the [Quick Start](#-quick-start) guide above!
