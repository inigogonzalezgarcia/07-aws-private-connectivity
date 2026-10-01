/**
 * Private hosted zone visible only inside the given VPCs, with a friendly name that aliases
 * the interface endpoint. Applications use orders.<zone> and never see the vpce-... name.
 */

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70"
    }
  }
}

resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = "Private names for PrivateLink endpoints (managed by Terraform)"

  dynamic "vpc" {
    for_each = toset(var.vpc_ids)
    content {
      vpc_id = vpc.value
    }
  }
}

resource "aws_route53_record" "alias" {
  for_each = var.records
  zone_id  = aws_route53_zone.this.zone_id
  name     = "${each.key}.${var.zone_name}"
  type     = "A"

  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.hosted_zone_id
    evaluate_target_health = false # health is checked by the NLB behind the endpoint
  }
}

# Log every DNS query made from the VPCs: the first place to look when "the name doesn't resolve".
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "queries" {
  count             = var.query_logging ? 1 : 0
  name              = "/route53resolver/${replace(var.zone_name, ".", "-")}"
  retention_in_days = var.query_log_retention_days
  kms_key_id        = var.kms_key_id
}

resource "aws_route53_resolver_query_log_config" "this" {
  count           = var.query_logging ? 1 : 0
  name            = "${replace(var.zone_name, ".", "-")}-queries"
  destination_arn = aws_cloudwatch_log_group.queries[0].arn
}

resource "aws_route53_resolver_query_log_config_association" "this" {
  for_each                     = var.query_logging ? toset(var.vpc_ids) : toset([])
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.this[0].id
  resource_id                  = each.value
}
