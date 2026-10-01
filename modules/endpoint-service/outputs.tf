output "service_name" {
  description = "What consumers put in their interface endpoint, e.g. com.amazonaws.vpce.eu-west-1.vpce-svc-..."
  value       = aws_vpc_endpoint_service.this.service_name
}

output "service_id" {
  value = aws_vpc_endpoint_service.this.id
}

output "nlb_arn" {
  value = aws_lb.this.arn
}
