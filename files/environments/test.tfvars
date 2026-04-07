aws_region = "ap-south-1"

vpc_id = "vpc-0test123456789abc"

private_subnet_ids = [
  "subnet-0test123456789abc",
  "subnet-0test987654321abc",
]

default_ec2_ami_id                = "ami-0test123456789abcd"
default_rds_backup_retention_days = 5

allowed_rds_instance_classes = [
  "db.t3.micro",
  "db.t3.small",
]

allowed_redis_node_types = [
  "cache.t3.micro",
  "cache.t3.small",
]

allowed_ec2_instance_types = [
  "t3.micro",
  "t3.small",
]

# Demo mode: leave alarm actions empty so Terraform does not depend on SNS topics.
# monitor_alarm_actions = [
#   "arn:aws:sns:ap-south-1:111122223333:idp-test-alerts",
# ]

global_tags = {
  Owner       = "platform-engineering"
  CostCenter  = "shared-platform-test"
  Compliance  = "baseline"
  Environment = "test"
}

# Demo mode: keep default AWS-managed encryption and do not require customer-managed KMS keys.
# rds_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/test-rds-key"
# ec2_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/test-ec2-key"
# s3_kms_key_id  = "arn:aws:kms:ap-south-1:111122223333:key/test-s3-key"
