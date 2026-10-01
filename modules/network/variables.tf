variable "name" {
  description = "Name prefix for every resource in this VPC."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR. Provider and consumer VPCs may even overlap: PrivateLink does not route between them."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, for example 10.10.0.0/16."
  }
}

variable "availability_zones" {
  description = "Candidate AZs, usually from data.aws_availability_zones."
  type        = list(string)
}

variable "az_count" {
  description = "How many AZs to use. Two is the minimum for an endpoint that survives one AZ failing."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "Use at least two AZs."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet (/16 + 8 = /24 subnets)."
  type        = number
  default     = 8
}

variable "flow_log_retention_days" {
  description = "How long flow logs are kept in CloudWatch Logs."
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key ARN for the flow log group."
  type        = string
  default     = null
}
