# =============================================================================
# RDS for PostgreSQL — useSend's primary datastore (Prisma).
# Password is generated here and injected into the app as a DATABASE_URL secret
# (see secrets.tf). Keep remote state encrypted; the password lives in state.
# =============================================================================

resource "random_password" "db" {
  length  = 32
  special = false # keep it URL-safe for DATABASE_URL
}

# Unique suffix so repeated destroys don't collide on a retained snapshot name.
resource "random_id" "snapshot" {
  byte_length = 3
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${var.project_name}-db" }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-pg"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 5 # autoscale headroom
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = var.db_multi_az
  publicly_accessible    = false

  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.project_name}-pg-final-${random_id.snapshot.hex}"

  # Performance Insights isn't supported on the smallest classes (e.g. t4g.micro/
  # small). Enable once you're on db.t4g.medium+ / db.m*/r*.
  performance_insights_enabled = false

  tags = { Name = "${var.project_name}-pg" }
}
