output "endpoint_id" {
  value = aws_vpc_endpoint.this.id
}

output "dns_name" {
  description = "Regional DNS name of the endpoint (resolves to the endpoint ENIs in every AZ)."
  value       = aws_vpc_endpoint.this.dns_entry[0].dns_name
}

output "hosted_zone_id" {
  description = "Hosted zone of the endpoint DNS name, needed for a Route 53 alias record."
  value       = aws_vpc_endpoint.this.dns_entry[0].hosted_zone_id
}

output "security_group_id" {
  value = aws_security_group.endpoint.id
}
