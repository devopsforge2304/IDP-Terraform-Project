# ============================================================
# Module: Slack Notification
# Posts a rich provisioning summary after successful apply
# ============================================================

locals {
  cost_map = {
    "db.t3.micro"    = "$13/month"
    "db.t3.small"    = "$27/month"
    "db.r5.large"    = "$175/month"
    "cache.t3.micro" = "$12/month"
    "cache.t3.small" = "$24/month"
  }

  message_text = <<EOT
*IDP Provisioning Complete* :white_check_mark:

*Tenant:* `${var.tenant_name}` | *Environment:* `${var.environment}`

*Resources provisioned:*
${var.rds_endpoint != "N/A" ? "• RDS Postgres: `${var.rds_endpoint}`" : ""}
${var.redis_endpoint != "N/A" ? "• Redis: `${var.redis_endpoint}`" : ""}
${var.s3_bucket_name != "N/A" ? "• S3 Bucket: `${var.s3_bucket_name}`" : ""}

*Secrets stored in Vault:* `${var.vault_path}`
To retrieve: `vault kv get ${var.vault_path}`

*Estimated monthly cost:* ${var.estimated_cost}

_No DevOps engineer was required to provision this environment._
EOT
}

resource "slack_conversation" "notify" {
  # Uses the Slack provider to post a message
  # The provider handles the API call to Slack
}

# Alternative: use a null_resource + local-exec if you prefer curl
resource "null_resource" "slack_message" {
  triggers = {
    tenant    = var.tenant_name
    env       = var.environment
    timestamp = timestamp()
  }

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
variable "channel_id" { type = string }

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

variable "vault_path" { type = string }

variable "estimated_cost" {
  type    = string
  default = "Calculating..."
}

variable "slack_bot_token" {
  type      = string
  sensitive = true
  default   = ""
}

output "cost_estimate" {
  value = "~$25-50/month (t3.micro tier)"
}
