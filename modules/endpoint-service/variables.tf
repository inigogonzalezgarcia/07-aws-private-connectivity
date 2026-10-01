variable "name" {
  description = "Name prefix (the NLB and target group names are cut to 32 characters)."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets for the NLB, one per AZ."
  type        = list(string)
}

variable "port" {
  description = "TCP port the service listens on."
  type        = number
}

variable "target_instance_ids" {
  description = "EC2 instances behind the NLB."
  type        = list(string)
  default     = []
}

variable "allowed_principals" {
  description = "ARNs allowed to request a connection (accounts, roles or users). Never use \"*\"."
  type        = list(string)

  validation {
    condition     = length(var.allowed_principals) > 0 && !contains(var.allowed_principals, "*")
    error_message = "List explicit principals; \"*\" would let any AWS account request a connection."
  }
}

variable "acceptance_required" {
  description = "Require the provider to accept each endpoint connection."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Protect the NLB from deletion. Off in the lab so terraform destroy works in one step."
  type        = bool
  default     = false
}
