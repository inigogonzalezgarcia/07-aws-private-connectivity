/**
 * Provider side of PrivateLink: an internal Network Load Balancer in front of the service,
 * published as a VPC endpoint service. Only the listed principals can request a connection,
 * and every connection must be accepted.
 */

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70"
    }
  }
}

resource "aws_lb" "this" {
  name                             = substr("${var.name}-nlb", 0, 32)
  internal                         = true # never reachable from the internet
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  enable_cross_zone_load_balancing = true # consumers in any AZ reach targets in every AZ
  enable_deletion_protection       = var.deletion_protection
}

resource "aws_lb_target_group" "this" {
  name                 = substr("${var.name}-tg", 0, 32)
  port                 = var.port
  protocol             = "TCP"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = toset(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value
  port             = var.port
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_vpc_endpoint_service" "this" {
  network_load_balancer_arns = [aws_lb.this.arn]
  acceptance_required        = var.acceptance_required
  allowed_principals         = var.allowed_principals
  supported_ip_address_types = ["ipv4"]
  tags                       = { Name = "${var.name}-endpoint-service" }
}
