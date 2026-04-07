# ============================================================
# Module: Vault Secret Injection
# Stores all provisioned credentials in Vault after apply
# ============================================================

resource "vault_kv_secret_v2" "tenant_secrets" {
  mount               = "secret"
  name                = "idp/${var.environment}/${var.tenant_name}"
  delete_all_versions = false

  data_json = jsonencode({
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

  custom_metadata {
    max_versions = 5

    data = {
      tenant      = var.tenant_name
      environment = var.environment
    }
  }
}

resource "vault_policy" "tenant" {
  name = "idp-tenant-${var.tenant_name}-${var.environment}"

  policy = <<EOT
path "secret/data/idp/${var.environment}/${var.tenant_name}" {
  capabilities = ["read", "list"]
}

path "secret/metadata/idp/${var.environment}/${var.tenant_name}" {
  capabilities = ["read", "list"]
}
EOT
}