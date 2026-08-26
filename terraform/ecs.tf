# =============================================================================
# ECS Fargate: one service running the useSend image. Single Next.js process;
# BullMQ workers run in-process. `prisma migrate deploy` runs at container boot
# (baked into the image's start.sh), so no separate migration task is needed.
# =============================================================================

locals {
  container_name = var.project_name
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.app_cpu
  memory                   = var.app_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.usesend_image
      essential = true

      portMappings = [
        { containerPort = var.app_port, protocol = "tcp" }
      ]

      # Non-secret config. Exact var names confirmed against useSend's prod
      # compose (docker/prod/compose.yml).
      environment = [
        { name = "PORT", value = tostring(var.app_port) },
        # NEXTAUTH_URL must be the public app URL; it's also used to build the
        # SNS callback (https://<app>/api/ses_callback) and the OAuth callback.
        { name = "NEXTAUTH_URL", value = "https://${var.app_domain}" },
        { name = "AWS_DEFAULT_REGION", value = var.aws_region },
        { name = "GITHUB_ID", value = var.github_client_id },
        { name = "NEXT_PUBLIC_IS_CLOUD", value = "false" },
        { name = "API_RATE_LIMIT", value = "1" },
        # No static AWS keys: the task role (iam.tf) supplies SES/SNS creds via
        # the default AWS credential chain.
        #
        # Object storage is intentionally OMITTED. useSend uses it only for
        # optional editor image uploads — transactional send and boot never
        # touch it. To enable it later, add the five S3_COMPATIBLE_* vars here
        # (see docs/runbook.md "Object storage (optional)"); note the app's S3
        # client hardcodes region "auto", so real AWS S3 needs a source patch or
        # an R2/MinIO backend.
      ]

      secrets = [
        { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
        { name = "REDIS_URL", valueFrom = aws_secretsmanager_secret.redis_url.arn },
        { name = "NEXTAUTH_SECRET", valueFrom = aws_secretsmanager_secret.auth_secret.arn },
        { name = "GITHUB_SECRET", valueFrom = aws_secretsmanager_secret.github_client_secret.arn },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"fetch('http://localhost:'+(process.env.PORT||3000)+'/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  # Migrations run at boot (prisma migrate deploy). On a first deploy both tasks
  # start together and Prisma's advisory lock serializes them, so the second task
  # waits out the first's migration. 300s of grace keeps that from tripping the
  # deployment circuit breaker. (Alternatively set app_desired_count=1 for the
  # very first apply, then scale up — see docs/runbook.md.)
  health_check_grace_period_seconds = 300

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.container_name
    container_port   = var.app_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.https]

  lifecycle {
    ignore_changes = [desired_count] # let autoscaling own it after first apply
  }
}

# ---- Autoscaling (CPU target tracking) ----
resource "aws_appautoscaling_target" "app" {
  max_capacity       = 6
  min_capacity       = var.app_desired_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "app_cpu" {
  name               = "${var.project_name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 65
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
