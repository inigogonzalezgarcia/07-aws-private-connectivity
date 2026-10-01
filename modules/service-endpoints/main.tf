/**
 * Endpoints to AWS services for a VPC without internet access:
 * Systems Manager (so instances can be managed with Session Manager instead of SSH/bastions)
 * and an S3 gateway endpoint (free, routes S3 traffic privately).
 */

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70"
    }
  }
}

data "aws_region" "current" {}

locals {
  interface_services = toset(var.interface_services)
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-aws-endpoints"
  description = "HTTPS from inside the VPC to AWS service endpoints"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-aws-endpoints" }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS from the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_services
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true # the normal AWS hostnames resolve to these private IPs
  tags                = { Name = "${var.name}-${each.key}" }
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.s3_gateway ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  tags              = { Name = "${var.name}-s3" }
}
