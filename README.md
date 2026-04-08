# Terraform Internal Developer Platform

This repository implements a GitHub-driven Internal Developer Platform (IDP) for Terraform on AWS. Developers submit a single [`infra.yaml`](./files/infra-management/infra.yaml) request, open a pull request, and the platform validates, plans, approves, and applies infrastructure through standardized Terraform modules.

## What The Platform Does

- Provisions tenant-scoped AWS infrastructure from one YAML request
- Enforces environment and sizing guardrails before Terraform runs
- Uses environment-specific `.tfvars` files from [`files/environments/`](./files/environments)
- Stores provisioned connection details in AWS Secrets Manager
- Emails a provisioning summary with estimated monthly cost through Gmail
- Separates PR-time `plan` from post-merge `apply`
- Runs scheduled drift detection

## Supported Resources

The current implementation supports these optional resource blocks in [`files/infra-management/infra.yaml`](./files/infra-management/infra.yaml):

- `rds`: PostgreSQL, encrypted storage, backups, CloudWatch CPU alarm, Multi-AZ required in production
- `redis`: ElastiCache Redis, private subnet placement, CloudWatch CPU alarm
- `ec2`: encrypted root volume, IAM instance profile, detailed monitoring, optional backup snapshot, production backup enforcement
- `s3`: tenant bucket, versioning, lifecycle policy, encryption, public access block, IAM-restricted bucket policy

Every request also creates or uses:

- a tenant IAM role and instance profile
- an AWS Secrets Manager secret named `idp/<environment>/<tenant>`
- a Gmail notification summarizing provisioned resources and estimated cost

## Current Pipeline Behavior

The workflow file is [`idp-pipeline.yml`](./.github/workflows/idp-pipeline.yml).

- `pull_request` to `main`
  - triggers when `files/infra-management/infra.yaml`, Terraform files, tfvars, scripts, or the workflow change
  - runs request loading, policy validation, `terraform fmt`, `terraform validate`, and `terraform plan`
  - uploads a plan artifact and comments the plan summary on the PR
- `push` to `main`
  - reruns request loading and validation
  - enforces the GitHub Environment approval gate
  - runs `terraform apply`
- `schedule`
  - runs daily drift detection at `0 2 * * *`
- `workflow_dispatch`
  - allows manual execution

## Workflow-Only Operating Model

- edit [`files/infra-management/infra.yaml`](./files/infra-management/infra.yaml) in a branch
- open a pull request to run validation and `terraform plan`
- merge to `main` to make the request eligible for deployment
- approve the matching GitHub Environment when required
- let GitHub Actions run `terraform apply`

For this repository:

- workflow secrets supply Gmail credentials at runtime
- AWS credentials from GitHub OIDC are also used to create and update AWS Secrets Manager secrets
- environment `.tfvars` files supply VPC and subnet IDs
- at least two private subnets are required
- `production` requests map to `files/environments/prod.tfvars`

## Request Flow

```mermaid
flowchart TD
    A[Developer updates files/infra-management/infra.yaml] --> B[Open pull request to main]
    B --> C[Load request config]
    C --> D[Validate YAML and policy rules]
    D --> E[Terraform fmt and validate]
    E --> F[Terraform plan with environment tfvars]
    F --> G[Upload plan artifact and PR comment]
    G --> H[Merge pull request]
    H --> I[GitHub Environment approval gate]
    I --> J[Terraform apply on main]
    J --> K[Write outputs to AWS Secrets Manager]
    K --> L[Send Gmail notification with cost estimate]
```

## Environment Model

```mermaid
flowchart TD
    A[files/environments] --> B[dev.tfvars]
    A --> C[test.tfvars]
    A --> D[qa.tfvars]
    A --> E[staging.tfvars]
    A --> F[prod.tfvars]
    B --> G[dev request settings]
    C --> H[test request settings]
    D --> I[qa request settings]
    E --> J[staging request settings]
    F --> K[production request settings]
```

## Example Request

```yaml
tenant_name: acme-corp
environment: staging
team_email: platform@acme.com
data_sensitivity: internal

resources:
  rds:
    enabled: true
    instance_class: db.t3.micro
    db_name: acmecorpdb
    multi_az: false
    backup_retention_days: 7

  redis:
    enabled: true
    node_type: cache.t3.micro
    num_nodes: 1

  ec2:
    enabled: false
    instance_type: t3.micro
    instance_count: 1
    backup_enabled: true

  s3:
    enabled: true
    versioning: true
    lifecycle_days: 90
```

