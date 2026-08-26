# =============================================================================
# Public entry point: internet-facing ALB -> useSend tasks on app_port.
# HTTPS terminates here (ACM cert). The SNS callback (/api/ses_callback) and the
# GitHub OAuth callback are just paths on the app, so they work through this ALB
# with no special routing — SNS just needs the cert to be publicly valid.
# =============================================================================

variable "acm_certificate_arn" {
  description = "Existing ACM cert ARN for app_domain (same region as the ALB). Leave empty to have Terraform create + DNS-validate one via route53_zone_id."
  type        = string
  default     = ""
}

locals {
  create_cert = var.acm_certificate_arn == ""
  # Prefer a bring-your-own cert, else the *validated* cert (so the HTTPS
  # listener implicitly waits for issuance — avoids the ACM chicken-and-egg),
  # else a bare (possibly un-validated) cert. try() guards the count-based
  # references so this never index-errors; coalesce skips empty strings.
  certificate_arn = coalesce(
    var.acm_certificate_arn,
    try(aws_acm_certificate_validation.app[0].certificate_arn, ""),
    try(aws_acm_certificate.app[0].arn, ""),
  )
}

# ---- ACM (created only if you didn't bring your own) ----
resource "aws_acm_certificate" "app" {
  count             = local.create_cert ? 1 : 0
  domain_name       = var.app_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = (local.create_cert && var.route53_zone_id != "") ? {
    for dvo in aws_acm_certificate.app[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "app" {
  count                   = (local.create_cert && var.route53_zone_id != "") ? 1 : 0
  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---- Load balancer ----
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 4
  }

  deregistration_delay = 30
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  lifecycle {
    precondition {
      condition     = var.acm_certificate_arn != "" || var.route53_zone_id != ""
      error_message = "Set either acm_certificate_arn (bring your own validated cert) or route53_zone_id (Terraform creates + DNS-validates one). Both empty leaves the HTTPS listener with an un-issued certificate."
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ---- App DNS record (only if Terraform manages the zone) ----
resource "aws_route53_record" "app" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.app_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
