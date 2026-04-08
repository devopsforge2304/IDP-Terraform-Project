output "secret_name" {
  value = aws_secretsmanager_secret.tenant_secrets.name
}

output "secret_arn" {
  value = aws_secretsmanager_secret.tenant_secrets.arn
}
