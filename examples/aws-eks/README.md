# AWS EKS Deployment

Complete example for deploying Sligo Cloud on AWS EKS using Terraform.

## Prerequisites

Before you begin, ensure you have:

1. **AWS CLI configured** with appropriate credentials
   ```bash
   aws configure
   ```

2. **Terraform installed** (version >= 1.0)
   ```bash
   terraform version
   ```

3. **kubectl installed** and configured (will be configured after cluster creation)

4. **Sligo Service Account Key** - JSON file provided by Sligo support
   - Contact support@sligo.ai to receive your service account key
   - This key allows your Kubernetes cluster to pull container images from Sligo's Google Artifact Registry (GAR)

5. **Container Repository Name** - Provided by Sligo
   - This is your unique repository name in Sligo's Google Artifact Registry
   - Example: `your-company-containers` or `client-abc-containers`

6. **Domain name** for your application (e.g., `app.example.com`)

## Step-by-Step Deployment Guide

### Step 1: Get Your Sligo Credentials

Before starting, you need two things from Sligo:

1. **Service Account Key (JSON file)**
   - Contact support@sligo.ai to receive your service account key
   - This is a JSON file that authenticates your cluster to pull images from Sligo's Google Artifact Registry

2. **Container Repository Name**
   - This is your unique repository name in Sligo's Google Artifact Registry
   - Example format: `your-company-containers` or `client-abc-containers`
   - You'll use this in the `client_repository_name` variable

### Step 2: Set Up Your Project Directory

```bash
# Navigate to the AWS EKS example directory
cd examples/aws-eks

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars
```

### Step 3: Add Your Sligo Service Account Key

**Important:** The service account key file must be placed in your project directory.

1. **Place the JSON key file** in the `examples/aws-eks/` directory
   - Name it something like `sligo-service-account-key.json`
   - **Note:** This file is automatically ignored by git (see `.gitignore`) for security

2. **Verify the file exists:**
   ```bash
   ls -la sligo-service-account-key.json
   ```

3. **Update `terraform.tfvars`** to point to this file:
   ```hcl
   sligo_service_account_key_path = "./sligo-service-account-key.json"
   ```

### Step 4: Configure Your Variables

Edit `terraform.tfvars` with your specific values:

**Required Configuration:**

```hcl
# Cluster Configuration
cluster_name    = "sligo-production"  # Your cluster name
cluster_version = "1.29"
aws_region      = "us-east-1"          # Your preferred AWS region

# Application Configuration
domain_name              = "app.example.com"              # Your domain
client_repository_name   = "your-client-containers"       # From Sligo support
sligo_service_account_key_path = "./sligo-service-account-key.json"  # Path to your key file
app_version              = "1.0.0"                        # Sligo Cloud version

# Database Configuration
db_password = "your-secure-password"  # Generate a strong password

# Required Secrets (generate secure random values)
jwt_secret          = "generate-with-openssl-rand-hex-32"
api_key             = "generate-with-openssl-rand-hex-32"
nextauth_secret     = "generate-with-openssl-rand-hex-32"
gateway_secret      = "generate-with-openssl-rand-hex-32"
encryption_key      = "generate-with-openssl-rand-hex-32"  # Must be 64 hex characters

# URLs
frontend_url        = "https://app.example.com"
next_public_api_url = "https://api.example.com"
```

**Generate secure secrets:**
```bash
# Generate encryption key (64 hex characters)
openssl rand -hex 32

# Generate other secrets
openssl rand -hex 32
```

### Step 5: Initialize Terraform

```bash
terraform init
```

This downloads the required Terraform providers and modules.

### Step 6: Review the Deployment Plan

```bash
terraform plan
```

This shows you what resources will be created. Review carefully to ensure:
- Cluster name is correct
- Region is correct
- Domain name is correct
- Service account key path is correct

### Step 7: Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will:
- Create the EKS cluster (takes 10-15 minutes)
- Create RDS database
- Create ElastiCache Redis
- Create S3 bucket
- Set up networking (VPC, subnets, security groups)
- Create ACM certificate
- Deploy the Sligo Cloud application

