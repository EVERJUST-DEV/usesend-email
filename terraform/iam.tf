# =============================================================================
# IAM. Two roles:
#   - execution role: used by the ECS agent to pull the image, ship logs, and
#     fetch the Secrets Manager values injected into the container at launch.
#   - task role: the identity the useSend app runs AS. useSend creates SES
#     identities / configuration sets and SNS subscriptions at runtime (when you
#     add a domain in the admin UI), so it needs SES + SNS access, plus S3 for
#     asset storage. No static AWS keys are used — the SDK picks up this role.
# =============================================================================

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---- Execution role ----
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow the execution role to read exactly the secrets we inject.
data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.database_url.arn,
      aws_secretsmanager_secret.redis_url.arn,
      aws_secretsmanager_secret.auth_secret.arn,
      aws_secretsmanager_secret.github_client_secret.arn,
    ]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.project_name}-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

# ---- Task role (app runtime identity) ----
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# useSend provisions SES identities/config-sets and SNS topics/subscriptions at
# runtime. The docs call for AmazonSESFullAccess + AmazonSNSFullAccess. These
# are broad; tighten later to specific actions once your usage is stable.
# (useSend's SES/SNS clients DO use the default credential chain, so this task
# role is what they run as — no static AWS keys needed.)
resource "aws_iam_role_policy_attachment" "task_ses" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_iam_role_policy_attachment" "task_sns" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# NOTE: no S3 policy here on purpose. useSend uses object storage ONLY for
# editor image uploads (optional), and its S3 client uses static
# S3_COMPATIBLE_* keys with a hardcoded region "auto" — a task role does not
# apply. See docs/runbook.md "Object storage (optional)" if you enable it.
