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
}

resource "aws_security_group" "rds" {
  name        = "${var.tenant_name}-${var.environment}-rds-sg"
  description = "RDS SG for tenant ${var.tenant_name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres from within VPC only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # restrict to VPC CIDR in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier             = "${var.tenant_name}-${var.environment}"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.instance_class
  db_name                = var.db_name
  username               = "admin_${replace(var.tenant_name, "-", "_")}"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  allocated_storage     = 20
  max_allocated_storage = 100 # auto-scaling storage
  storage_encrypted     = true
  storage_type          = "gp3"

  backup_retention_period = 7
  deletion_protection     = var.environment == "production"
  skip_final_snapshot     = var.environment != "production"

  performance_insights_enabled = true

  tags = {
    Tenant = var.tenant_name
  }
}
