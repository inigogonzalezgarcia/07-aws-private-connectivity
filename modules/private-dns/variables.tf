variable "zone_name" {
  description = "Private zone, e.g. internal.example. Use a domain you own or a reserved one; never a public name you don't control."
  type        = string
}

variable "vpcs" {
  description = "VPCs that can resolve the zone, as static name => VPC ID (keys must be known at plan time)."
  type        = map(string)
}

variable "records" {
  description = "Short name => endpoint DNS name and hosted zone id."
  type = map(object({
    dns_name       = string
    hosted_zone_id = string
  }))
}

variable "query_logging" {
  description = "Send Route 53 Resolver query logs for the VPCs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "query_log_retention_days" {
  type    = number
  default = 14
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key ARN for the query log group."
  type        = string
  default     = null
}
