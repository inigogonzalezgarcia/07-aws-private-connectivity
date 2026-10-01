terraform {
  required_version = ">= 1.7" # mock providers in `terraform test` need 1.7+ (OpenTofu 1.8+)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Local state is fine for a lab you destroy the same day. For anything shared, use a
  # remote backend (S3 with state locking) and never commit terraform.tfstate.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "aws-private-connectivity"
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}
