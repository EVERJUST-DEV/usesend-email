# =============================================================================
# Security groups. Traffic path: internet -> ALB -> ECS tasks -> RDS / Redis.
# Each tier only accepts from the tier in front of it.
# =============================================================================

# ---- ALB: public 80/443 ----
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Public ingress to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP (redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-alb" }
}

# ---- ECS tasks: only from the ALB on the app port; egress anywhere (SES API, image pulls) ----
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs"
  description = "useSend web/worker tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-ecs" }
}

# ---- RDS: 5432 only from ECS ----
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds"
  description = "Postgres, reachable only from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-rds" }
}

# ---- Redis: 6379 only from ECS ----
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis"
  description = "Redis, reachable only from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-redis" }
}
