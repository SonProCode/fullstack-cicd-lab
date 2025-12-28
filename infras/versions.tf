terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  backend "s3" {
    key          = "terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = false
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

locals {
  var  = yamldecode(file("${path.module}/${var.environment}/terraform.yaml"))
  tags = try(local.var.tags, {})
}

variable "environment" {
  description = "The deployment environment"
  type        = string
}
