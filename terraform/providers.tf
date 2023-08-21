terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}


terraform {
  backend "s3" {
    bucket = "thelatestlead"
    key    = "production/infastructure"
    region = "us-west-2"
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = "us-west-2"
}
