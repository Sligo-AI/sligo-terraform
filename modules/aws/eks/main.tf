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
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      instance_types = var.node_group_instance_types

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

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "postgres" {
  cluster_identifier     = "${var.cluster_name}-postgres"
  engine                 = "aurora-postgresql"
  engine_version         = "15.15"
  database_name          = "sligo"
  master_username        = var.db_username
  master_password        = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  storage_encrypted      = true
  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = {
    Name = "${var.cluster_name}-postgres"
  }
}

# Aurora Serverless v2 Cluster Instance
resource "aws_rds_cluster_instance" "postgres" {
  identifier         = "${var.cluster_name}-postgres-instance-1"
  cluster_identifier = aws_rds_cluster.postgres.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.postgres.engine
  engine_version     = aws_rds_cluster.postgres.engine_version

  tags = {
    Name = "${var.cluster_name}-postgres-instance-1"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.cluster_name}-redis-subnet-group"
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : aws_subnet.private[*].id

  lifecycle {
    # Avoid changing subnet_ids while replication group is using them (SubnetInUse)
    ignore_changes = [subnet_ids]
  }
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
      "ec2:GetSecurityGroupsForVpc",
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

  data = merge({
    NEXT_PUBLIC_API_URL            = var.next_public_api_url
    NEXT_PUBLIC_URL                = var.frontend_url
    FRONTEND_URL                   = var.frontend_url
    NEXTAUTH_SECRET                = var.nextauth_secret
    PORT                           = "3000"
    REDIS_URL                      = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    BACKEND_URL                    = "http://sligo-backend:3001"
    MCP_GATEWAY_URL                = "http://mcp-gateway:3002"
    DATABASE_URL                   = "postgresql://${urlencode(aws_rds_cluster.postgres.master_username)}:${urlencode(aws_rds_cluster.postgres.master_password)}@${aws_rds_cluster.postgres.endpoint}:${aws_rds_cluster.postgres.port}/${aws_rds_cluster.postgres.database_name}"
    WORKOS_API_KEY                 = var.workos_api_key != "" ? var.workos_api_key : "placeholder"
    WORKOS_CLIENT_ID               = var.workos_client_id != "" ? var.workos_client_id : "placeholder"
    WORKOS_COOKIE_PASSWORD         = var.workos_cookie_password != "" ? var.workos_cookie_password : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_ID   = var.next_public_google_client_id != "" ? var.next_public_google_client_id : "placeholder"
    NEXT_PUBLIC_GOOGLE_CLIENT_KEY  = var.next_public_google_client_key != "" ? var.next_public_google_client_key : "placeholder"
    NEXT_PUBLIC_ONEDRIVE_CLIENT_ID = var.next_public_onedrive_client_id != "" ? var.next_public_onedrive_client_id : "placeholder"
    PINECONE_API_KEY               = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX                 = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    GOOGLE_CLIENT_SECRET           = var.google_client_secret != "" ? var.google_client_secret : "placeholder"
    ONEDRIVE_CLIENT_SECRET         = var.onedrive_client_secret != "" ? var.onedrive_client_secret : "placeholder"
    OPENAI_API_KEY                 = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    ENCRYPTION_KEY                 = var.encryption_key != "" ? var.encryption_key : "placeholder"
    BUCKET_NAME_AGENT_AVATARS      = local.s3_bucket_agent_avatars_id
    BUCKET_NAME_FILE_MANAGER       = local.s3_bucket_file_manager_id
    BUCKET_NAME_LOGOS              = local.s3_bucket_logos_id
    BUCKET_NAME_RAG                = local.s3_bucket_rag_id
    NODE_ENV                       = "production"
    SKIP_ENV_VALIDATION            = "true"
    # AWS S3 for EKS (we know these; optional keys omitted when using IRSA)
    AWS_REGION   = var.aws_region
    AWS_ENDPOINT = "https://s3.amazonaws.com"
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.rag_sa_key != "" ? { RAG_SA_KEY = var.rag_sa_key } : {}, var.google_project_id != "" ? { GOOGLE_PROJECTID = var.google_project_id } : {}, var.aws_access_key_id != "" && var.aws_secret_access_key != "" ? { AWS_ACCESS_KEY_ID = var.aws_access_key_id, AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key } : {})
}

resource "kubernetes_secret" "backend_secrets" {
  metadata {
    name      = "backend-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    JWT_SECRET                           = var.jwt_secret
    API_KEY                              = var.api_key
    PORT                                 = "3001"
    DATABASE_URL                         = "postgresql://${urlencode(aws_rds_cluster.postgres.master_username)}:${urlencode(aws_rds_cluster.postgres.master_password)}@${aws_rds_cluster.postgres.endpoint}:${aws_rds_cluster.postgres.port}/${aws_rds_cluster.postgres.database_name}"
    REDIS_URL                            = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    MCP_GATEWAY_URL                      = "http://mcp-gateway:3002"
    SQL_CONNECTION_STRING_DECRYPTION_IV  = var.sql_connection_string_decryption_iv != "" ? var.sql_connection_string_decryption_iv : "placeholder"
    SQL_CONNECTION_STRING_DECRYPTION_KEY = var.sql_connection_string_decryption_key != "" ? var.sql_connection_string_decryption_key : "placeholder"
    ENCRYPTION_KEY                       = var.encryption_key != "" ? var.encryption_key : "placeholder"
    OPENAI_API_KEY                       = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    OPENAI_BASE_URL                      = var.openai_base_url
    ANTHROPIC_API_KEY                    = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    VERBOSE_LOGGING                      = tostring(var.verbose_logging)
    BACKEND_REQUEST_TIMEOUT_MS           = tostring(var.backend_request_timeout_ms)
    LANGSMITH_API_KEY                    = var.langsmith_api_key != "" ? var.langsmith_api_key : ""
    BUCKET_NAME_FILE_MANAGER             = local.s3_bucket_file_manager_id
    NODE_ENV                             = "production"
    SKIP_ENV_VALIDATION                  = "true"
    AWS_REGION                           = var.aws_region
    AWS_ENDPOINT                         = "https://s3.amazonaws.com"
    GOOGLE_PROJECTID                     = var.google_project_id != "" ? var.google_project_id : ""
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {}, var.aws_access_key_id != "" && var.aws_secret_access_key != "" ? { AWS_ACCESS_KEY_ID = var.aws_access_key_id, AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key } : {})
}

resource "kubernetes_secret" "mcp_gateway_secrets" {
  metadata {
    name      = "mcp-gateway-secrets"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = merge({
    SECRET                       = var.gateway_secret
    PORT                         = "3002"
    FRONTEND_URL                 = var.frontend_url
    BUCKET_NAME_FILE_MANAGER     = local.s3_bucket_file_manager_id
    REDIS_URL                    = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    REDIS_URL_STRUCTURED_OUTPUTS = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
    PINECONE_API_KEY             = var.pinecone_api_key != "" ? var.pinecone_api_key : "placeholder"
    PINECONE_INDEX               = var.pinecone_index != "" ? var.pinecone_index : "placeholder"
    OPENAI_API_KEY               = var.openai_api_key != "" ? var.openai_api_key : "placeholder"
    PERPLEXITY_API_KEY           = var.perplexity_api_key != "" ? var.perplexity_api_key : "placeholder"
    TAVILY_API_KEY               = var.tavily_api_key != "" ? var.tavily_api_key : "placeholder"
    SPENDHQ_BASE_URL             = var.spendhq_base_url != "" ? var.spendhq_base_url : "placeholder"
    SPENDHQ_CLIENT_ID            = var.spendhq_client_id != "" ? var.spendhq_client_id : "placeholder"
    SPENDHQ_CLIENT_SECRET        = var.spendhq_client_secret != "" ? var.spendhq_client_secret : "placeholder"
    SPENDHQ_TOKEN_URL            = var.spendhq_token_url != "" ? var.spendhq_token_url : "placeholder"
    SPENDHQ_SS_HOST              = var.spendhq_ss_host != "" ? var.spendhq_ss_host : "placeholder"
    SPENDHQ_SS_USERNAME          = var.spendhq_ss_username != "" ? var.spendhq_ss_username : "placeholder"
    SPENDHQ_SS_PASSWORD          = var.spendhq_ss_password != "" ? var.spendhq_ss_password : "placeholder"
    SPENDHQ_SS_PORT              = var.spendhq_ss_port != "" ? var.spendhq_ss_port : "3306"
    ANTHROPIC_API_KEY            = var.anthropic_api_key != "" ? var.anthropic_api_key : "placeholder"
    AWS_REGION                   = var.aws_region
    AWS_ENDPOINT                 = "https://s3.amazonaws.com"
  }, var.gcp_sa_key != "" ? { GCP_SA_KEY = var.gcp_sa_key } : {}, var.google_project_id != "" ? { GOOGLE_PROJECTID = var.google_project_id } : {}, var.google_vertex_ai_web_credentials != "" ? { GOOGLE_VERTEX_AI_WEB_CREDENTIALS = var.google_vertex_ai_web_credentials } : {}, var.aws_access_key_id != "" && var.aws_secret_access_key != "" ? { AWS_ACCESS_KEY_ID = var.aws_access_key_id, AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key } : {})
}

# Database Secret
resource "kubernetes_secret" "database_secret" {
  metadata {
    name      = "database-secret"
    namespace = kubernetes_namespace.sligo.metadata[0].name
  }

  data = {
    host     = aws_rds_cluster.postgres.endpoint
    port     = tostring(aws_rds_cluster.postgres.port)
    database = aws_rds_cluster.postgres.database_name
    username = aws_rds_cluster.postgres.master_username
    password = aws_rds_cluster.postgres.master_password
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

# S3 Buckets for Application Storage (4 buckets total)
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Data sources to check if buckets exist (optional, for existing buckets)
data "aws_s3_bucket" "existing_file_manager" {
  count  = var.s3_bucket_name != "" && var.use_existing_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_name
}

data "aws_s3_bucket" "existing_agent_avatars" {
  count  = var.s3_bucket_agent_avatars_name != "" && var.use_existing_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_agent_avatars_name
}

data "aws_s3_bucket" "existing_logos" {
  count  = var.s3_bucket_logos_name != "" && var.use_existing_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_logos_name
}

data "aws_s3_bucket" "existing_rag" {
  count  = var.s3_bucket_rag_name != "" && var.use_existing_s3_bucket ? 1 : 0
  bucket = var.s3_bucket_rag_name
}

# S3 Bucket 1: File Manager
resource "aws_s3_bucket" "file_manager" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.cluster_name}-file-manager-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.cluster_name}-file-manager"
    Environment = "production"
    Purpose     = "file-manager"
  }
}

