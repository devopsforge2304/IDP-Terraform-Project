# Terraform Project: Absolute End-to-End Explanation

## 1. Purpose of this project

This repository models an Internal Developer Platform for infrastructure provisioning with Terraform on AWS.

The main idea is simple:

- developers do not write raw Terraform modules for every request
- developers describe what they need in `files/infra-management/infra.yaml`
- the repository and pipeline enforce standards, validation, governance, and review
- approved changes are applied through reusable Terraform modules
- generated outputs and credentials are stored in AWS Secrets Manager for later retrieval

## 2. What problem this project solves

Without a platform like this, infrastructure requests often happen through:

- manual tickets
- ad hoc Terraform edits
- inconsistent naming and tagging
- weak review and audit trails
- direct production changes without guardrails
- secrets scattered across chat, tickets, or local notes

This project standardizes that process.

A developer requests infrastructure through one file, the pull request becomes the approval and audit surface, GitHub Actions plus Terraform perform the technical validation and provisioning, and AWS Secrets Manager becomes the output handoff layer.

## 3. Prerequisites before using this project

### 3.1 GitHub repository prerequisites

You need a GitHub repository with:

- this Terraform project checked in
- the workflow file at `.github/workflows/idp-pipeline.yml`
- the default branch set to `main`
- Actions enabled for the repository
- branch protection on `main`
- required status checks configured if you want PRs blocked until validation passes
- GitHub Environments configured if you want controlled approval before apply

The intended operating model for this repository is GitHub Actions first:

- developers edit `files/infra-management/infra.yaml`
- pull requests run validation and `terraform plan`
- merge plus GitHub Environment approval enables `terraform apply`
- local Terraform execution is optional for development, but it is not the demo path

### 3.2 Required GitHub secrets

The current pipeline expects these repository or environment secrets:

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `GMAIL_SENDER_EMAIL`
- `GMAIL_APP_PASSWORD`

What each one is for:

- `AWS_ACCOUNT_ID`
  Used to build the AWS role ARN that GitHub Actions assumes.

- `TF_STATE_BUCKET`
  The S3 bucket used for remote Terraform state.

- `TF_LOCK_TABLE`
  The DynamoDB table used for Terraform state locking.

- `GMAIL_SENDER_EMAIL`
  Gmail address used by the notification module to send a provisioning summary.

- `GMAIL_APP_PASSWORD`
  Gmail app password used by the notification module for SMTP authentication.

### 3.3 AWS prerequisites

Before any apply can succeed, AWS must already contain the shared platform foundation.

At minimum you need:

- an AWS account
- an IAM role for GitHub Actions to assume
- an S3 bucket for Terraform remote state
- a DynamoDB table for Terraform state locking
- a VPC for each environment or a shared VPC model
- private subnet IDs for each environment
- network routes and security posture appropriate for RDS, Redis, and EC2
- AWS Secrets Manager permissions for the GitHub Actions role
- optional KMS keys if you want customer-managed encryption for workloads or Secrets Manager

The workflow assumes GitHub Actions can assume a role like:

`arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActionsRole`

That role must be allowed to:

- trust the GitHub OIDC provider and allow `sts:AssumeRoleWithWebIdentity`
- read and write Terraform state in S3
- use the DynamoDB lock table
- create and manage the AWS services this Terraform stack provisions
- create and update the per-tenant AWS Secrets Manager secret
- use KMS keys referenced by the Terraform configuration, if any

In practical terms, the role needs:

- S3 backend actions
- DynamoDB lock actions
- provisioning access across EC2, RDS, ElastiCache, IAM, S3, CloudWatch, Secrets Manager, and optionally KMS

### 3.4 Terraform backend prerequisites

This project uses a remote S3 backend with DynamoDB locking.

That means you need:

- an S3 bucket already created
- a DynamoDB table already created
- the GitHub Actions role allowed to access both

The backend key is environment and tenant aware. The workflow builds it like this:

`idp/<environment>/<tenant_name>.tfstate`

That means each tenant and environment request gets its own Terraform state object path.

### 3.5 AWS Secrets Manager prerequisites

AWS Secrets Manager is now the secret and output handoff layer for generated outputs and credentials.

You therefore need:

- a reachable AWS account and region for Secrets Manager
- GitHub Actions AWS credentials with permission to create and update secrets
- optional `secrets_manager_kms_key_id` if you want a customer-managed encryption key
- a decision on who or what is allowed to read the tenant secret after provisioning