**Note:** The entire deployment takes approximately 15-20 minutes.

### Step 8: Configure DNS

After deployment completes:

1. **Get the DNS validation records** (if using automatic certificate):
   ```bash
   terraform output acm_certificate_validation_records
   ```

2. **Add CNAME records** to your DNS provider:
   - Copy the validation records from the output above
   - Add them to your DNS provider (e.g., GoDaddy, Route53, Cloudflare)
   - Wait 5-10 minutes for DNS propagation

3. **Get the ALB hostname:**
   ```bash
   terraform output ingress_hostname
   ```

4. **Point your domain to the ALB:**
   - Add a CNAME record: `app.example.com` → `<alb-hostname>`
   - Or add an A record pointing to the ALB IP

5. **Wait for certificate validation:**
   - Check certificate status: `aws acm list-certificates --region us-east-1`
   - Once validated, HTTPS will be enabled automatically

### Step 9: Verify Deployment

```bash
# Configure kubectl to use your new cluster
aws eks update-kubeconfig --name <your-cluster-name> --region <your-region>

# Check all pods are running
kubectl get pods -n sligo

# Check ingress
kubectl get ingress -n sligo

# View application logs
kubectl logs -n sligo deployment/sligo-app --tail=50
```

### Step 10: Access Your Application

Once DNS is configured and the certificate is validated:
- Visit `https://your-domain.com`
- You should see the Sligo Cloud login page

## Understanding Container Registry Access

Sligo Cloud containers are stored in **Google Artifact Registry (GAR)**. Here's how access works:

1. **Sligo provides you with:**
   - A JSON service account key file (for authentication)
   - Your container repository name (e.g., `your-client-containers`)

2. **You place the key file** in your project directory (e.g., `./sligo-service-account-key.json`)

3. **Terraform automatically:**
   - Reads the key file
   - Creates a Kubernetes image pull secret
   - Configures your pods to use this secret to pull images from GAR

4. **The container images are pulled from:**
   ```
   us-central1-docker.pkg.dev/<your-repository-name>/nextjs:<version>
   us-central1-docker.pkg.dev/<your-repository-name>/backend:<version>
   us-central1-docker.pkg.dev/<your-repository-name>/mcp-gateway:<version>
   ```

