# =============================================================================
# Secrets Manager — connection strings and app secrets, injected into the ECS
# tasks at launch (ecs.tf maps these ARNs to the app's env var names). The
# execution role (iam.tf) is granted GetSecretValue on exactly these.
# =============================================================================

# NextAuth/Auth.js session-encryption secret.
resource "random_password" "auth_secret" {
  length  = 48
  special = false
}

locals {
  # Prisma-style DSN. sslmode=require encrypts the ECS->RDS hop (no cert
  # verification). For verify-full, add the RDS CA bundle — see docs/runbook.md.
  database_url = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${var.db_name}?sslmode=require"

  # No auth token by default (in-VPC, SG-restricted). Switch to rediss:// if you
  # enable transit encryption + auth_token in elasticache.tf.
  redis_url = "redis://${aws_elasticache_replication_group.main.primary_endpoint_address}:6379"
}

resource "aws_secretsmanager_secret" "database_url" {
  name                    = "${var.project_name}/database_url"
  recovery_window_in_days = 0 # values are Terraform-regenerated; free the name on destroy
}
resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = local.database_url
}

resource "aws_secretsmanager_secret" "redis_url" {
  name                    = "${var.project_name}/redis_url"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id     = aws_secretsmanager_secret.redis_url.id
  secret_string = local.redis_url
}

resource "aws_secretsmanager_secret" "auth_secret" {
  name                    = "${var.project_name}/auth_secret"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "auth_secret" {
  secret_id     = aws_secretsmanager_secret.auth_secret.id
  secret_string = random_password.auth_secret.result
}

resource "aws_secretsmanager_secret" "github_client_secret" {
  name                    = "${var.project_name}/github_client_secret"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "github_client_secret" {
  secret_id     = aws_secretsmanager_secret.github_client_secret.id
  secret_string = var.github_client_secret
}
