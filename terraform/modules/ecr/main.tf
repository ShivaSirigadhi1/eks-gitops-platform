resource "aws_ecr_repository" "app" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.app.name
  policy     = var.lifecycle_policy
}

resource "aws_ecr_repository_policy" "github_actions" {
  repository = aws_ecr_repository.app.name
  policy     = data.aws_iam_policy_document.github_actions.json
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    sid    = "AllowGitHubActionsPush"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = var.github_actions_role_arns
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }
}
