variable "project_name" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "availability_zones" {
  type = list(string)
}
variable "public_subnet_cidrs" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "enable_nat_gateway" {
  type    = bool
  default = true
}
