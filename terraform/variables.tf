# =============================================================================
# Inputs. Copy terraform.tfvars.example -> terraform.tfvars and fill in.
# =============================================================================

variable "aws_region" {
  description = "AWS region. us-east-1 has the most mature SES feature set."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "usesend"
}

# ---- Network ----------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "nat_per_az" {
  description = "true = one NAT gateway per AZ (HA, ~2x cost); false = single NAT."
  type        = bool
  default     = false
}

# ---- App / DNS --------------------------------------------------------------
variable "app_domain" {
  description = "Hostname the useSend dashboard + API are served on, e.g. mail.yourco.com. Used for ACM, the ALB, and the app's auth callback URL."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID that app_domain lives in. Used to auto-create the ACM validation records and the app A/ALIAS record. Leave empty to manage DNS yourself."
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Container port the useSend web app listens on. Confirm against useSend's Dockerfile/docs (typically 3000)."
  type        = number
  default     = 3000
}

# ---- Container image --------------------------------------------------------
# Confirmed from the useSend repo: the published image is usesend/usesend
# (Docker Hub) / ghcr.io/usesend/usesend. The old "unsend" names are stale.
variable "usesend_image" {
  description = "Fully-qualified useSend container image (registry/name:tag). Pin a version tag for production rather than :latest."
  type        = string
  default     = "usesend/usesend:latest"
}

# useSend self-host is a SINGLE Next.js process; BullMQ workers run in-process.
# So there is one ECS service, not a web/worker split.
variable "health_check_path" {
  description = "App health endpoint (confirmed: GET /api/health returns 200)."
  type        = string
  default     = "/api/health"
}

# ---- ECS sizing (single service) -------------------------------------------
variable "app_cpu" {
  type    = number
  default = 512
}
variable "app_memory" {
  type    = number
  default = 1024
}
variable "app_desired_count" {
  description = "Number of tasks. Note: each task runs `prisma migrate deploy` at boot (Prisma takes an advisory lock, so concurrent boots are safe)."
  type        = number
  default     = 2
}

# ---- RDS Postgres -----------------------------------------------------------
variable "db_engine_version" {
  type    = string
  default = "16"
}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "db_name" {
  type    = string
  default = "usesend"
}
variable "db_username" {
  type    = string
  default = "usesend"
}
variable "db_multi_az" {
  description = "Multi-AZ for the database. Recommended true for production."
  type        = bool
  default     = true
}

# ---- ElastiCache Redis ------------------------------------------------------
variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}
variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

# ---- GitHub OAuth (useSend self-host login) --------------------------------
variable "github_client_id" {
  description = "GitHub OAuth App client ID for dashboard login."
  type        = string
  default     = ""

  validation {
    condition     = length(trimspace(var.github_client_id)) > 0
    error_message = "github_client_id is required — GitHub is the wired login provider. Set it in terraform.tfvars. (To use Google instead, wire GOOGLE_CLIENT_* in ecs.tf and relax this.)"
  }
}
variable "github_client_secret" {
  description = "GitHub OAuth App client secret."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = length(var.github_client_secret) > 0
    error_message = "github_client_secret is required. Export it before apply: export TF_VAR_github_client_secret='...'"
  }
}
