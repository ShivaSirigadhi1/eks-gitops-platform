variable "repository_name" {
  type = string
}
variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
}
variable "lifecycle_policy" {
  type    = string
  default = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPattern    = "sha-*"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
variable "github_actions_role_arns" {
  type    = list(string)
  default = []
}
