# ============================================================
# Module: RDS (Postgres) — isolated per tenant
# ============================================================

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.tenant_name}-${var.environment}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.tenant_name}-${var.environment}-rds-sg"
  description = "RDS SG for tenant ${var.tenant_name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.tenant_name}-${var.environment}-rds-sg" })

  ingress {
    description = "Postgres from within the tenant private network"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier                      = "${var.tenant_name}-${var.environment}"
  engine                          = "postgres"
  engine_version                  = "17.7"
  instance_class                  = var.instance_class
  db_name                         = substr(replace(var.db_name, "-", ""), 0, 63)
  username                        = substr("admin_${replace(var.tenant_name, "-", "_")}", 0, 16)
  password                        = random_password.db.result
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_encrypted               = true
  kms_key_id                      = var.kms_key_id
  storage_type                    = "gp3"
  backup_retention_period         = var.backup_retention
  deletion_protection             = var.environment == "production"
  skip_final_snapshot             = var.environment != "production"
  performance_insights_enabled    = true
  monitoring_interval             = 60
  copy_tags_to_snapshot           = true
  multi_az                        = var.multi_az
  publicly_accessible             = false
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  tags                            = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.tenant_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "High CPU for tenant RDS instance."
  alarm_actions       = var.monitor_actions
  ok_actions          = var.monitor_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }

  tags = var.tags
}