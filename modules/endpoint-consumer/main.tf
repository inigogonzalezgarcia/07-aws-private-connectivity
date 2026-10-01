/**
 * Consumer side of PrivateLink: an interface endpoint (one ENI per subnet/AZ) to an endpoint
 * service, behind a security group that only admits the listed client CIDRs on the service port.
 */

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70"
    }
  }
}

resource "aws_security_group" "endpoint" {
  name        = "${var.name}-endpoint"
  description = "Clients allowed to reach ${var.name} through PrivateLink"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-endpoint" }
}

resource "aws_vpc_security_group_ingress_rule" "clients" {
  for_each          = toset(var.client_cidrs)
  security_group_id = aws_security_group.endpoint.id
  description       = "Service port from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = var.port
  to_port           = var.port
  cidr_ipv4         = each.value
}

# No egress rules: the endpoint only answers connections, it never starts them.

resource "aws_vpc_endpoint" "this" {
  vpc_id              = var.vpc_id
  service_name        = var.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = false # the name comes from our own private hosted zone (see private-dns)
  tags                = { Name = "${var.name}-endpoint" }
}
