terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
  # Separate state from the app so this deploys without any app variables/secrets.
  backend "s3" {
    bucket  = "usesend-tfstate-678806349176"
    key     = "usesend/docs.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Component = "docs"
    }
  }
}
