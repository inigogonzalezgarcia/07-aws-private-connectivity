variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "One subnet per AZ for the endpoint network interfaces."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Place the endpoint in at least two subnets (AZs)."
  }
}

variable "service_name" {
  description = "Endpoint service name published by the provider."
  type        = string
}

variable "port" {
  type = number
}

variable "client_cidrs" {
  description = "Source CIDRs allowed to use the endpoint. Keep them as narrow as the clients are."
  type        = list(string)

  validation {
    condition     = length(var.client_cidrs) > 0 && !contains(var.client_cidrs, "0.0.0.0/0")
    error_message = "List the client subnets explicitly; 0.0.0.0/0 is not allowed."
  }
}
