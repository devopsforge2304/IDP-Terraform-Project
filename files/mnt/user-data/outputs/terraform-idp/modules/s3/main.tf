# ============================================================
# Module: S3 — isolated bucket per tenant
# ============================================================

resource "aws_s3_bucket" "this" {
  bucket = "${var.tenant_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Tenant = var.tenant_name
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Strict bucket policy — only tenant IAM role can access
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTenantRoleOnly"
        Effect    = "Allow"
        Principal = { AWS = var.iam_role_arn }
        Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
      },
      {
        Sid       = "DenyAllOthers"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          ArnNotEquals = {
            "aws:PrincipalArn" = var.iam_role_arn
          }
        }
      }
    ]
  })
}

variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "versioning" { type = bool }
variable "iam_role_arn" { type = string }

output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
