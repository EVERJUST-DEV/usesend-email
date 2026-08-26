output "app_url" {
  description = "Dashboard + API URL."
  value       = "https://${var.app_domain}"
}

output "alb_dns_name" {
  description = "ALB hostname. If you are NOT letting Terraform manage Route53, create a CNAME/ALIAS for app_domain pointing here."
  value       = aws_lb.main.dns_name
}

output "ses_callback_url" {
  description = "Enter this as the callback URL when configuring SES in the useSend admin UI. Must be publicly reachable."
  value       = "https://${var.app_domain}/api/ses_callback"
}

output "github_oauth_callback_url" {
  description = "Set this as the Authorization callback URL in your GitHub OAuth App."
  value       = "https://${var.app_domain}/api/auth/callback/github"
}

output "db_endpoint" {
  value = aws_db_instance.main.address
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service" {
  value = aws_ecs_service.app.name
}
