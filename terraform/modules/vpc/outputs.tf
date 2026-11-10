output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "nat_gateway_ids" {
  value = aws_nat_gateway.main[*].id
}
output "vpc_endpoint_sg_id" {
  value = aws_security_group.vpc_endpoint.id
}