Preparation sequence:

1. Decide whether to use the default AWS-managed key or a customer-managed KMS key.
2. If using a customer-managed key, create it and grant the GitHub Actions role access.
3. Grant the role Secrets Manager actions such as `CreateSecret`, `UpdateSecret`, `PutSecretValue`, and `DescribeSecret`.
4. Optionally grant readers `GetSecretValue` on the tenant secret path pattern.
5. Store the KMS key ID or ARN in the environment `.tfvars` files if you use one.

The platform stores generated or discovered values in a secret named like:

`idp/<environment>/<tenant>`

### 3.6 Gmail prerequisites

Gmail notification is also part of the current flow because the root module always calls the `gmail-notify` module.

You need:

- a Gmail account that can send the notification email
- a Gmail App Password
- SMTP access to `smtp.gmail.com:465`

Preparation sequence:

1. Sign in to the sender Gmail account.
2. Enable 2-Step Verification.
3. Open Google Account `Security`.
4. Open `App passwords`.
5. Create a Mail app password for this workflow.
6. Store the sender email and app password in GitHub Secrets.

### 3.7 Environment configuration prerequisites

Each environment file under `files/environments/` should contain the non-secret values for that environment.

Examples:

- `aws_region`
- `vpc_id`
- `private_subnet_ids`
- `default_ec2_ami_id`
- `default_rds_backup_retention_days`
- allowed size lists
- `global_tags`
- `secrets_manager_kms_key_id`

Important network requirement:

- at least two private subnet IDs are required
- recommended placement is two private subnets in different Availability Zones

### 3.8 Developer prerequisites

A developer using this repo should understand:

- how to create a Git branch
- how to edit `infra-management/infra.yaml`
- how to open a pull request
- what each environment means
- which resource types are available
- what instance sizes are allowed

## 4. Repository structure and what each file does

### 4.1 Root-level documentation files

- `e2e-sequence.md`
  Business-level sequence of the platform flow.

- `governance-security.md`
  Explains the control plane and governance story.

- `internal-tf-module-execution-layer.md`
  Shows module execution sequencing.

- `env.md`
  Explains how environments are represented.

### 4.2 Main implementation directory

Everything operational lives under `files/`.

- `files/main.tf`
  Root Terraform orchestration layer. Reads YAML, validates, computes tags, and calls all modules.

- `files/variables.tf`
  Defines Terraform inputs from env tfvars, secrets, or defaults.

- `files/infra-management/infra.yaml`
  The developer request surface.

- `files/terraform.tfvars`
  Local/manual/demo values for Gmail and optional Secrets Manager KMS configuration.

- `files/modules/secrets-manager/main.tf`
  Writes selected outputs and credentials into AWS Secrets Manager.

- `files/modules/gmail-notify/main.tf`
  Sends a Gmail summary after provisioning and includes the secret name and ARN.

## 5. The developer journey from branch creation to production of infrastructure

### 5.1 Step 1: Developer creates a branch

A developer starts from the latest `main` branch and creates a feature branch.

### 5.2 Step 2: Developer edits `files/infra-management/infra.yaml`

The developer describes the request in `files/infra-management/infra.yaml`.

This file contains things like:

- `tenant_name`
- `environment`
- `team_email`
- `data_sensitivity`
- `resources.rds`
- `resources.redis`
- `resources.ec2`
- `resources.s3`

### 5.3 Step 3: Developer commits and pushes the branch

At this point nothing is created in AWS yet.

### 5.4 Step 4: Developer opens a pull request to `main`

This is the governance checkpoint where the request becomes reviewable.

### 5.5 Step 5: GitHub Actions triggers on the pull request

The PR trigger watches the request file, Terraform files, tfvars files, scripts, and the workflow file.

### 5.6 Step 6: Review happens in two layers

- PR reviewers inspect the request and plan
- GitHub Environment approvers authorize deployment after merge

## 6. Exact explanation of every pipeline job

### 6.1 `load-config`

Purpose:

- read `tenant_name` and `environment` from `infra-management/infra.yaml`
- expose them as outputs for later jobs

### 6.2 `validate-request`

Purpose:

- fail fast on invalid YAML requests before Terraform planning

### 6.3 `terraform-plan`

Purpose:

- format-check Terraform
- initialize Terraform with the remote backend
- validate the configuration
- create a plan for reviewers

Detailed behavior:

