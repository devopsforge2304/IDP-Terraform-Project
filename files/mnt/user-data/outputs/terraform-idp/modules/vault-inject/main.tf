# ============================================================
# Module: Vault Secret Injection
# Stores all provisioned credentials in Vault after apply
# ============================================================

resource "vault_kv_secret_v2" "tenant_secrets" {
  mount               = "secret"
  name                = "idp/${var.environment}/${var.tenant_name}"
  delete_all_versions = false

  data_json = jsonencode({
    # RDS credentials
    rds_endpoint = var.rds_endpoint
    rds_username = var.rds_username
    rds_password = var.rds_password

    # S3
    s3_bucket_name = var.s3_bucket_name

    # Redis
    redis_endpoint = var.redis_endpoint

    # Metadata
    provisioned_at = timestamp()
    environment    = var.environment
    tenant         = var.tenant_name
  })

  custom_metadata {
    max_versions = 5 # keep last 5 rotations
    data = {
      tenant      = var.tenant_name
      environment = var.environment
    }
  }
}

# Vault policy — read-only for the tenant's own secrets
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

variable "tenant_name" { type = string }
variable "environment" { type = string }

variable "rds_endpoint" {
  type    = string
  default = ""
}

variable "rds_username" {
  type    = string
  default = ""
}

variable "rds_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "s3_bucket_name" {
  type    = string
  default = ""
}

variable "redis_endpoint" {
  type    = string
  default = ""
}

output "vault_path" {
  value = vault_kv_secret_v2.tenant_secrets.path
}

output "vault_policy_name" {
  value = vault_policy.tenant.name
}
