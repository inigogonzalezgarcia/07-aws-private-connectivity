variable "region" {
  description = "AWS region for the lab."
  type        = string
  default     = "eu-west-1"
}

variable "name" {
  description = "Prefix for every resource."
  type        = string
  default     = "pl-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name))
    error_message = "Use 2-16 lowercase letters, digits or '-' (it ends up in load balancer names)."
  }
}

variable "provider_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "consumer_cidr" {
  description = "Can overlap with provider_cidr: PrivateLink does not route between the VPCs."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "service_port" {
  type    = number
  default = 8080
}

variable "private_zone" {
  description = "Private hosted zone for friendly names. .example is reserved, so it can never clash with a real domain."
  type        = string
  default     = "internal.example"
}

variable "allowed_principals" {
  description = "Principals allowed to connect to the endpoint service. Empty = this account only."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_principals, "*")
    error_message = "Never publish the service to \"*\": list the accounts or roles that may connect."
  }
}

variable "create_test_instances" {
  description = "Create one service instance and one Session Manager client to test the path."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "Graviton (arm64) type to match the AMI."
  type        = string
  default     = "t4g.nano"
}
