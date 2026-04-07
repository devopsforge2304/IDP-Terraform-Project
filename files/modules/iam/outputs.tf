output "role_arn" {
  value = aws_iam_role.tenant.arn
}

output "role_name" {
  value = aws_iam_role.tenant.name
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.tenant.name
}