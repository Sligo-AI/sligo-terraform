# Sligo Cloud - Terraform Modules

Official Terraform modules for deploying Sligo Cloud Platform on AWS EKS and Google Cloud GKE.

This repository provides production-ready Terraform configurations that provision infrastructure and deploy the [Sligo Cloud Helm Chart](https://github.com/Sligo-AI/sligo-helm-charts).

## 🎯 What This Repository Provides

- **Infrastructure as Code (IAC)** for Sligo Cloud deployments
- **Reusable Terraform modules** for AWS EKS and GCP GKE
- **Complete examples** with best practices
- **Environment automation** - Use `make create-environment` to quickly create new environments
- **Automated provisioning** of:
  - Kubernetes clusters (EKS/GKE)
  - Managed databases (RDS/Cloud SQL)
  - Managed cache (ElastiCache/Memorystore)
  - Object storage buckets (S3/GCS)
  - Helm chart deployment
  - Secrets management
  - Ingress configuration

## 📋 Prerequisites

Before you begin, ensure you have:

- **Terraform** >= 1.0 installed
- **Helm** >= 3.10 (for Terraform Helm provider)
- **kubectl** installed (will be configured after cluster creation)
- **Cloud provider credentials** configured:
  - AWS: `aws configure` or environment variables
  - GCP: `gcloud auth application-default login`
- **Sligo Service Account Key** (JSON file) - Contact support@sligo.ai
  - This authenticates your cluster to pull container images from Sligo's Google Artifact Registry (GAR)
  - Place this file in your project directory (it's automatically ignored by git)
- **Container Repository Name** - Provided by Sligo support
  - Your unique repository name in Sligo's Google Artifact Registry
  - Example: `your-company-containers` or `client-abc-containers`
- **Domain name** for your application (e.g., `app.example.com`)

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

### Step 1: Get Your Sligo Credentials

Before starting, contact **support@sligo.ai** to receive:

1. **Service Account Key (JSON file)** - For authenticating to Sligo's Google Artifact Registry
2. **Container Repository Name** - Your unique repository name (e.g., `your-company-containers`)

### Step 2: Create Your Environment

**Recommended:** Use the automated environment creation tool:

```bash
# Clone the repository
git clone https://github.com/Sligo-AI/sligo-terraform.git
cd sligo-terraform

# Create a new environment (interactive prompts)
make create-environment
```

The script will prompt you for:
- Infrastructure type (`aws-eks` or `gcp-gke`)
- Environment name (e.g., `dev`, `staging`, `prod`)
- Region (e.g., `us-east-1` for AWS, `us-central1` for GCP)
- Cluster name (defaults to `sligo-{env-name}`)
- Domain name (defaults to `{env-name}.example.com`)

This creates a new directory in `environments/` with all necessary files pre-configured.

**Alternative:** If you prefer to use the examples directly for learning or testing, see the [Manual Setup](#manual-setup-using-examples) section below.

### Step 3: Configure Your Environment

```bash
# Navigate to your environment directory
cd environments/aws-eks-{your-env-name}  # or gcp-gke-{your-env-name}

# Place your Sligo service account key in this directory
# Name it: sligo-service-account-key.json
# (This file is automatically ignored by git for security)

# Edit terraform.tfvars with your values:
# - Set client_repository_name (from Sligo)
# - Set sligo_service_account_key_path = "./sligo-service-account-key.json"
# - Set app_version = "v1.0.0" (or latest version tag - contact Sligo for available versions)
# - Configure all required secrets (jwt_secret, api_key, etc.)
# - Generate encryption_key: openssl rand -hex 32
```

### Step 4: Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy everything
terraform apply
```

**See the [detailed step-by-step guide](examples/aws-eks/README.md) for complete instructions.**

> **💡 Tip:** Need multiple environments (dev, staging, prod)? See the [Managing Multiple Environments](#-managing-multiple-environments-dev-staging-prod) section for best practices.

---

### Manual Setup Using Examples

If you want to use the examples directly (for learning, testing, or one-off deployments):

**AWS EKS:**
```bash
cd examples/aws-eks
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform plan && terraform apply
```

**GCP GKE:**
```bash
cd examples/gcp-gke
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform plan && terraform apply
```

> **Note:** For production deployments or multiple environments, we recommend using `make create-environment` to create environments in the `environments/` directory. This keeps your deployments organized and separate from the example templates.

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
  cluster_version = "1.29"
  aws_region      = "us-east-1"

  # Application configuration
  domain_name              = "app.example.com"
  client_repository_name   = "your-client-containers"
  app_version              = "v1.0.0"  # Pin to specific version tag (e.g., v1.0.0, v1.2.3)
  sligo_service_account_key_path = "./sligo-service-account-key.json"

  # Database configuration
  db_instance_class    = "db.t3.medium"
  db_allocated_storage = 100
  db_password          = var.db_password

  # Optional: Prisma Accelerate (or use direct PostgreSQL)
  prisma_accelerate_url = var.prisma_accelerate_url

  # Optional: ACM Certificate (or auto-create)
  acm_certificate_arn = var.acm_certificate_arn

  # Secrets
  jwt_secret       = var.jwt_secret
  api_key          = var.api_key
  nextauth_secret  = var.nextauth_secret
  gateway_secret   = var.gateway_secret
  frontend_url     = "https://app.example.com"
  next_public_api_url = "https://api.example.com"
  encryption_key   = var.encryption_key  # 64 hex characters

  # Optional: WorkOS, Google Cloud, Pinecone, etc.
  workos_api_key  = var.workos_api_key
  # ... other optional variables
}
```

**Key Features:**
- ✅ Automatic AWS Load Balancer Controller installation
- ✅ Automatic ACM certificate creation with DNS validation
- ✅ Security group rules automatically configured
- ✅ Simplified ingress routing (all traffic to Next.js app)
- ✅ Service-specific health check paths
- ✅ Support for Prisma Accelerate or direct PostgreSQL

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
  app_version              = "v1.0.0"  # Pin to specific version tag (e.g., v1.0.0, v1.2.3)
  
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
2. Terraform creates Kubernetes secrets and image pull secrets for Google Artifact Registry
3. Terraform uses the Helm provider to deploy the chart from the public Helm repository
4. The Helm chart deploys the Sligo Cloud application using containers from Sligo's Google Artifact Registry

## 📦 Container Registry Access

Sligo Cloud containers are stored in **Google Artifact Registry (GAR)**. Here's how access works:

1. **Sligo provides you with:**
   - A JSON service account key file (for authentication)
   - Your container repository name (e.g., `your-client-containers`)

2. **You place the key file** in your project directory:
   - Example: `examples/aws-eks/sligo-service-account-key.json`
   - The file is automatically ignored by git (see `.gitignore`) for security

3. **Terraform automatically:**
   - Reads the key file from the path you specify in `sligo_service_account_key_path`
   - Creates a Kubernetes image pull secret named `gar-pull-secret`
   - Configures all pods to use this secret to pull images from GAR

4. **Container images are pulled from:**
   ```
   us-central1-docker.pkg.dev/sligo-ai-platform/<your-repository-name>/sligo-frontend:<app_version>
   us-central1-docker.pkg.dev/sligo-ai-platform/<your-repository-name>/sligo-backend:<app_version>
   us-central1-docker.pkg.dev/sligo-ai-platform/<your-repository-name>/sligo-mcp-gateway:<app_version>
   ```
   
   Where `<app_version>` is the value you set in `app_version` (e.g., `v1.0.0`, `v1.2.3`).

**Important:**
- The service account key file must be present when running `terraform apply`
- The repository name (`client_repository_name`) must match exactly what Sligo provided
- Contact support@sligo.ai if you need a new service account key

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
| `client_repository_name` | Your GAR repository name (provided by Sligo support) | Yes |
| `sligo_service_account_key_path` | Path to Sligo service account key JSON file (place in project directory) | Yes |
| `app_version` | Sligo Cloud application version tag (e.g., `v1.0.0`, `v1.2.3`). Should match a version tag in the container registry. Use `latest` for development only. | Yes |
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
| `cluster_version` | Kubernetes version | `1.28` |
| `db_instance_class` | RDS instance class | `db.t3.medium` |
| `db_allocated_storage` | RDS storage in GB | `100` |
| `redis_node_type` | ElastiCache node type | `cache.t3.micro` |
| `acm_certificate_arn` | Existing ACM certificate ARN | `""` (auto-create) |
| `prisma_accelerate_url` | Prisma Accelerate URL | `""` (use direct PostgreSQL) |
| `encryption_key` | 64-character hex encryption key | Required |
| `s3_bucket_name` | S3 bucket name | `""` (auto-generate) |
| `vpc_id` | Existing VPC ID | `""` (create new) |
| `subnet_ids` | Existing subnet IDs | `[]` (create new) |

### GCP-Specific Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `gcp_project_id` | GCP project ID | Required |
| `gcp_region` | GCP region | `us-central1` |
| `gcp_zones` | GCP zones | `["us-central1-a"]` |
| `db_tier` | Cloud SQL tier | `db-f1-micro` |
| `redis_memory_size_gb` | Memorystore memory size | `1` |

## 🏢 Managing Multiple Environments (Dev, Staging, Prod)

If you need multiple instances of Sligo Cloud (dev, staging, production), we recommend using **separate directories** for each environment.

### Quick Start: Automated Environment Creation

The easiest way to create a new environment is using the automated script:

```bash
make create-environment
```

This interactive script will:
- Prompt you for environment name, infrastructure type (aws-eks/gcp-gke), and region
- Create a new environment directory in `environments/`
- Copy all necessary files from the example template
- Pre-fill `terraform.tfvars` with your inputs
- Generate a helpful README with next steps

**Example:**
```bash
$ make create-environment
? Infrastructure type (aws-eks/gcp-gke): aws-eks
? Environment name: dev
? AWS region [us-east-1]: us-west-2
? Cluster name [sligo-dev]: 
? Domain name [dev.example.com]: dev-app.example.com

✓ Environment created successfully!
```

### Recommended Structure

```
examples/
├── aws-eks/              # Example/template
└── gcp-gke/             # Example/template

environments/
├── aws-eks-dev/          # Development environment (created via make create-environment)
│   ├── main.tf
│   ├── terraform.tfvars
│   └── sligo-service-account-key.json
├── aws-eks-staging/      # Staging environment
│   ├── main.tf
│   ├── terraform.tfvars
│   └── sligo-service-account-key.json
└── aws-eks-prod/         # Production environment
    ├── main.tf
    ├── terraform.tfvars
    └── sligo-service-account-key.json
```

### Manual Setup Steps

If you prefer to create environments manually:

1. **Copy the example for each environment:**
   ```bash
   cp -r examples/aws-eks environments/aws-eks-dev
   cp -r examples/aws-eks environments/aws-eks-staging
   cp -r examples/aws-eks environments/aws-eks-prod
   ```

2. **Configure each environment's `terraform.tfvars`** with environment-specific values:
   - Different `cluster_name` (e.g., `sligo-dev`, `sligo-staging`, `sligo-prod`)
   - Different `domain_name` (e.g., `dev-app.example.com`, `staging-app.example.com`, `app.example.com`)
   - Different resource sizes (smaller for dev, larger for prod)
   - **Different secrets** for each environment (never reuse prod secrets)

3. **Add service account key to each directory:**
   - You can use the **same** service account key for all environments
   - All environments pull from the same container repository

4. **Deploy each environment independently:**
   ```bash
   cd environments/aws-eks-dev && terraform init && terraform apply
   cd ../aws-eks-staging && terraform init && terraform apply
   cd ../aws-eks-prod && terraform init && terraform apply
   ```

**Benefits:**
- ✅ Clear separation of environments
- ✅ Independent Terraform state files
- ✅ No risk of deploying to the wrong environment
- ✅ Easy to manage different configurations

**See the [detailed guide](examples/aws-eks/README.md#managing-multiple-environments-dev-staging-prod) for more information.**

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
  description = "Load balancer hostname (for DNS configuration)"
  value       = module.sligo_aws.ingress_hostname
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (if auto-created)"
  value       = module.sligo_aws.acm_certificate_arn
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate"
  value       = module.sligo_aws.acm_certificate_validation_records
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

To upgrade to a new version:

1. **Check available versions** in Google Artifact Registry or contact Sligo support
2. **Update `app_version`** in your `terraform.tfvars`:
   ```hcl
   app_version = "v1.2.3"  # Update to new version tag
   ```
3. **Apply the changes**:
   ```bash
   terraform plan  # Review changes
   terraform apply # Apply upgrade
   ```

**Important:**
- Always use version tags (e.g., `v1.0.0`, `v1.2.3`) for production deployments
- Avoid using `latest` in production as it can cause unexpected updates
- Test upgrades in a non-production environment first

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

## 📌 Versioning and Image Tags

Sligo Cloud uses semantic versioning for container images. When you set `app_version` in your Terraform configuration, it determines which container image versions are deployed.

### Available Versions

Container images are tagged with version tags (e.g., `v1.0.0`, `v1.2.3`) when Sligo releases new versions. You can:

1. **Check available versions** in your Google Artifact Registry:
   ```bash
   gcloud artifacts docker images list \
     us-central1-docker.pkg.dev/sligo-ai-platform/<your-repository-name>/sligo-backend \
     --format="table(tags)"
   ```

2. **Contact Sligo support** (support@sligo.ai) to get a list of available versions

### Using Version Tags

**Production deployments** should always pin to a specific version:
```hcl
app_version = "v1.0.0"  # Pin to specific version
```

**Development/testing** can use `latest` (not recommended for production):
```hcl
app_version = "latest"  # Development only
```

### Upgrading Versions

When upgrading to a new version:

1. Update `app_version` in `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Run `terraform apply` to deploy the new version
4. Monitor the deployment for any issues

**Best Practice:** Test upgrades in a non-production environment first.

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