**Important Notes:**
- The service account key file is **never committed to git** (it's in `.gitignore`)
- The key file must be present when running `terraform apply`
- If you lose the key file, contact Sligo support for a new one
- The repository name (`client_repository_name`) must match exactly what Sligo provided

## What Gets Provisioned

### Infrastructure
- **EKS Cluster** - Managed Kubernetes cluster
- **RDS PostgreSQL** - Managed database instance
- **ElastiCache Redis** - Managed Redis cache
- **S3 Bucket** - Object storage for file management
- **VPC & Networking** - VPC, subnets, security groups (if not using existing)
- **ACM Certificate** - SSL/TLS certificate (auto-created or provided)
- **Application Load Balancer (ALB)** - Internet-facing load balancer with HTTPS

### Kubernetes Resources
- **Namespace** - `sligo` namespace for all resources
- **Image Pull Secret** - For Google Artifact Registry authentication
- **Secrets** - Application secrets (database, API keys, etc.)
- **Helm Release** - Sligo Cloud application deployment
- **AWS Load Balancer Controller** - Automatically installed and configured
- **Ingress** - Routes traffic from ALB to application pods
- **Security Group Rules** - Allows ALB to communicate with pods

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | EKS cluster name | `sligo-production` |
| `domain_name` | Domain for your application | `app.example.com` |
| `client_repository_name` | Your GAR repository name (provided by Sligo) | `your-client-containers` |
| `sligo_service_account_key_path` | Path to Sligo service account key JSON file (place in this directory) | `./sligo-service-account-key.json` |
| `db_password` | Database password | `secure-password-123` |
| `jwt_secret` | JWT secret for backend | `your-jwt-secret` |
| `api_key` | API key | `your-api-key` |
| `nextauth_secret` | NextAuth secret | `your-nextauth-secret` |
| `gateway_secret` | MCP Gateway secret | `your-gateway-secret` |
| `frontend_url` | Frontend URL | `https://app.example.com` |
| `next_public_api_url` | Public API URL | `https://api.example.com` |
| `encryption_key` | 64-character hex encryption key | Generate with `openssl rand -hex 32` |

### Optional Variables

#### Prisma Accelerate
- `prisma_accelerate_url` - Prisma Accelerate connection URL (if not provided, uses direct PostgreSQL connection)

#### HTTPS/SSL
- `acm_certificate_arn` - Existing ACM certificate ARN (if not provided, certificate is auto-created)

#### WorkOS Authentication
- `workos_api_key` - WorkOS API key
- `workos_client_id` - WorkOS Client ID
- `workos_cookie_password` - WorkOS cookie password

#### Google Cloud Integration
- `next_public_google_client_id` - Google OAuth Client ID
- `next_public_google_client_key` - Google OAuth Client Key
- `google_client_secret` - Google OAuth Client Secret
- `google_project_id` - Google Cloud Project ID
- `google_api_key` - Google API Key
- `google_storage_bucket` - Google Storage bucket name
- `google_storage_agent_avatars_bucket` - Bucket for agent avatars
- `google_storage_mcp_logos_bucket` - Bucket for MCP logos
- `google_storage_rag_sa_key` - Google Storage RAG Service Account Key (JSON)
- `file_manager_google_projectid` - File Manager Google Project ID

#### Pinecone
- `pinecone_api_key` - Pinecone API key
- `pinecone_index` - Pinecone index name

#### Other Services
- `openai_api_key` - OpenAI API key
- `gcp_sa_key` - GCP Service Account Key (JSON)
- `onedrive_client_secret` - OneDrive OAuth Client Secret
- `next_public_onedrive_client_id` - OneDrive OAuth Client ID

See `terraform.tfvars.example` for complete list of available variables.

## Key Features

### Automatic AWS Load Balancer Controller Installation

The module automatically:
- Creates IAM role and policy for the controller
- Creates Kubernetes service account with IAM role annotation
- Installs the AWS Load Balancer Controller via Helm
- Configures the controller to manage ALB resources

### Automatic ACM Certificate Creation

If `acm_certificate_arn` is not provided:
- Creates a DNS-validated ACM certificate
- Outputs DNS validation records for your domain
- Configures HTTPS listeners and SSL redirect on the ALB

### Simplified Ingress Routing

All traffic is routed to the Next.js app:
- `/` → Next.js app (handles all routes including `/api/*`)
- All `/api/*` routes are handled by Next.js API routes
- Backend and MCP Gateway are accessed internally via service DNS

### Security Group Rules

Automatically configures security group rules to allow:
- ALB → App pods (port 3000)
- ALB → Backend pods (port 3001)
- ALB → MCP Gateway pods (port 3002)

### Health Checks

Service-specific health check paths:
- App: `/api/health`
- Backend: `/health`
- MCP Gateway: `/health`

## DNS Configuration

### Option 1: Automatic Certificate (Recommended)

1. Run `terraform apply`
2. Get validation records:
   ```bash
   terraform output acm_certificate_validation_records
   ```
3. Add CNAME records to your DNS provider (e.g., GoDaddy)
4. Wait for certificate validation (usually 5-10 minutes)
5. Point your domain to the ALB:
   ```bash
   kubectl get ingress -n sligo
   # Add CNAME record: your-domain.com → ALB hostname
   ```

### Option 2: Existing Certificate

1. Create ACM certificate manually in AWS Console
2. Set `acm_certificate_arn` in `terraform.tfvars`
3. Run `terraform apply`
4. Point your domain to the ALB hostname

## Outputs

After deployment, Terraform outputs:

- `application_url` - Your application URL
- `cluster_endpoint` - Kubernetes cluster API endpoint
- `database_endpoint` - RDS PostgreSQL endpoint
- `ingress_hostname` - ALB hostname (for DNS configuration)
- `acm_certificate_arn` - ACM certificate ARN (if auto-created)
- `acm_certificate_validation_records` - DNS validation records (if auto-created)

## Post-Deployment

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n sligo

# Check ingress
kubectl get ingress -n sligo

# Check services
kubectl get svc -n sligo

# View application logs
kubectl logs -n sligo deployment/sligo-app --tail=50
```

### Update Secrets

If you need to update environment variables:

1. Update values in `terraform.tfvars`
2. Run `terraform apply`
3. Restart pods:
   ```bash
   kubectl rollout restart deployment/sligo-app -n sligo
   kubectl rollout restart deployment/sligo-backend -n sligo
   ```

### Access the Application

Once DNS is configured and certificate is validated:
- Visit `https://your-domain.com`
- You should see the Sligo Cloud login page

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n sligo

# View pod events
kubectl describe pod <pod-name> -n sligo

# Check logs
kubectl logs <pod-name> -n sligo
```

### Common Issues

1. **"Invalid key length" error** - `encryption_key` must be exactly 64 hex characters. Generate with `openssl rand -hex 32`

2. **"Prisma API Key invalid"** - Check `prisma_accelerate_url` is correct and API key is valid

3. **"Cannot GET /api/workos/callback"** - This should be resolved with the simplified ingress routing. Verify ingress routes `/` to app service.

4. **504 Gateway Timeout** - Check:
   - Security group rules allow ALB → pods
   - Pods are running and healthy
   - Health check paths are correct

5. **Certificate validation pending** - Ensure DNS CNAME records are added and propagated

### Viewing Logs

```bash
# App logs
kubectl logs -n sligo deployment/sligo-app --tail=100

# Backend logs
kubectl logs -n sligo deployment/sligo-backend --tail=100

# MCP Gateway logs
kubectl logs -n sligo deployment/mcp-gateway --tail=100

# Ingress events
kubectl describe ingress -n sligo
```

### Checking ALB Status

```bash
# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?contains(LoadBalancerName, 'sligo')].LoadBalancerArn" --output text)

# Check target health
aws elbv2 describe-target-groups --region us-east-1 --load-balancer-arn "$ALB_ARN" --query "TargetGroups[*].TargetGroupArn" --output text | xargs -I {} aws elbv2 describe-target-health --target-group-arn {} --region us-east-1
```

## Architecture

```
Internet
   │
   ▼
ALB (Application Load Balancer)
   │ HTTPS (ACM Certificate)
   ▼
Ingress (Kubernetes)
   │
   ▼
Next.js App (Port 3000)
   ├── Handles all routes (/)
   ├── API routes (/api/*)
   └── Calls Backend internally
       │
       ▼
   Backend (Port 3001)
       └── Calls MCP Gateway internally
           │
           ▼
       MCP Gateway (Port 3002)
```

**Internal Communication:**
- Frontend → Backend: `http://sligo-backend:3001`
- Backend → MCP Gateway: `http://mcp-gateway:3002`
- All services → Database: RDS PostgreSQL
- All services → Cache: ElastiCache Redis

## Security Considerations

- **Secrets Management**: Use AWS Secrets Manager or similar in production
- **Network Security**: Security groups restrict access to necessary ports only
- **HTTPS**: Always use HTTPS in production (automatic with ACM)
- **IAM Roles**: Least privilege IAM roles for service accounts
- **Encryption**: Encryption key must be securely generated and stored

## Next Steps

1. Configure all required environment variables in `terraform.tfvars`
2. Run `terraform apply`
3. Configure DNS as described above
4. Access your application at `https://your-domain.com`

## Managing Multiple Environments (Dev, Staging, Prod)

If you need to deploy multiple instances of Sligo Cloud (e.g., dev, staging, and production), you have two options:

### Option 1: Separate Directories (Recommended)

Create separate directories for each environment:

```
examples/
├── aws-eks/
│   ├── main.tf
│   ├── terraform.tfvars.example
│   └── ...
├── aws-eks-dev/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── sligo-service-account-key.json
├── aws-eks-staging/
│   ├── main.tf
│   ├── terraform.tfvars
│   └── sligo-service-account-key.json
└── aws-eks-prod/
    ├── main.tf
    ├── terraform.tfvars
    └── sligo-service-account-key.json
```

**Setup Steps:**

1. **Copy the example directory for each environment:**
   ```bash
   cp -r examples/aws-eks examples/aws-eks-dev
   cp -r examples/aws-eks examples/aws-eks-staging
   cp -r examples/aws-eks examples/aws-eks-prod
   ```

2. **Configure each environment's `terraform.tfvars`:**
   
   **Dev (`examples/aws-eks-dev/terraform.tfvars`):**
   ```hcl
   cluster_name    = "sligo-dev"
   domain_name     = "dev-app.example.com"
   db_instance_class = "db.t3.small"  # Smaller for dev
   # ... other dev-specific values
   ```
   
   **Staging (`examples/aws-eks-staging/terraform.tfvars`):**
   ```hcl
   cluster_name    = "sligo-staging"
   domain_name     = "staging-app.example.com"
   db_instance_class = "db.t3.medium"
   # ... other staging-specific values
   ```
   
   **Prod (`examples/aws-eks-prod/terraform.tfvars`):**
   ```hcl
   cluster_name    = "sligo-prod"
   domain_name     = "app.example.com"
   db_instance_class = "db.t3.large"  # Larger for prod
   # ... other prod-specific values
   ```

3. **Add service account key to each directory:**
   ```bash
   # Copy the same key file to each environment directory
   cp sligo-service-account-key.json examples/aws-eks-dev/
   cp sligo-service-account-key.json examples/aws-eks-staging/
   cp sligo-service-account-key.json examples/aws-eks-prod/
   ```

4. **Deploy each environment independently:**
   ```bash
   cd examples/aws-eks-dev
   terraform init
   terraform apply
   
   cd ../aws-eks-staging
   terraform init
   terraform apply
   
   cd ../aws-eks-prod
   terraform init
   terraform apply
   ```

**Benefits:**
- ✅ Clear separation of environments
- ✅ Independent Terraform state files
- ✅ Easy to manage different configurations
- ✅ Can deploy/update environments independently
- ✅ No risk of accidentally affecting the wrong environment

### Option 2: Terraform Workspaces (Advanced)

Use Terraform workspaces to manage multiple environments in the same directory:

```bash
cd examples/aws-eks

# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch to dev workspace
terraform workspace select dev

# Configure dev-specific values (use workspace-specific tfvars or variables)
terraform apply -var-file="dev.tfvars"

# Switch to prod workspace
terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```

**Note:** This approach requires careful management of workspace-specific variables and state files.

### Recommended Approach

**We recommend Option 1 (Separate Directories)** because:
- It's simpler and clearer for teams
- Less risk of deploying to the wrong environment
- Each environment has its own state file automatically
- Easier to understand and maintain
- Better for CI/CD pipelines (can deploy each environment independently)

### Environment-Specific Considerations

When setting up multiple environments, consider:

1. **Resource Sizing:**
   - Dev: Smaller instances (`db.t3.small`, `cache.t3.micro`)
   - Staging: Medium instances (similar to prod for testing)
   - Prod: Larger instances based on expected load

2. **Domain Names:**
   - Dev: `dev-app.example.com`
   - Staging: `staging-app.example.com`
   - Prod: `app.example.com`

3. **Service Account Key:**
   - You can use the **same** service account key for all environments
   - The key provides access to your container repository
   - All environments pull from the same repository

4. **Container Repository:**
   - All environments use the same `client_repository_name`
   - Different environments can use different `app_version` if needed

5. **Secrets:**
   - Use **different** secrets for each environment
   - Never reuse production secrets in dev/staging

For more details, see the [module documentation](../../modules/aws/eks/README.md).
