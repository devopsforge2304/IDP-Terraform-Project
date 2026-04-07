# ============================================================
# Module: Slack Notification
# Posts a provisioning summary after successful apply
# ============================================================

locals {
  resource_lines = compact([
    var.rds_endpoint != "N/A" ? "- RDS Postgres: ${var.rds_endpoint}" : "",
    var.redis_endpoint != "N/A" ? "- Redis: ${var.redis_endpoint}" : "",
    var.s3_bucket_name != "N/A" ? "- S3 Bucket: ${var.s3_bucket_name}" : "",
    length(var.ec2_private_ips) > 0 ? "- EC2 Private IPs: ${join(", ", var.ec2_private_ips)}" : "",
  ])

  message_text = join("\n", compact([
    "*IDP Provisioning Complete*",
    "*Tenant:* `${var.tenant_name}` | *Environment:* `${var.environment}`",
    "*Requested by:* ${var.team_email}",
    "",
    "*Resources provisioned:*",
    join("\n", local.resource_lines),
    "",
    "*Vault path:* `${var.vault_path}`",
    "*Estimated monthly cost:* ${local.cost_estimate}",
  ]))

  cost_estimate = format("$%.2f/month", var.estimated_cost_value)
}

resource "terraform_data" "slack_message" {
  input = {
    tenant        = var.tenant_name
    env           = var.environment
    vault_path    = var.vault_path
    resource_hash = sha1(join(",", var.enabled_resources))
  }

  triggers_replace = [
    var.vault_path,
    sha1(join(",", var.enabled_resources)),
    local.cost_estimate,
  ]

  provisioner "local-exec" {
    command = <<EOF
curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer ${var.slack_bot_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "${var.channel_id}",
    "text": "${replace(local.message_text, "\"", "\\\"")}",
    "mrkdwn": true
  }'
EOF
  }
}

variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "team_email" { type = string }
variable "channel_id" { type = string }

variable "slack_bot_token" {
  type      = string
  sensitive = true
}

variable "enabled_resources" { type = list(string) }

variable "rds_endpoint" {
  type    = string
  default = "N/A"
}

variable "s3_bucket_name" {
  type    = string
  default = "N/A"
}

variable "redis_endpoint" {
  type    = string
  default = "N/A"
}

variable "ec2_private_ips" {
  type    = list(string)
  default = []
}

variable "vault_path" { type = string }
variable "estimated_cost_value" { type = number }

output "cost_estimate" {
  value = local.cost_estimate
}
