/**
 * Lab: a "provider" VPC publishes an internal service through PrivateLink, a "consumer" VPC
 * reaches it by a private DNS name. Neither VPC has an internet gateway, a NAT gateway or a
 * route to the other. Optional test instances let you check the path end to end.
 */

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  azs = data.aws_availability_zones.available.names

  # Same-account lab by default; add other accounts or roles to publish the service to them.
  allowed_principals = length(var.allowed_principals) > 0 ? var.allowed_principals : [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
}

# --- Networks ----------------------------------------------------------------

module "provider_vpc" {
  source             = "../../modules/network"
  name               = "${var.name}-provider"
  cidr_block         = var.provider_cidr
  availability_zones = local.azs
  az_count           = var.az_count
}

module "consumer_vpc" {
  source             = "../../modules/network"
  name               = "${var.name}-consumer"
  cidr_block         = var.consumer_cidr
  availability_zones = local.azs
  az_count           = var.az_count
}

# --- Provider: service behind an internal NLB, published as an endpoint service ----------

module "endpoint_service" {
  source              = "../../modules/endpoint-service"
  name                = "${var.name}-orders"
  vpc_id              = module.provider_vpc.vpc_id
  subnet_ids          = module.provider_vpc.private_subnet_ids
  port                = var.service_port
  targets             = { for i, instance in aws_instance.service : "service-${i}" => instance.id }
  allowed_principals  = local.allowed_principals
  acceptance_required = true
}

# --- Consumer: interface endpoint, private DNS name, AWS service endpoints ----------------

module "orders_endpoint" {
  source       = "../../modules/endpoint-consumer"
  name         = "${var.name}-orders"
  vpc_id       = module.consumer_vpc.vpc_id
  subnet_ids   = module.consumer_vpc.private_subnet_ids
  service_name = module.endpoint_service.service_name
  port         = var.service_port
  client_cidrs = module.consumer_vpc.private_subnet_cidrs
}

# In this single-account lab the provider accepts its own consumer. Across accounts, the
# provider team runs this (or accepts in the console) after checking who is asking.
resource "aws_vpc_endpoint_connection_accepter" "orders" {
  vpc_endpoint_service_id = module.endpoint_service.service_id
  vpc_endpoint_id         = module.orders_endpoint.endpoint_id
}

module "private_dns" {
  source    = "../../modules/private-dns"
  zone_name = var.private_zone
  vpcs      = { consumer = module.consumer_vpc.vpc_id }
  records = {
    orders = {
      dns_name       = module.orders_endpoint.dns_name
      hosted_zone_id = module.orders_endpoint.hosted_zone_id
    }
  }
}

module "consumer_aws_endpoints" {
  source          = "../../modules/service-endpoints"
  name            = "${var.name}-consumer"
  vpc_id          = module.consumer_vpc.vpc_id
  vpc_cidr        = module.consumer_vpc.cidr_block
  subnet_ids      = module.consumer_vpc.private_subnet_ids
  route_table_ids = [module.consumer_vpc.private_route_table_id]
}
