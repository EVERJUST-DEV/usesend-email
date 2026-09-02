variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "usesend"
}

variable "docs_image_tag" {
  description = "ECR image tag for the docs container (CI passes the git SHA)."
  type        = string
  default     = "latest"
}
