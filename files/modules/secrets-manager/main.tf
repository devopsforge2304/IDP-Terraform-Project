# ============================================================
# Module: AWS Secrets Manager Injection
# Stores all provisioned credentials in AWS Secrets Manager after apply
# ============================================================

locals {
  secret_name = "idp/${var.environment}/${var.tenant_name}"
}

resource "aws_secretsmanager_secret" "tenant_secrets" {
  name                    = local.secret_name
  description             = "Provisioned infrastructure outputs for ${var.tenant_name} in ${var.environment}"
  recovery_window_in_days = 7
  kms_key_id              = var.secrets_manager_kms_key_id

  tags = merge(var.tags, {
    Name = local.secret_name
  })
}

resource "aws_secretsmanager_secret_version" "tenant_secrets" {
  secret_id = aws_secretsmanager_secret.tenant_secrets.id

  secret_string = jsonencode({
    rds_endpoint    = var.rds_endpoint
    rds_username    = var.rds_username
    rds_password    = var.rds_password
    s3_bucket_name  = var.s3_bucket_name
    redis_endpoint  = var.redis_endpoint
    ec2_private_ips = var.ec2_private_ips
    enabled_modules = var.enabled_modules
    provisioned_at  = timestamp()
    environment     = var.environment
    tenant          = var.tenant_name
  })
}
