# Read the existing app infrastructure (created by the root module) by name/tag,
# so this module owns only the docs resources and shares no state or variables.

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Tier"
    values = ["public"]
  }
}

data "aws_lb" "main" {
  name = "${var.project_name}-alb"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.main.arn
  port              = 443
}

data "aws_security_group" "alb" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-alb"]
  }
  vpc_id = data.aws_vpc.main.id
}

data "aws_ecs_cluster" "main" {
  cluster_name = "${var.project_name}-cluster"
}

data "aws_iam_role" "execution" {
  name = "${var.project_name}-ecs-execution"
}
