output "interface_endpoint_ids" {
  value = { for k, e in aws_vpc_endpoint.interface : k => e.id }
}

output "security_group_id" {
  value = aws_security_group.endpoints.id
}