1. Checks out the repository.
2. Configures AWS credentials by assuming the GitHub Actions role.
3. Installs Terraform.
4. Runs `terraform fmt -check -recursive`.
5. Runs `terraform init` with backend config supplied from secrets.
6. Passes Gmail secrets through `TF_VAR_*` environment variables.
7. Runs `terraform validate`.
8. Runs `terraform plan` with the correct environment tfvars file.
9. Saves the plan as an artifact.
10. Posts a plan summary as a PR comment.

### 6.4 `approval-gate`

Purpose:

- stop automatic apply until the right deployment approval path is satisfied

### 6.5 `terraform-apply`

Purpose:

- actually create, update, or destroy infrastructure after merge and approval

What it does:

1. Checks out the repository.
2. Configures AWS credentials.
3. Installs Terraform.
4. Runs `terraform init` with remote backend settings.
5. Supplies Gmail secrets through `TF_VAR_*` environment variables.
6. Runs `terraform apply -auto-approve` with the matching environment tfvars file.

Operational meaning:

- the merge to `main` is the point where the request becomes eligible for real infrastructure changes
- GitHub Environment approval is the final gate before apply
- the same AWS credentials are used both for resource provisioning and for writing the tenant secret

### 6.6 `drift-detection`

Purpose:

- detect whether real infrastructure has drifted away from code

## 7. Detailed explanation of `files/main.tf`

`main.tf` is the root orchestration layer.

Its job is to:

- read the YAML request
- validate it
- calculate derived values
- call the right modules with standardized inputs

### 7.1 Terraform and providers block

This block defines:

- required Terraform version
- AWS provider
- Random provider
- remote S3 backend configuration shape

The root module now relies on the AWS provider for both infrastructure and secret storage.

### 7.2 AWS provider block

The AWS provider uses `var.aws_region` and applies default tags using `local.mandatory_tags`.

### 7.3 Locals block

This is where the YAML file is decoded and normalized.

Main things created here:

- `local.config`
- `local.tenant_name`
- `local.env`
- resource-specific config objects
- `local.enabled_resources`
- `local.monthly_cost_estimate`
- `local.mandatory_tags`
- default backup retention logic

### 7.4 Validation guardrail

`terraform_data.workflow_validation` enforces:

- approved environments
- naming pattern for tenant
- required team email
- at least one resource enabled
- approved instance classes and types
- production RDS Multi-AZ
- production EC2 backups enabled
- at least two private subnets

### 7.5 Module orchestration order

The root module calls:

- `module.iam`
- `module.rds`
- `module.redis`
- `module.ec2`
- `module.s3`
- `module.secrets_manager`
- `module.gmail_notify`

Important execution idea:

- IAM is foundational
- workload modules are conditional based on the YAML request
- Secrets Manager and Gmail notification happen after resources exist

## 8. Detailed explanation of every module

### 8.1 IAM module

Purpose:

- create tenant-specific IAM access boundaries for provisioned resources

### 8.2 RDS module

Purpose:

- create a tenant-scoped PostgreSQL database layer

It creates a random password, subnet group, security group, DB instance, and monitoring alarm.

### 8.3 Redis module

Purpose:

- create tenant-scoped ElastiCache Redis

### 8.4 EC2 module

Purpose:

- create compute instances for tenant workloads

### 8.5 S3 module

Purpose:

- create a tenant-specific storage bucket

### 8.6 AWS Secrets Manager module

Purpose:

- store infrastructure outputs and generated credentials in AWS Secrets Manager

Examples of values written:

- RDS endpoint
- RDS username
- RDS password
- S3 bucket name
- Redis endpoint
- EC2 private IPs
- enabled module list
- provision timestamp

Why it matters:

Applications and operators can retrieve important runtime values from one AWS-native location instead of chasing Terraform output manually.

The secret naming pattern is:

- `idp/<environment>/<tenant>`

### 8.7 Gmail notify module

Purpose:

- send a provisioning summary email after Terraform completes

What it communicates:

- tenant name
- environment
- enabled resources
- selected endpoints or outputs
- AWS Secrets Manager secret name
- secret ARN
- estimated cost information

## 9. Explanation of `variables.tf`

`variables.tf` defines the input contract for the root module.

These inputs come from three main places:

- environment tfvars files
- pipeline secrets exposed as `TF_VAR_*`
- safe defaults in Terraform

Examples of variables supplied by env tfvars:

