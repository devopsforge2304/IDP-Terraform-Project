# ============================================================
# Module: Gmail Notification
# Emails a provisioning summary after successful apply
# ============================================================

locals {
  resource_lines = compact([
    var.rds_endpoint != "N/A" ? "- RDS Postgres: ${var.rds_endpoint}" : "",
    var.redis_endpoint != "N/A" ? "- Redis: ${var.redis_endpoint}" : "",
    var.s3_bucket_name != "N/A" ? "- S3 Bucket: ${var.s3_bucket_name}" : "",
    length(var.ec2_private_ips) > 0 ? "- EC2 Private IPs: ${join(", ", var.ec2_private_ips)}" : "",
  ])

  message_text = join("\n", compact([
    "IDP Provisioning Complete",
    "Tenant: ${var.tenant_name} | Environment: ${var.environment}",
    "Requested by: ${var.team_email}",
    "",
    "Resources provisioned:",
    join("\n", local.resource_lines),
    "",
    "Vault path: ${var.vault_path}",
    "Estimated monthly cost: ${local.cost_estimate}",
  ]))

  cost_estimate = format("$%.2f/month", var.estimated_cost_value)
}

resource "terraform_data" "gmail_message" {
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
tmp_email_file="$(mktemp)"

cat <<'MAIL' > "$tmp_email_file"
From: ${var.gmail_sender_email}
To: ${var.team_email}
Subject: IDP Provisioning Complete - ${var.tenant_name} (${var.environment})
Content-Type: text/plain; charset=UTF-8

${local.message_text}
MAIL

curl -s --ssl-reqd \
  --url "smtps://smtp.gmail.com:465" \
  --user "${var.gmail_sender_email}:${var.gmail_app_password}" \
  --mail-from "${var.gmail_sender_email}" \
  --mail-rcpt "${var.team_email}" \
  --upload-file "$tmp_email_file"

rm -f "$tmp_email_file"
EOF
  }
}
