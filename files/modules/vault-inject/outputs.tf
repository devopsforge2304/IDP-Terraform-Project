output "vault_path" {
  value = vault_kv_secret_v2.tenant_secrets.path
}

output "vault_policy_name" {
  value = vault_policy.tenant.name
}