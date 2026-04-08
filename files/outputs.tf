output "tenant_name" {
  value = local.tenant_name
}

output "environment" {
  value = local.env
}

output "enabled_resources" {
  value = local.enabled_resources
}

output "estimated_monthly_cost" {
  value = local.monthly_cost_estimate
}

output "secret_name" {
  value = module.secrets_manager.secret_name
}

output "secret_arn" {
  value = module.secrets_manager.secret_arn
}
