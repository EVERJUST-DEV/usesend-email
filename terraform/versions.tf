terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote state (recommended before you have anything real deployed).
  # Create the bucket + lock table once, then uncomment and `terraform init
  # -migrate-state`. Until then Terraform uses local state (terraform.tfstate),
  # which is gitignored.
  #
  #   aws s3 mb s3://usesend-tfstate-<account-id> --region us-east-1
  #   aws dynamodb create-table --table-name usesend-tflock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST --region us-east-1
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "usesend-tfstate-<account-id>"
  #   key            = "usesend/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "usesend-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Component = "transactional-email"
    }
  }
}
