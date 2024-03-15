terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket = "terraform-state-46422794"
    key    = "terraform/terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = "eu-west-1"
}

variable "AWS_ACCOUNT_ID" {
  description = "AWS Account ID"
  type        = string
}

resource "random_id" "random" {
  byte_length = 8
}