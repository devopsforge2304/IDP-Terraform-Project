output "endpoint" {
  value = aws_db_instance.this.address
}

output "username" {
  value = aws_db_instance.this.username
}

output "password" {
  value     = random_password.db.result
  sensitive = true
}