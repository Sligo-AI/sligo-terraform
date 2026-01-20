# Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Configuration (create if not provided)
data "aws_vpc" "selected" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

resource "aws_vpc" "main" {
  count                = var.vpc_id == "" ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# Subnets (create if not provided)
data "aws_subnets" "selected" {
  count = length(var.subnet_ids) > 0 ? 1 : 0
  filter {
    name   = "subnet-id"
    values = var.subnet_ids
  }
}

resource "aws_subnet" "private" {
  count             = var.vpc_id == "" ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                              = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  count                   = var.vpc_id == "" ? 2 : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Internet Gateway (if creating VPC)
resource "aws_internet_gateway" "main" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# Route Table (if creating VPC)
resource "aws_route_table" "public" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.vpc_id == "" ? 2 : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Elastic IPs for NAT Gateways (if creating VPC)
resource "aws_eip" "nat" {
  count  = var.vpc_id == "" ? 2 : 0
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways (if creating VPC)
resource "aws_nat_gateway" "main" {
  count         = var.vpc_id == "" ? 2 : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Private Route Tables (if creating VPC)
resource "aws_route_table" "private" {
  count  = var.vpc_id == "" ? 2 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.vpc_id == "" ? 2 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : concat(aws_subnet.private[*].id, aws_subnet.public[*].id)

  cluster_endpoint_public_access = true

  # Enable access entries API (required for EKS clusters to allow nodes to join)
  # This ensures node groups can automatically join the cluster
  authentication_mode = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"]
      
      # Use public subnets for node groups to ensure they can reach EKS API endpoint
      # This prevents timeout issues during node group creation
      # Alternatively, if using private subnets, ensure NAT Gateway is configured (see above)
      subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : aws_subnet.public[*].id
      
      # Ensure node group version matches cluster version
      # This prevents AMI compatibility issues
      update_config = {
        max_unavailable_percentage = 33
      }
      
      # Attach cluster's primary security group to node group
      # This ensures proper communication between nodes and cluster
      attach_cluster_primary_security_group = true
      
      # Add Kubernetes labels and tags
      labels = {
        nodegroup = "main"
      }
      
      tags = {
        Name = "${var.cluster_name}-main-node-group"
      }
    }
  }

  tags = {
    Name = var.cluster_name
  }
}

# RDS Database
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : aws_subnet.private[*].id

  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id != "" ? data.aws_vpc.selected[0].cidr_block : aws_vpc.main[0].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.cluster_name}-postgres"
  engine                 = "postgres"
  engine_version         = "15.15"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_encrypted      = true
  db_name                = "sligo"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "${var.cluster_name}-postgres"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.cluster_name}-redis-subnet-group"
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : aws_subnet.private[*].id
}

resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_id != "" ? data.aws_vpc.selected[0].cidr_block : aws_vpc.main[0].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-redis-sg"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.cluster_name}-redis"
  description                = "Redis cluster for ${var.cluster_name}"
  node_type                  = var.redis_node_type
  port                       = 6379
  parameter_group_name       = "default.redis7"
  num_cache_clusters         = 1
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = {
    Name = "${var.cluster_name}-redis"
  }
}

# Wait for cluster to be fully ready before Kubernetes operations
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    module.eks,
    module.eks.eks_managed_node_groups
  ]

  create_duration = "30s"
}

# Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}

# Helm Provider Configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name
      ]
    }
  }
}

# Kubernetes Namespace
resource "kubernetes_namespace" "sligo" {
  metadata {
    name = "sligo"
    labels = {
      app = "sligo-cloud"
    }
  }

  # Wait for cluster to be fully ready
  depends_on = [time_sleep.wait_for_cluster]
}

# Image Pull Secret for GAR
resource "kubernetes_secret" "gar_pull_secret" {
  metadata {
    name      = "gar-pull-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "us-docker.pkg.dev" = {
          username = "_json_key"
          password = file(var.sligo_service_account_key_path)
          auth     = base64encode("_json_key:${file(var.sligo_service_account_key_path)}")
        }
      }
    })
  }
}

# Application Secrets
resource "kubernetes_secret" "nextjs_secrets" {
  metadata {
    name      = "nextjs-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    NEXT_PUBLIC_API_URL = var.next_public_api_url
    FRONTEND_URL        = var.frontend_url
    NEXTAUTH_SECRET     = var.nextauth_secret
  }
}

resource "kubernetes_secret" "backend_secrets" {
  metadata {
    name      = "backend-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    JWT_SECRET = var.jwt_secret
    API_KEY    = var.api_key
  }
}

