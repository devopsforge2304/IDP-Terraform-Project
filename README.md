# Terraform Internal Developer Platform (IDP)

A self-service infrastructure provisioning platform aligned to the workflow docs in this project. Developers submit `infra.yaml`, open a PR, pass validation and policy checks, and then approved changes apply through standardized Terraform modules.

## What gets provisioned

From a single `infra.yaml` file:
- AWS RDS (Postgres) with encryption, backups, CloudWatch alarms, and production Multi-AZ enforcement
- AWS ElastiCache (Redis) with private subnet placement and monitoring alarms
- AWS EC2 with IAM instance profile attachment, backup snapshots, and detailed monitoring
- AWS S3 with encryption, public access blocking, lifecycle policy support, and tenant-scoped access
- IAM Role and Instance Profile with least-privilege permissions derived from the requested resources
- Vault Secrets stored at `secret/idp/<env>/<tenant>`
- Slack Notification with resource summary and estimated monthly cost

## Workflow alignment

The code now reflects the documented flow:
- `infra.yaml` is the developer request payload
- environment-specific tfvars are loaded from `environments/`
- validation covers tenant naming, environment, approved instance types, and production safety rules
- non-secret environment-wide settings such as VPC/subnets, AMI defaults, approved sizes, backup defaults, alarm routes, tags, and KMS keys live in `environments/*.tfvars`
- remote backend usage is expected through GitHub Actions backend config
- the pipeline runs YAML validation, policy checks, `terraform fmt`, `terraform validate`, `terraform plan`, approval gating, drift detection, and `terraform apply`

## Project structure

```text
files/
├── main.tf
├── variables.tf
├── infra.yaml
├── terraform.tfvars
├── environments/
│   ├── dev.tfvars
│   ├── test.tfvars
│   ├── qa.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
├── modules/
│   ├── iam/
│   ├── rds/
│   ├── redis/
│   ├── ec2/
│   ├── s3/
│   ├── vault-inject/
│   └── slack-notify/
└── scripts/
    └── policy-check.sh
```

The GitHub Actions workflow lives at `.github/workflows/idp-pipeline.yml`, with a copy retained in `files/idp-pipeline.yml` for project reference.

## Required CI secrets

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `VAULT_ADDRESS`
- `VAULT_TOKEN`
- `SLACK_BOT_TOKEN`
- `SLACK_CHANNEL_ID`

Environment-specific infrastructure settings are now expected in the matching file under `files/environments/`, for example:
- `aws_region`
- `vpc_id`
- `private_subnet_ids`
- `default_ec2_ami_id`
- `default_rds_backup_retention_days`
- `allowed_rds_instance_classes`
- `allowed_redis_node_types`
- `allowed_ec2_instance_types`
- `monitor_alarm_actions`
- `global_tags`
- `rds_kms_key_id`
- `ec2_kms_key_id`
- `s3_kms_key_id`
