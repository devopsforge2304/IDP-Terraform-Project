# ============================================================
# Module: Redis (ElastiCache) — per tenant
# ============================================================

resource "aws_security_group" "redis" {
  name        = "${var.tenant_name}-${var.environment}-redis-sg"
  description = "Redis SG for tenant ${var.tenant_name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.tenant_name}-${var.environment}-redis-sg" })

  ingress {
    from_port   = 6379
    to_port     = 6379
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

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.tenant_name}-${var.environment}-redis-subnet"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.tenant_name}-${var.environment}"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.redis.id]
  apply_immediately    = true

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.tenant_name}-${var.environment}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "High CPU for tenant Redis cluster."
  alarm_actions       = var.monitor_actions
  ok_actions          = var.monitor_actions

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.this.id
  }
}