## Guardrails Enforced Today

Validation is split between [`files/scripts/policy-check.sh`](./files/scripts/policy-check.sh) and Terraform preconditions in [`files/main.tf`](./files/main.tf).

- `tenant_name` must be lowercase and hyphenated
- `environment` must be one of `dev`, `test`, `qa`, `staging`, `production`
- `team_email` is required
- at least one resource must be enabled
- approved instance types are enforced for RDS, Redis, and EC2
- production RDS requires `multi_az: true`
- production EC2 requires `backup_enabled: true`
- at least two private subnet IDs must be supplied through environment tfvars

## Repository Layout

```text
.
├── .github/workflows/idp-pipeline.yml
├── README.md
├── e2e-sequence.md
├── env.md
├── governance-security.md
├── idp-provisioning-workflow.md
├── internal-tf-module-execution-layer.md
└── files
    ├── infra-management
    │   └── infra.yaml
    ├── main.tf
    ├── variables.tf
    ├── terraform.tfvars
    ├── environments
    │   ├── dev.tfvars
    │   ├── prod.tfvars
    │   ├── qa.tfvars
    │   ├── staging.tfvars
    │   └── test.tfvars
    ├── modules
    │   ├── ec2
    │   ├── iam
    │   ├── rds
    │   ├── redis
    │   ├── s3
    │   ├── gmail-notify
    │   └── secrets-manager
    └── scripts
        └── policy-check.sh
```

## Required GitHub Secrets

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `GMAIL_SENDER_EMAIL`
- `GMAIL_APP_PASSWORD`

## Required GitHub Environments

Create these GitHub Environments in the repository settings:

- `idp-nonprod`
- `idp-production`

Why they matter:

- they are the post-merge approval gate for deployments
- `production` routes to `idp-production`
- `dev`, `test`, `qa`, and `staging` route to `idp-nonprod`
- they separate PR review from deployment authorization

## AWS Role Requirements

The workflow assumes an IAM role named `GitHubActionsRole`.

That role must:

- trust GitHub OIDC and allow `sts:AssumeRoleWithWebIdentity`
- access the S3 backend bucket and DynamoDB lock table
- create and manage the AWS resources used by the Terraform modules
- create and update AWS Secrets Manager secrets for tenant outputs

At a minimum, backend access must cover:

- `s3:ListBucket`
- `s3:GetBucketLocation`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `dynamodb:DescribeTable`
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:DeleteItem`

Provisioning access must cover the services used in this project:

- EC2, including security groups, instances, volumes, snapshots, tags, and VPC lookups
- RDS, including DB instances and DB subnet groups
- ElastiCache, including cache clusters and subnet groups
- IAM, including roles, policies, and instance profiles
- S3, including bucket policy, encryption, versioning, lifecycle, and public access block
- CloudWatch alarms
- Secrets Manager, including `CreateSecret`, `UpdateSecret`, `PutSecretValue`, `DescribeSecret`, `TagResource`, and `GetSecretValue` if operators or follow-on automation need read access
- KMS if you use customer-managed KMS keys for workload encryption or Secrets Manager encryption

## AWS Secrets Manager And Gmail Setup

This repository expects:

- AWS Secrets Manager to store tenant outputs under names like `idp/<environment>/<tenant>`
- the GitHub Actions AWS role to manage those secrets during Terraform apply
- a Gmail account with 2-Step Verification enabled
- a Gmail App Password stored in `GMAIL_APP_PASSWORD`

## Environment Tfvars Inputs

Each file in [`files/environments/`](./files/environments) is expected to provide non-secret environment settings such as:

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
- `secrets_manager_kms_key_id`

## Notes About Current Implementation

- Terraform now uses only the AWS provider for infrastructure and secret storage
- AWS credentials used for infrastructure provisioning also back the Secrets Manager write path
- the Gmail notification includes the final secret name and secret ARN so operators know where to retrieve outputs
- `files/terraform.tfvars` is only a local sample; the intended demo path is GitHub Actions
