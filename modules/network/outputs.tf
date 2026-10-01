output "vpc_id" {
  value = aws_vpc.this.id
}

output "cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "flow_log_group" {
  value = aws_cloudwatch_log_group.flow_logs.name
}
