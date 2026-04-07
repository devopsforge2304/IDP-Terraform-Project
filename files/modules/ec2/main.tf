# ============================================================
# Module: EC2 — tenant compute execution layer
# ============================================================

resource "aws_security_group" "ec2" {
  name        = "${var.tenant_name}-${var.environment}-ec2-sg"
  description = "EC2 SG for tenant ${var.tenant_name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.tenant_name}-${var.environment}-ec2-sg" })

  ingress {
    description = "HTTPS within VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "SSH within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "this" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = var.iam_instance_profile_name
  monitoring             = true

  root_block_device {
    encrypted   = true
    kms_key_id  = var.kms_key_id
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-${var.environment}-ec2-${count.index + 1}"
  })
}

resource "aws_ebs_snapshot" "backup" {
  count     = var.backup_enabled ? var.instance_count : 0
  volume_id = aws_instance.this[count.index].root_block_device[0].volume_id

  tags = merge(var.tags, {
    Name = "${var.tenant_name}-${var.environment}-ec2-backup-${count.index + 1}"
  })
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.instance_count
  alarm_name          = "${var.tenant_name}-${var.environment}-ec2-${count.index + 1}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "High CPU for tenant EC2 instance."
  alarm_actions       = var.monitor_actions
  ok_actions          = var.monitor_actions

  dimensions = {
    InstanceId = aws_instance.this[count.index].id
  }
}

variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "instance_type" { type = string }
variable "instance_count" { type = number }
variable "ami_id" { type = string }
variable "subnet_id" { type = string }
variable "vpc_id" { type = string }
variable "iam_instance_profile_name" { type = string }
variable "backup_enabled" { type = bool }
variable "monitor_actions" { type = list(string) }
variable "kms_key_id" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }

output "private_ips" {
  value = aws_instance.this[*].private_ip
}
