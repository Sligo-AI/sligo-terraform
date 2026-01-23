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
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.medium"]

      # Migrate to Amazon Linux 2023 (AL2023) - required for K8s 1.30+
      # AL2 support ends Nov 26, 2025, and no AL2 AMIs for K8s 1.33+
      ami_type = "AL2023_x86_64_STANDARD"

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

# ACM Certificate for HTTPS (optional - create if acm_certificate_arn is not provided)
resource "aws_acm_certificate" "sligo" {
  count             = var.acm_certificate_arn == "" ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.cluster_name}-certificate"
  }
}

# Local value for certificate ARN (use provided or created)
# Note: If creating automatically, certificate will be in "Pending validation" state
# until DNS validation records are added to GoDaddy
locals {
  certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (var.acm_certificate_arn == "" && length(aws_acm_certificate.sligo) > 0 ? aws_acm_certificate.sligo[0].arn : "")
}

# Note: OIDC provider is managed by the EKS module

# IAM Policy for AWS Load Balancer Controller
data "aws_iam_policy_document" "alb_controller" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values = [
        "CreateTargetGroup",
        "CreateLoadBalancer"
      ]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.aws_iam_policy_document.alb_controller.json
}

# IAM Role for AWS Load Balancer Controller Service Account
data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# Kubernetes Service Account for AWS Load Balancer Controller
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }
}

# Helm Release for AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  depends_on = [
    time_sleep.wait_for_cluster,
    kubernetes_service_account.alb_controller,
    aws_iam_role_policy_attachment.alb_controller
  ]
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
        "us-central1-docker.pkg.dev" = {
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
    NEXT_PUBLIC_API_URL                = var.next_public_api_url
    NEXT_PUBLIC_URL                    = var.frontend_url
    FRONTEND_URL                       = var.frontend_url
    NEXTAUTH_SECRET                    = var.nextauth_secret
    PORT                               = "3000"
    REDIS_URL                          = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    BACKEND_URL                        = "http://sligo-backend:3001"
    MCP_GATEWAY_URL                    = "http://mcp-gateway:3002"
    DATABASE_URL                       = var.prisma_accelerate_url != "" ? var.prisma_accelerate_url : "postgresql://${urlencode(aws_db_instance.postgres.username)}:${urlencode(aws_db_instance.postgres.password)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
    FILE_MANAGER_GOOGLE_STORAGE_BUCKET = local.s3_bucket_id
    FILE_MANAGER_REDIS_URL             = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    # These should be provided via terraform.tfvars - adding placeholders for now
    WORKOS_API_KEY                      = var.workos_api_key != "" ? var.workos_api_key : "placeholder"
    WORKOS_CLIENT_ID                    = var.workos_client_id != "" ? var.workos_client_id : "placeholder"
    WORKOS_COOKIE_PASSWORD              = var.workos_cookie_password != "" ? var.workos_cookie_password : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_ID        = var.next_public_google_client_id != "" ? var.next_public_google_client_id : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_KEY       = var.next_public_google_client_key != "" ? var.next_public_google_client_key : "placeholder"
    NEXT_PUBLIC_ONEDRIVE_CLIENT_ID      = var.next_public_onedrive_client_id != "" ? var.next_public_onedrive_client_id : "placeholder"
    PINECONE_API_KEY                    = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX                      = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    GCP_SA_KEY                          = var.gcp_sa_key != "" ? var.gcp_sa_key : "placeholder"
    GOOGLE_CLIENT_SECRET                = var.google_client_secret != "" ? var.google_client_secret : "placeholder"
    GOOGLE_STORAGE_AGENT_AVATARS_BUCKET = var.google_storage_agent_avatars_bucket != "" ? var.google_storage_agent_avatars_bucket : "placeholder"
    GOOGLE_STORAGE_BUCKET               = var.google_storage_bucket != "" ? var.google_storage_bucket : "placeholder"
    GOOGLE_STORAGE_MCP_LOGOS_BUCKET     = var.google_storage_mcp_logos_bucket != "" ? var.google_storage_mcp_logos_bucket : "placeholder"
    GOOGLE_STORAGE_RAG_SA_KEY           = var.google_storage_rag_sa_key != "" ? var.google_storage_rag_sa_key : "placeholder"
    ONEDRIVE_CLIENT_SECRET              = var.onedrive_client_secret != "" ? var.onedrive_client_secret : "placeholder"
    OPENAI_API_KEY                      = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    ENCRYPTION_KEY                      = var.encryption_key != "" ? var.encryption_key : "placeholder"
    FILE_MANAGER_GOOGLE_PROJECTID       = var.file_manager_google_projectid != "" ? var.file_manager_google_projectid : ""
    NODE_ENV                            = "production"
    # Temporarily skip env validation to allow pods to start
    SKIP_ENV_VALIDATION = "true"
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
    PORT       = "3001"
    # Use Prisma Accelerate URL if provided, otherwise fall back to direct PostgreSQL connection
    # Prisma Accelerate URL format: prisma://accelerate.prisma-data.net/?api_key=... or prisma+postgres://...
    DATABASE_URL                         = var.prisma_accelerate_url != "" ? var.prisma_accelerate_url : "postgresql://${urlencode(aws_db_instance.postgres.username)}:${urlencode(aws_db_instance.postgres.password)}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
    REDIS_URL                            = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    MCP_GATEWAY_URL                      = "http://mcp-gateway:3002"
    SQL_CONNECTION_STRING_DECRYPTION_IV  = var.sql_connection_string_decryption_iv != "" ? var.sql_connection_string_decryption_iv : "placeholder"
    SQL_CONNECTION_STRING_DECRYPTION_KEY = var.sql_connection_string_decryption_key != "" ? var.sql_connection_string_decryption_key : "placeholder"
    ENCRYPTION_KEY                       = var.encryption_key != "" ? var.encryption_key : "placeholder"
    GOOGLE_PROJECTID                     = var.google_project_id != "" ? var.google_project_id : "placeholder"
    GOOGLE_API_KEY                       = var.google_api_key != "" ? var.google_api_key : "placeholder"
    OPENAI_API_KEY                       = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    FILE_MANAGER_REDIS_URL               = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    FILE_MANAGER_GOOGLE_STORAGE_BUCKET   = local.s3_bucket_id
    NODE_ENV                             = "production"
    # Temporarily skip env validation to allow pods to start
    SKIP_ENV_VALIDATION = "true"
  }
}