# S3 Bucket 2: Agent Avatars
resource "aws_s3_bucket" "agent_avatars" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = var.s3_bucket_agent_avatars_name != "" ? var.s3_bucket_agent_avatars_name : "${var.cluster_name}-agent-avatars-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.cluster_name}-agent-avatars"
    Environment = "production"
    Purpose     = "agent-avatars"
  }
}

# S3 Bucket 3: MCP Logos
resource "aws_s3_bucket" "logos" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = var.s3_bucket_logos_name != "" ? var.s3_bucket_logos_name : "${var.cluster_name}-logos-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.cluster_name}-logos"
    Environment = "production"
    Purpose     = "mcp-logos"
  }
}

# S3 Bucket 4: RAG Storage
resource "aws_s3_bucket" "rag" {
  count  = var.use_existing_s3_bucket ? 0 : 1
  bucket = var.s3_bucket_rag_name != "" ? var.s3_bucket_rag_name : "${var.cluster_name}-rag-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.cluster_name}-rag"
    Environment = "production"
    Purpose     = "rag-storage"
  }
}

# Local values to get bucket IDs and ARNs (either existing or newly created)
locals {
  s3_bucket_file_manager_id  = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_file_manager[0].id : aws_s3_bucket.file_manager[0].id
  s3_bucket_file_manager_arn = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_file_manager[0].arn : aws_s3_bucket.file_manager[0].arn
  s3_bucket_agent_avatars_id = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_agent_avatars[0].id : aws_s3_bucket.agent_avatars[0].id
  s3_bucket_logos_id         = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_logos[0].id : aws_s3_bucket.logos[0].id
  s3_bucket_rag_id           = var.use_existing_s3_bucket ? data.aws_s3_bucket.existing_rag[0].id : aws_s3_bucket.rag[0].id

  # Keep backward compatibility
  s3_bucket_id  = local.s3_bucket_file_manager_id
  s3_bucket_arn = local.s3_bucket_file_manager_arn
}

