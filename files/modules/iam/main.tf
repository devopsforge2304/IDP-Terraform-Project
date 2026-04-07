# ============================================================
# Module: IAM — least-privilege role per tenant
# ============================================================

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "lambda.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "tenant" {
  name               = "idp-tenant-${var.tenant_name}-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  description        = "Least-privilege role for tenant ${var.tenant_name} (${var.environment})"
  tags               = var.tags
}

resource "aws_iam_instance_profile" "tenant" {
  name = "idp-tenant-${var.tenant_name}-${var.environment}"
  role = aws_iam_role.tenant.name
}

resource "aws_iam_policy" "tenant" {
  name        = "idp-tenant-${var.tenant_name}-${var.environment}"
  description = "Scoped policy for IDP tenant ${var.tenant_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      var.enable_rds ? [{
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = "arn:aws:rds-db:*:*:dbuser:*/${var.tenant_name}*"
      }] : [],
      var.enable_s3 ? [{
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.tenant_name}-${var.environment}-*",
          "arn:aws:s3:::${var.tenant_name}-${var.environment}-*/*",
        ]
      }] : [],
      var.enable_redis ? [{
        Effect   = "Allow"
        Action   = ["elasticache:Describe*", "elasticache:List*"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Tenant" = var.tenant_name
          }
        }
      }] : [],
      var.enable_ec2 ? [{
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
        ]
        Resource = "*"
      }] : []
    )
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "tenant" {
  role       = aws_iam_role.tenant.name
  policy_arn = aws_iam_policy.tenant.arn
}