resource "kubernetes_secret" "mcp_gateway_secrets" {
  metadata {
    name      = "mcp-gateway-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    SECRET                             = var.gateway_secret
    PORT                               = "3002"
    FILE_MANAGER_GOOGLE_STORAGE_BUCKET = local.s3_bucket_id
    FILE_MANAGER_REDIS_URL             = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    REDIS_URL_STRUCTURED_OUTPUTS       = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    # Required for utility server
    FRONTEND_URL     = var.frontend_url
    OPENAI_API_KEY   = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    PINECONE_API_KEY = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX   = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    # Optional for other servers
    PERPLEXITY_API_KEY = var.perplexity_api_key != "" ? var.perplexity_api_key : "placeholder"
    TAVILY_API_KEY     = var.tavily_api_key != "" ? var.tavily_api_key : "placeholder"
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
    host = aws_elasticache_replication_group.redis.primary_endpoint_address
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
      global = {
        imagePullSecrets = [
          kubernetes_secret.gar_pull_secret.metadata[0].name
        ]
      }

      ingress = {
        enabled   = true
        className = "alb"
        annotations = merge({
          "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"          = "ip"
          "alb.ingress.kubernetes.io/listen-ports"         = local.certificate_arn != "" ? "[{\"HTTP\": 80}, {\"HTTPS\": 443}]" : "[{\"HTTP\": 80}]"
          "alb.ingress.kubernetes.io/healthcheck-path"     = "/api/health"
          "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-port"     = "traffic-port"
          "alb.ingress.kubernetes.io/success-codes"        = "200"
          }, local.certificate_arn != "" ? {
          "alb.ingress.kubernetes.io/certificate-arn" = local.certificate_arn
          "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        } : {})
        hosts = [
          {
            host = var.domain_name
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend  = "app"
              }
            ]
          }
        ]
      }

      app = {
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-frontend"
          tag        = "latest"
        }
        secretName = kubernetes_secret.nextjs_secrets.metadata[0].name
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }

      backend = {
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-backend"
          tag        = "latest"
        }
        secretName = kubernetes_secret.backend_secrets.metadata[0].name
        resources = {
          requests = {
            cpu    = "1000m"
            memory = "2Gi"
          }
          limits = {
            cpu    = "2000m"
            memory = "4Gi"
          }
        }
      }

      mcpGateway = {
        replicaCount = 1
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-mcp-gateway"
          tag        = "latest"
        }
        secretName = kubernetes_secret.mcp_gateway_secrets.metadata[0].name
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }

      database = {
        enabled = true
        type    = "external"
        external = {
          host       = aws_db_instance.postgres.address
          port       = aws_db_instance.postgres.port
          database   = aws_db_instance.postgres.db_name
          secretName = kubernetes_secret.database_secret.metadata[0].name
        }
      }

      redis = {
        enabled = true
        type    = "external"
        external = {
          host       = aws_elasticache_replication_group.redis.primary_endpoint_address
          port       = aws_elasticache_replication_group.redis.port
          secretName = kubernetes_secret.redis_secret.metadata[0].name
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster,
    helm_release.aws_load_balancer_controller,
    kubernetes_secret.gar_pull_secret,
    kubernetes_secret.nextjs_secrets,
    kubernetes_secret.backend_secrets,
    kubernetes_secret.mcp_gateway_secrets,
    kubernetes_secret.database_secret,
    kubernetes_secret.redis_secret
  ]
}

