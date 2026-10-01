# Runs without AWS credentials: the AWS provider is mocked, so these tests check the
# configuration's logic and guard-rails, not AWS itself. Run with `terraform test` (1.7+)
# or `tofu test` from envs/lab.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "eu-west-1"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [{
        dns_name       = "vpce-0abc-1234.vpce-svc-0def.eu-west-1.vpce.amazonaws.com"
        hosted_zone_id = "Z38GZ743OKFT7T"
      }]
    }
  }

  mock_resource "aws_vpc_endpoint_service" {
    defaults = {
      service_name = "com.amazonaws.vpce.eu-west-1.vpce-svc-0def"
    }
  }

  # Mocked ARNs must still look like ARNs, because the provider validates them.
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/mock"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-west-1:111122223333:log-group:mock"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:111122223333:loadbalancer/net/mock/0123456789abcdef"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:111122223333:targetgroup/mock/0123456789abcdef"
    }
  }

  mock_resource "aws_route53_record" {
    defaults = {
      fqdn = "orders.internal.example"
    }
  }
}

run "lab_builds_the_private_path" {
  command = apply

  assert {
    condition     = length(module.provider_vpc.private_subnet_ids) == 2 && length(module.consumer_vpc.private_subnet_ids) == 2
    error_message = "Both VPCs should have one private subnet in each of two AZs."
  }

  assert {
    condition     = output.endpoint_service_name == "com.amazonaws.vpce.eu-west-1.vpce-svc-0def"
    error_message = "The consumer endpoint must point at the provider's endpoint service."
  }

  assert {
    condition     = output.orders_url == "http://orders.internal.example:8080/"
    error_message = "The service should be reachable by its private name."
  }

  assert {
    condition     = aws_vpc_endpoint_connection_accepter.orders.vpc_endpoint_service_id == module.endpoint_service.service_id
    error_message = "The lab must accept its own endpoint connection."
  }
}

run "test_instances_are_locked_down" {
  command = apply

  assert {
    condition     = aws_instance.service[0].associate_public_ip_address == false && aws_instance.client[0].associate_public_ip_address == false
    error_message = "Test instances must not get public IPs."
  }

  assert {
    condition     = aws_instance.service[0].metadata_options[0].http_tokens == "required" && aws_instance.client[0].metadata_options[0].http_tokens == "required"
    error_message = "Instances must require IMDSv2."
  }

  assert {
    condition     = aws_instance.service[0].root_block_device[0].encrypted && aws_instance.client[0].root_block_device[0].encrypted
    error_message = "Root volumes must be encrypted."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.service_from_nlb[0].cidr_ipv4 == "10.10.0.0/16"
    error_message = "The service must only accept traffic from inside the provider VPC."
  }

  assert {
    condition     = alltrue([for r in [aws_vpc_security_group_egress_rule.client_https[0], aws_vpc_security_group_egress_rule.client_service[0]] : r.cidr_ipv4 == "10.20.0.0/16"])
    error_message = "The client may only talk to addresses inside its own VPC."
  }
}

run "without_test_instances" {
  command = apply

  variables {
    create_test_instances = false
  }

  assert {
    condition     = length(aws_instance.service) == 0 && length(aws_instance.client) == 0
    error_message = "No instances should be created when create_test_instances = false."
  }
}

run "rejects_wildcard_principal" {
  command = plan

  variables {
    allowed_principals = ["*"]
  }

  expect_failures = [var.allowed_principals]
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "This_Is_Not_Valid"
  }

  expect_failures = [var.name]
}