- `aws_region`
- `vpc_id`
- `private_subnet_ids`
- `default_ec2_ami_id`
- allowed size lists
- `default_rds_backup_retention_days`
- `global_tags`
- `secrets_manager_kms_key_id`

Examples of variables supplied by secrets:

- `gmail_sender_email`
- `gmail_app_password`

## 10. What happens after Terraform apply succeeds

After apply:

- AWS resources exist or are updated
- Terraform state is stored in the remote S3 backend
- state locking is released in DynamoDB
- infrastructure outputs are written to AWS Secrets Manager
- a Gmail summary is sent
- the merged PR plus workflow run form the audit trail

## 11. What happens if something fails

Failure can happen at multiple points.

### Policy failure

If `policy-check.sh` fails:

- the PR shows a failed validation job
- no Terraform plan is produced
- the developer must edit the branch and push again

### Terraform validation failure

If `terraform validate` fails:

- the PR cannot be safely approved
- reviewers should request changes

### Terraform plan failure

If `terraform plan` fails:

- the plan comment is not trustworthy or may not exist
- the PR should not be merged until the issue is fixed

### Approval-gate hold

If GitHub Environment approval is required:

- the merge can exist on `main`
- but apply will wait until an approved reviewer authorizes the environment deployment

### Apply failure

If `terraform apply` fails:

- the workflow run fails on `main`
- infrastructure may be partially changed depending on where the failure occurred
- the team investigates using Terraform logs, AWS console state, and Terraform state
- if the failure happened while writing the secret, inspect Secrets Manager permissions and KMS access

## 12. Clean mental model of the whole system

A simple way to understand the project is:

- `infra-management/infra.yaml` is the request
- `policy-check.sh` is the fast rule checker
- `main.tf` is the orchestrator
- modules are the standardized implementation units
- env tfvars define environment-wide defaults
- GitHub PR is the review surface
- GitHub Actions is the automation engine
- GitHub Environments provide deployment approval
- Terraform state in S3 is the source of truth for managed resources
- AWS Secrets Manager is the secret and output handoff layer
- Gmail is the notification layer

## 13. End-to-end sequence in one continuous story

1. A developer needs infrastructure.
2. The developer creates a branch from `main`.
3. The developer edits `files/infra-management/infra.yaml` to request resources.
4. The developer commits and pushes the branch.
5. The developer opens a PR targeting `main`.
6. GitHub Actions triggers because the request changed.
7. `load-config` reads `tenant_name` and `environment`.
8. `validate-request` runs `policy-check.sh`.
9. `terraform-plan` runs `fmt`, `init`, `validate`, and `plan`.
10. The plan is uploaded and commented on the PR.
11. Reviewers inspect both the YAML request and the Terraform plan.
12. If changes are needed, the developer updates the branch and pushes again.
13. Once reviewers are satisfied, the PR is approved.
14. Someone merges the PR into `main`.
15. The merge causes a `push` event on `main`.
16. `approval-gate` routes the deployment through the correct GitHub Environment.
17. If environment approval is configured, an authorized approver must approve.
18. `terraform-apply` runs after approval.
19. Terraform reads the merged `infra-management/infra.yaml` from `main`.
20. Terraform loads the matching environment tfvars file.
21. Terraform uses AWS credentials for both provisioning and Secrets Manager writes, and GitHub secrets for Gmail.
22. `main.tf` validates the request and orchestrates the modules.
23. IAM is created first.
24. Requested workload modules are created next.
25. Outputs and credentials are written into AWS Secrets Manager.
26. Gmail notification is sent.
27. Terraform state is updated in S3 and unlocked in DynamoDB.
28. Later, scheduled drift detection checks whether real infrastructure still matches code.

## 14. Final summary

This repository is not just Terraform code. It is a controlled delivery system for infrastructure.

It combines:

- developer self-service through `infra-management/infra.yaml`
- governance through PR review
- fast policy validation through shell scripting
- standardized resource creation through reusable Terraform modules
- environment-specific defaults through `environments/*.tfvars`
- deployment control through GitHub Actions and GitHub Environments
- secret and output handling through AWS Secrets Manager
- operational visibility through Gmail
- safety and consistency through remote Terraform state and locking

With the surrounding GitHub controls and AWS IAM permissions in place, the lifecycle becomes:

request -> validate -> review -> plan -> approve -> merge -> apply -> store secret -> notify -> monitor drift