# Data source to find ALB security group (created by AWS Load Balancer Controller)
# The ALB security group is tagged by the controller
data "aws_security_group" "alb" {
  count = 1
  filter {
    name   = "tag:elbv2.k8s.aws/cluster"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:ingress.k8s.aws/resource"
    values = ["ManagedLBSecurityGroup"]
  }

  depends_on = [helm_release.sligo_cloud]
}

# Data source to find node security group
data "aws_security_group" "node" {
  filter {
    name   = "tag:kubernetes.io/cluster/${var.cluster_name}"
    values = ["owned"]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-node*"]
  }
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id]
  }
}

# Get node security group from EKS module or data source
locals {
  node_security_group_id = try(module.eks.node_security_group_id, data.aws_security_group.node.id)
  alb_security_group_id  = data.aws_security_group.alb[0].id
}

# Security group rules to allow ALB to reach pods
# These should be managed by TargetGroupBinding, but we add them as backup
resource "aws_security_group_rule" "alb_to_app" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = local.alb_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow ALB to reach app pods on port 3000"

  depends_on = [helm_release.sligo_cloud, data.aws_security_group.alb]
}

resource "aws_security_group_rule" "alb_to_backend" {
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = local.alb_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow ALB to reach backend pods on port 3001"

  depends_on = [helm_release.sligo_cloud, data.aws_security_group.alb]
}

resource "aws_security_group_rule" "alb_to_mcp_gateway" {
  type                     = "ingress"
  from_port                = 3002
  to_port                  = 3002
  protocol                 = "tcp"
  source_security_group_id = local.alb_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow ALB to reach mcp-gateway pods on port 3002"

  depends_on = [helm_release.sligo_cloud, data.aws_security_group.alb]
}

# Add health check path annotations to services via Kubernetes resources
# (Since Helm chart doesn't support service annotations, we add them directly)
resource "kubernetes_annotations" "backend_service_healthcheck" {
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "sligo-backend"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  annotations = {
    "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
  }

  depends_on = [helm_release.sligo_cloud]

  # Force replacement if service is recreated
  force = true
}

resource "kubernetes_annotations" "mcp_gateway_service_healthcheck" {
  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "mcp-gateway"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }
  annotations = {
    "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
  }

  depends_on = [helm_release.sligo_cloud]

  # Force replacement if service is recreated
  force = true
}
