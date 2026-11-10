# KMS Key for EKS encryption
resource "aws_kms_key" "eks" {
  description = "${var.project_name} EKS encryption key"
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnets      = var.private_subnets
  enable_nat_gateway   = var.enable_nat_gateway
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name             = var.project_name
  cluster_name             = "${var.project_name}-${var.environment}"
  kubernetes_version       = var.kubernetes_version
  private_subnet_ids       = module.vpc.private_subnet_ids
  cluster_security_group_ids = [aws_security_group.eks_cluster.id]
  kms_key_arn              = aws_kms_key.eks.arn
  enable_public_endpoint   = var.enable_public_endpoint
  instance_types           = var.instance_types
  capacity_type            = var.capacity_type
  desired_size             = var.desired_size
  max_size                 = var.max_size
  min_size                 = var.min_size
}

# Security group for EKS cluster
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.enable_public_endpoint ? ["0.0.0.0/0"] : [module.vpc.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  repository_name        = "${var.project_name}-app"
  image_tag_mutability   = "IMMUTABLE"
  github_actions_role_arns = [module.iam.github_actions_role_arn]
}

# IAM Module (includes GitHub Actions OIDC and IRSA roles)
module "iam" {
  source = "./modules/iam"

  project_name            = var.project_name
  aws_region              = var.aws_region
  github_repo_patterns    = var.github_repo_patterns
  oidc_provider_arn       = module.eks.oidc_provider_arn
  oidc_provider_url       = module.eks.oidc_provider_url
  service_account_names   = [
    "system:serviceaccount:kube-system:aws-load-balancer-controller",
    "system:serviceaccount:external-secrets:external-secrets",
  ]
}

# ALB Controller Module
module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name              = module.eks.cluster_name
  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  alb_controller_role_arn   = module.iam.alb_controller_role_arn
}

# External Secrets Module
module "external_secrets" {
  source = "./modules/external-secrets"

  aws_region               = var.aws_region
  external_secrets_role_arn = module.iam.external_secrets_role_arn
}

# Argo CD Module
module "argocd" {
  source = "./modules/argocd"

  project_name = var.project_name
  argocd_url   = "https://argocd.${var.domain_name}"
}

# Monitoring Module (optional)
module "monitoring" {
  source = "./modules/monitoring"

  grafana_admin_password = var.grafana_admin_password
}
