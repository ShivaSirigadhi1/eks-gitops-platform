# OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role for GitHub Actions to assume
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_repo_patterns
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "github-actions-ecr"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_eks" {
  name = "github-actions-eks"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "*"
    }]
  })
}

# IRSA roles for cluster addons
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = var.service_account_names
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
}

resource "aws_iam_role_policy" "alb_controller" {
  name = "alb-controller"
  role = aws_iam_role.alb_controller.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "elasticloadbalancing:*",
        "ec2:Describe*",
        "ec2:CreateTags",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "iam:CreateServiceLinkedRole"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "external_secrets" {
  name = "${var.project_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "external-secrets"
  role = aws_iam_role.external_secrets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
    }]
  })
}

data "aws_caller_identity" "current" {}