# Enable versioning on all S3 buckets
resource "aws_s3_bucket_versioning" "file_manager" {
  count  = var.s3_bucket_versioning && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_file_manager_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "agent_avatars" {
  count  = var.s3_bucket_versioning && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_agent_avatars_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "logos" {
  count  = var.s3_bucket_versioning && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_logos_id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "rag" {
  count  = var.s3_bucket_versioning && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_rag_id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption on all S3 buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "file_manager" {
  count  = var.s3_bucket_encryption && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_file_manager_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "agent_avatars" {
  count  = var.s3_bucket_encryption && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_agent_avatars_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logos" {
  count  = var.s3_bucket_encryption && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_logos_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rag" {
  count  = var.s3_bucket_encryption && !var.use_existing_s3_bucket ? 1 : 0
  bucket = local.s3_bucket_rag_id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access on all S3 buckets
resource "aws_s3_bucket_public_access_block" "file_manager" {
  count                   = var.use_existing_s3_bucket ? 0 : 1
  bucket                  = local.s3_bucket_file_manager_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "agent_avatars" {
  count                   = var.use_existing_s3_bucket ? 0 : 1
  bucket                  = local.s3_bucket_agent_avatars_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logos" {
  count                   = var.use_existing_s3_bucket ? 0 : 1
  bucket                  = local.s3_bucket_logos_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "rag" {
  count                   = var.use_existing_s3_bucket ? 0 : 1
  bucket                  = local.s3_bucket_rag_id
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
          local.s3_bucket_file_manager_arn,
          "${local.s3_bucket_file_manager_arn}/*",
          "arn:aws:s3:::${local.s3_bucket_agent_avatars_id}",
          "arn:aws:s3:::${local.s3_bucket_agent_avatars_id}/*",
          "arn:aws:s3:::${local.s3_bucket_logos_id}",
          "arn:aws:s3:::${local.s3_bucket_logos_id}/*",
          "arn:aws:s3:::${local.s3_bucket_rag_id}",
          "arn:aws:s3:::${local.s3_bucket_rag_id}/*"
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
    bucket_name_file_manager  = local.s3_bucket_file_manager_id
    bucket_name_agent_avatars = local.s3_bucket_agent_avatars_id
    bucket_name_logos         = local.s3_bucket_logos_id
    bucket_name_rag           = local.s3_bucket_rag_id
    region                    = var.aws_region
    role_arn                  = aws_iam_role.s3_access.arn
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
          } : {}, length(var.subnet_ids) > 0 ? {
          "alb.ingress.kubernetes.io/subnets" = join(",", var.subnet_ids)
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
          tag        = var.app_version
          pullPolicy = "Always"
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
          tag        = var.app_version
          pullPolicy = "Always"
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
          tag        = var.app_version
          pullPolicy = "Always"
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

      # Pre-install/pre-upgrade Job: Prisma migrate + sync AI models + sync MCP servers (same as build-and-publish)
      releaseSetup = {
        enabled = true
        image = {
          repository = "us-central1-docker.pkg.dev/sligo-ai-platform/${var.client_repository_name}/sligo-release-setup"
          tag        = var.app_version
          pullPolicy = "Always"
        }
        secretName = kubernetes_secret.backend_secrets.metadata[0].name
      }

      database = {
        enabled = true
        type    = "external"
        external = {
          host       = aws_rds_cluster.postgres.endpoint
          port       = aws_rds_cluster.postgres.port
          database   = aws_rds_cluster.postgres.database_name
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

# Wait for AWS LB Controller to create ALB and backend SG after Ingress
resource "time_sleep" "wait_for_alb_sg" {
  create_duration = "90s"
  depends_on      = [helm_release.sligo_cloud]
}

# Look up ALB backend security group (created by AWS Load Balancer Controller).
# Use aws_security_groups (plural) so we get an empty list instead of error when not found.
# Controller tags shared backend SG with elbv2.k8s.aws/resource = "backend-sg".
data "aws_security_groups" "alb" {
  filter {
    name   = "tag:elbv2.k8s.aws/cluster"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:elbv2.k8s.aws/resource"
    values = ["backend-sg"]
  }
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != "" ? var.vpc_id : aws_vpc.main[0].id]
  }
  depends_on = [time_sleep.wait_for_alb_sg]
}

locals {
  node_security_group_id = module.eks.node_security_group_id
  alb_security_group_id  = length(data.aws_security_groups.alb.ids) > 0 ? data.aws_security_groups.alb.ids[0] : null
}

# Security group rules to allow ALB to reach pods (backup; controller also manages these).
# Only create when backend SG exists; otherwise rely on controller.
resource "aws_security_group_rule" "alb_to_app" {
  count                    = local.alb_security_group_id != null ? 1 : 0
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = local.alb_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow ALB to reach app pods on port 3000"
}

resource "aws_security_group_rule" "alb_to_backend" {
  count                    = local.alb_security_group_id != null ? 1 : 0
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = local.alb_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow ALB to reach backend pods on port 3001"
}

resource "aws_security_group_rule" "alb_to_mcp_gateway" {
  count                    = local.alb_security_group_id != null ? 1 : 0
  type                     = "ingress"
  from_port                = 3002
  to_port                  = 3002
  protocol                 = "tcp"
  source_security_group_id = local.alb_security_group_id
  security_group_id        = local.node_security_group_id
  description              = "Allow ALB to reach mcp-gateway pods on port 3002"
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
