# =============================================================================
# Docs hosting: serve the static Fumadocs site at mail.everjust.app/docs.
# A small nginx container (static export baked in) runs as its OWN ECS service
# behind the SAME ALB, reached via a /docs* listener rule. The app's default
# routing is untouched. Image is built + pushed by CI (.github/workflows/docs.yml).
# =============================================================================

variable "docs_image_tag" {
  description = "ECR image tag for the docs container (CI passes the git SHA)."
  type        = string
  default     = "latest"
}

resource "aws_ecr_repository" "docs" {
  name                 = "${var.project_name}-docs"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Keep only the last few images.
resource "aws_ecr_lifecycle_policy" "docs" {
  repository = aws_ecr_repository.docs.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 5"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 5 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_cloudwatch_log_group" "docs" {
  name              = "/ecs/${var.project_name}-docs"
  retention_in_days = 30
}

# Docs tasks: accept 8080 only from the ALB. Separate SG so the app SG is untouched.
resource "aws_security_group" "docs" {
  name        = "${var.project_name}-docs"
  description = "useSend docs container"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "docs http from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-docs" }
}

resource "aws_ecs_task_definition" "docs" {
  family                   = "${var.project_name}-docs"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      name      = "docs"
      image     = "${aws_ecr_repository.docs.repository_url}:${var.docs_image_tag}"
      essential = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.docs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "docs"
        }
      }
    }
  ])
}

resource "aws_lb_target_group" "docs" {
  name        = "${var.project_name}-docs"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/docs/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 4
  }
}

# Route /docs and /docs/* on the existing HTTPS listener to the docs service.
resource "aws_lb_listener_rule" "docs" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.docs.arn
  }
  condition {
    path_pattern {
      values = ["/docs", "/docs/*"]
    }
  }
}

resource "aws_ecs_service" "docs" {
  name            = "${var.project_name}-docs"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.docs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.docs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.docs.arn
    container_name   = "docs"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 60
  depends_on                        = [aws_lb_listener_rule.docs]
}

output "docs_ecr_url" {
  value = aws_ecr_repository.docs.repository_url
}
