output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "fqdns" {
  value = { for k, r in aws_route53_record.alias : k => r.fqdn }
}
