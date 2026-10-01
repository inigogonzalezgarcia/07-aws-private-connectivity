variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "Only this range may reach the endpoints on 443."
  type        = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "route_table_ids" {
  description = "Route tables that get the S3 gateway route."
  type        = list(string)
  default     = []
}

variable "interface_services" {
  description = "AWS services to reach privately. The default is what Session Manager needs."
  type        = list(string)
  default     = ["ssm", "ssmmessages", "ec2messages"]
}

variable "s3_gateway" {
  type    = bool
  default = true
}
