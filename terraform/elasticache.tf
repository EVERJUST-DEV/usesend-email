# =============================================================================
# ElastiCache Redis — useSend's job queue (BullMQ) and rate limiting.
# Single node by default; add replicas via num_cache_clusters for HA.
# In-VPC only (private subnets + SG restricted to ECS), so no auth token by
# default. To require auth/TLS, set transit_encryption_enabled + auth_token and
# switch the app URL to rediss:// (see secrets.tf / ecs.tf note).
# =============================================================================

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-redis"
  subnet_ids = aws_subnet.private[*].id
}

# BullMQ REQUIRES noeviction — the default AWS redis7 param group uses
# volatile-lru, which would silently evict queued jobs (accepted-but-never-sent
# emails) under memory pressure. This matches the local docker-compose behavior.
resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.project_name}-redis7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-redis"
  description          = "useSend BullMQ queue + rate limiting"

  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type
  port           = 6379

  num_cache_clusters         = 1
  automatic_failover_enabled = false

  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
  parameter_group_name = aws_elasticache_parameter_group.main.name

  at_rest_encryption_enabled = true
  # transit_encryption_enabled = true
  # auth_token               = random_password.redis.result  # if you enable auth

  snapshot_retention_limit = 3
  apply_immediately        = true

  tags = { Name = "${var.project_name}-redis" }
}
