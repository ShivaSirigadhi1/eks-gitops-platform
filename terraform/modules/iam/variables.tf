variable "project_name" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "github_repo_patterns" {
  type = list(string)
}
variable "oidc_provider_arn" {
  type = string
}
variable "oidc_provider_url" {
  type = string
}
variable "service_account_names" {
  type = list(string)
}
