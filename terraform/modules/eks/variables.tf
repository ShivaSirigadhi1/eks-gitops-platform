variable "project_name" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "kubernetes_version" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "cluster_security_group_ids" {
  type = list(string)
}
variable "kms_key_arn" {
  type = string
}
variable "enable_public_endpoint" {
  type    = bool
  default = false
}
variable "instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}
variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
variable "desired_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 4
}
variable "min_size" {
  type    = number
  default = 1
}
