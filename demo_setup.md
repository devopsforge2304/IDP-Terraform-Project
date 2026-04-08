# Demo Setup

This file is the step-by-step prerequisite checklist to get the IDP Terraform demo working from scratch.

## 1. Create the base accounts and tools

Create or confirm access to:

- A GitHub repository for this project
- An AWS account where demo resources will be created
- A Vault server
- A Gmail account dedicated to notifications, for example `platform.team.demo@gmail.com`

Install or confirm access to:

- Terraform
- Git
- `yq`
- `curl`
- AWS CLI
- Vault CLI

## 2. Prepare AWS foundation first

Before the workflow can run, AWS must already contain the shared platform pieces.

Create these:

1. An IAM role named `GitHubActionsRole`
2. An S3 bucket for Terraform state
3. A DynamoDB table for Terraform state locking
4. A VPC for the target environment
5. At least two private subnets in that VPC
6. Route tables, NAT, and security controls needed for private resources

Example values:

- `AWS_ACCOUNT_ID = 123456789012`
- `TF_STATE_BUCKET = idp-demo-terraform-state`
- `TF_LOCK_TABLE = terraform-state-lock`
- `vpc_id = vpc-0123456789abcdef0`
- `private_subnet_ids = ["subnet-aaa...", "subnet-bbb..."]`

The GitHub Actions IAM role must be allowed to:

- Assume via GitHub OIDC
- Read and write the Terraform state bucket
- Read and write the DynamoDB lock table
- Create and manage the AWS resources used by this Terraform project

## 3. Prepare Vault

Create or confirm:

1. A running Vault server
2. A token that Terraform can use
3. The KV v2 secrets engine mounted at `secret/`

Example values:

- `VAULT_ADDRESS = http://<vault-host>:8200`
- `VAULT_TOKEN = hvs.xxxxx`

Terraform writes tenant outputs and generated credentials under:

- `secret/idp/<environment>/<tenant_name>`

## 4. Prepare Gmail for notifications

The project sends mail through Gmail SMTP over port `465`.

Create or confirm:

1. A Gmail account dedicated to sending notifications
2. 2-Step Verification enabled on that Gmail account
3. A Google App Password generated for Mail

Example values:

- `GMAIL_SENDER_EMAIL = platform.team.demo@gmail.com`
- `GMAIL_APP_PASSWORD = abcd efgh ijkl mnop`

When storing `GMAIL_APP_PASSWORD` in GitHub Secrets, save the app password value itself. It is fine if Google shows it grouped with spaces.

## 5. Create GitHub repository secrets

In the GitHub repository, create these secrets:

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `VAULT_ADDRESS`
- `VAULT_TOKEN`
- `GMAIL_SENDER_EMAIL`
- `GMAIL_APP_PASSWORD`

These are the only secret values the current workflow injects into Terraform.

## 6. Create GitHub Environments

Create these GitHub Environments:

- `idp-nonprod`
- `idp-production`

Recommended:

- Add required reviewers to `idp-production`
- Optionally add required reviewers to `idp-nonprod`

## 7. Fill environment tfvars files

The current design expects network and environment configuration in the Terraform env files under `files/environments/`.

For each environment file such as:

- `files/environments/dev.tfvars`
- `files/environments/test.tfvars`
- `files/environments/qa.tfvars`
- `files/environments/staging.tfvars`
- `files/environments/prod.tfvars`

Set or review these non-secret values:

- `aws_region`
- `vpc_id`
- `private_subnet_ids`
- `default_ec2_ami_id`
- `default_rds_backup_retention_days`
- `allowed_rds_instance_classes`
- `allowed_redis_node_types`
- `allowed_ec2_instance_types`
- `global_tags`
- optional `monitor_alarm_actions`
- optional `rds_kms_key_id`
- optional `ec2_kms_key_id`
- optional `s3_kms_key_id`

## 8. Do you need GitHub env vars or secrets for VPC and subnet IDs?

For the current codebase: no, not by default.

Right now:

- `vpc_id` comes from the environment `.tfvars` files
- `private_subnet_ids` come from the environment `.tfvars` files
- the workflow does not pass `TF_VAR_vpc_id`
- the workflow does not pass `TF_VAR_private_subnet_ids`

So for the current implementation, you should update the environment tfvars files rather than GitHub secrets.

Use GitHub secrets only if:

- you consider the network IDs sensitive in your organization, or
- you want different values injected at runtime instead of storing them in repo tfvars

If you want that model later, the workflow would need to be extended to pass:

- `TF_VAR_vpc_id`
- `TF_VAR_private_subnet_ids`

## 9. Review the local fallback tfvars

`files/terraform.tfvars` is currently useful for local/manual runs and demo testing.

Review these values there:

- `vault_address`
- `vault_token`
- `gmail_sender_email`
- `gmail_app_password`

Do not rely on that file for GitHub Actions. The workflow uses GitHub Secrets for those values.

## 10. Prepare the request file

Before running the workflow, update the request definition with:

- `tenant_name`
- `environment`
- `team_email`
- required resource blocks under `resources`

The example request file currently lives outside the Terraform folder at:

- `infra-management/infra.yaml`

Make sure the workflow path and Terraform path both point to the same request file before your first demo run.

## 11. Make sure the runner can reach `smtp.gmail.com:465`

If you use GitHub-hosted runners:

- outbound internet access is usually already available
- you mainly need to ensure there is no repository, organization, or enterprise policy blocking outbound SMTP-like traffic from your workflow environment

If you use a self-hosted runner:

1. Confirm DNS resolution works for `smtp.gmail.com`
2. Confirm outbound TCP traffic to port `465` is allowed
3. Confirm the runner host firewall allows outbound `465`
4. Confirm the VPC security architecture allows the runner to reach the internet
5. If the runner is in a private subnet, confirm a working NAT path exists
6. Confirm any corporate proxy or egress filter does not block Gmail SMTP

Useful checks from the runner:

```bash
nslookup smtp.gmail.com
nc -vz smtp.gmail.com 465
curl -v --ssl-reqd smtps://smtp.gmail.com:465
```

If `nc` fails:

- check egress firewall rules
- check NAT or internet gateway routing
- check corporate egress controls

If DNS fails:

- fix resolver settings on the runner host
- verify outbound UDP/TCP DNS access

If TLS connects but auth fails:

- verify `GMAIL_SENDER_EMAIL`
- verify `GMAIL_APP_PASSWORD`
- confirm 2-Step Verification is enabled
- generate a fresh App Password and update the GitHub Secret

## 12. First validation steps before demoing

Run through this order:

1. Confirm the workflow file is using Gmail secrets, not Slack secrets
2. Confirm the request file path is correct in both workflow and Terraform
3. Confirm all GitHub Secrets exist
4. Confirm the GitHub Environments exist
5. Confirm the AWS role can be assumed by GitHub Actions
6. Confirm the tfvars file for the target environment has a valid `vpc_id` and at least two private subnets
7. Confirm Vault is reachable from the runner
8. Confirm Gmail SMTP is reachable from the runner
9. Open a PR that changes the request file
10. Verify `validate-request` and `terraform-plan` succeed
11. Merge to `main`
12. Verify `terraform-apply`, Vault write, and Gmail notification succeed

## 13. Quick checklist

You need to create first:

- AWS account foundation
- GitHub OIDC role
- Terraform state bucket
- Terraform lock table
- environment VPC and subnets
- Vault server and token
- Gmail sender account and app password
- GitHub Secrets
- GitHub Environments
- environment tfvars values
- request file values
- runner egress path to `smtp.gmail.com:465`