resource "kubernetes_secret" "mcp_gateway_secrets" {
  metadata {
    name      = "mcp-gateway-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    SECRET = var.gateway_secret
  }
}

# Database Secret
resource "kubernetes_secret" "database_secret" {
  metadata {
    name      = "database-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    host     = aws_db_instance.postgres.address
    port     = tostring(aws_db_instance.postgres.port)
    database = aws_db_instance.postgres.db_name
    username = aws_db_instance.postgres.username
    password = aws_db_instance.postgres.password
  }
}

# Redis Secret
resource "kubernetes_secret" "redis_secret" {
  metadata {
    name      = "redis-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    host = aws_elasticache_replication_group.redis.configuration_endpoint_address
    port = tostring(aws_elasticache_replication_group.redis.port)
  }
}

# S3 Bucket for Application Storage
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Data source to check if bucket exists (optional, for existing buckets)
data "aws_s3_bucket" "existing" {
  count  = var.s3_bucket_name != "" && var.use_existing_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket" "app_storage" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.cluster_name}-storage-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.cluster_name}-storage"
    Environment = "production"
  }
}

# Local to get the bucket ID and ARN (either existing or newly created)
locals {
  s3_bucket_id  = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing[0].id : aws_s3_bucket.app_storage[0].id
  s3_bucket_arn = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing[0].arn : aws_s3_bucket.app_storage[0].arn
}

resource "aws_s3_bucket_versioning" "app_storage" {
  count  = var.s3_bucket_versioning && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  count  = var.s3_bucket_encryption && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = local.s3_bucket_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for S3 Access (for use by pods)
resource "aws_iam_role" "s3_access" {
  name = "${var.cluster_name}-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${kubernetes_namespace.sligo.metadata[0].name}:s3-access"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.cluster_name}-s3-access-policy"
  role = aws_iam_role.s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          local.s3_bucket_arn,
          "${local.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# S3 Bucket Secret for Kubernetes
resource "kubernetes_secret" "s3_secret" {
  metadata {
    name      = "s3-storage-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    bucket_name = local.s3_bucket_id
    bucket_arn  = local.s3_bucket_arn
    region      = var.aws_region
    role_arn    = aws_iam_role.s3_access.arn
  }
}

# Helm Release for Sligo Cloud
resource "helm_release" "sligo_cloud" {
  name       = "sligo-cloud"
  repository = "https://sligo-ai.github.io/sligo-helm-charts"
  chart      = "sligo-cloud"
  version    = var.app_version
  namespace  = kubernetes_namespace.sligo.metadata[0].name
  timeout    = 600 # 10 minutes timeout

  values = [
    yamlencode({
      ingress = {
        enabled = true
        hosts = [
          {
            host  = var.domain_name
            paths = ["/"]
          }
        ]
        annotations = {
          "kubernetes.io/ingress.class"           = "alb"
          "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
        }
      }

      imagePullSecrets = [
        {
          name = kubernetes_secret.gar_pull_secret.metadata[0].name
        }
      ]

      app = {
        image = {
          repository = "us-docker.pkg.dev/${var.client_repository_name}/nextjs"
          tag        = var.app_version
        }
        secretName = kubernetes_secret.nextjs_secrets.metadata[0].name
      }

      backend = {
        image = {
          repository = "us-docker.pkg.dev/${var.client_repository_name}/backend"
          tag        = var.app_version
        }
        envFrom = [
          {
            secretRef = {
              name = kubernetes_secret.backend_secrets.metadata[0].name
            }
          }
        ]
        database = {
          host     = aws_db_instance.postgres.address
          port     = aws_db_instance.postgres.port
          database = aws_db_instance.postgres.db_name
          username = aws_db_instance.postgres.username
          password = aws_db_instance.postgres.password
        }
        redis = {
          host = aws_elasticache_replication_group.redis.configuration_endpoint_address
          port = aws_elasticache_replication_group.redis.port
        }
      }

      mcpGateway = {
        image = {
          repository = "us-docker.pkg.dev/${var.client_repository_name}/mcp-gateway"
          tag        = var.app_version
        }
        envFrom = [
          {
            secretRef = {
              name = kubernetes_secret.mcp_gateway_secrets.metadata[0].name
            }
          }
        ]
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster,
    kubernetes_secret.gar_pull_secret,
    kubernetes_secret.nextjs_secrets,
    kubernetes_secret.backend_secrets,
    kubernetes_secret.mcp_gateway_secrets,
    kubernetes_secret.database_secret,
    kubernetes_secret.redis_secret
  ]
}
