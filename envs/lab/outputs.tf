output "endpoint_service_name" {
  description = "Share this with consumers; they create an interface endpoint to it."
  value       = module.endpoint_service.service_name
}

output "endpoint_dns_name" {
  value = module.orders_endpoint.dns_name
}

output "orders_url" {
  description = "Private name of the service, resolvable only inside the consumer VPC."
  value       = "http://${module.private_dns.fqdns["orders"]}:${var.service_port}/"
}

output "flow_log_groups" {
  value = [module.provider_vpc.flow_log_group, module.consumer_vpc.flow_log_group]
}

output "test_commands" {
  description = "How to check the path from the client instance."
  value = var.create_test_instances ? join("\n", [
    "aws ssm start-session --target ${aws_instance.client[0].id} --region ${var.region}",
    "# then, inside the session:",
    "getent hosts ${module.private_dns.fqdns["orders"]}",
    "curl -s http://${module.private_dns.fqdns["orders"]}:${var.service_port}/health",
  ]) : "create_test_instances = false"
}
