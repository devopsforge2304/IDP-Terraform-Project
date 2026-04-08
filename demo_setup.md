# Demo Setup

This guide is the workflow-first setup for this repository. The intended operating model is:

- developers edit `files/infra-management/infra.yaml`
- GitHub Actions runs `terraform plan` on pull requests
- GitHub Actions runs `terraform apply` after merge and environment approval
- you do not need to run Terraform locally for the demo

## 1. Create the base accounts

Create or confirm access to:

- a GitHub repository containing this project
- an AWS account for the demo
- a Vault server
- a Gmail account dedicated to notifications, for example `platform.team.demo@gmail.com`

Also confirm these GitHub repository capabilities are enabled:

- GitHub Actions
- pull requests against `main`
- GitHub Environments

## 2. Prepare the AWS foundation used by the workflow

Before the workflow can run, AWS must already contain the shared platform pieces.

Create these:

1. An IAM OIDC identity provider for GitHub if your AWS account does not already have one
2. An IAM role named `GitHubActionsRole`
3. An S3 bucket for Terraform state
4. A DynamoDB table for Terraform state locking
5. A VPC for each environment you plan to support, or one shared VPC model
6. Private subnets for that VPC
7. Route tables, NAT, and security controls needed for private resources

Example values:

- `AWS_ACCOUNT_ID = 123456789012`
- `TF_STATE_BUCKET = idp-demo-terraform-state`
- `TF_LOCK_TABLE = terraform-state-lock`
- `vpc_id = vpc-0123456789abcdef0`
- `private_subnet_ids = ["subnet-aaa...", "subnet-bbb..."]`

## 3. Create the GitHub OIDC trust for `GitHubActionsRole`

The workflow uses `aws-actions/configure-aws-credentials` and assumes:

- `arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActionsRole`

Create the trust relationship so GitHub Actions can assume the role with OIDC.

At minimum, the trust policy should:

- trust the GitHub OIDC provider `token.actions.githubusercontent.com`
- allow `sts:AssumeRoleWithWebIdentity`
- restrict `sub` to your repository and branch or environment strategy
- restrict `aud` to `sts.amazonaws.com`

Example trust policy shape:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:<ORG>/<REPO>:ref:refs/heads/main",
            "repo:<ORG>/<REPO>:pull_request"
          ]
        }
      }
    }
  ]
}
```

Adjust `<ORG>` and `<REPO>` to your repository.

## 4. Grant the required permissions to `GitHubActionsRole`

The role needs enough access for both the backend and the resources provisioned by this Terraform project.

### 4.1 Backend permissions

Grant permissions to:

- read and write the Terraform state object in S3
- list the state bucket
- use the DynamoDB lock table

That means the role should be able to perform these S3 actions:

- `s3:ListBucket`
- `s3:GetBucketLocation`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`

And these DynamoDB actions:

- `dynamodb:DescribeTable`
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:DeleteItem`

### 4.2 Resource provisioning permissions

This repository can create IAM, RDS, Redis, EC2, S3, CloudWatch, and supporting networking/security resources. In practice, `GitHubActionsRole` needs permission to manage:

- `ec2`
  - VPC lookups
  - subnets
  - security groups
  - ENIs created as part of instances or databases
  - instances
  - EBS volumes and snapshots
  - tags
- `rds`
  - DB instances
  - DB subnet groups
  - tags
- `elasticache`
  - cache clusters
  - subnet groups
  - tags
- `iam`
  - roles
  - inline or attached policies
  - instance profiles
  - role policy attachments
- `s3`
  - buckets
  - bucket encryption
  - public access block
  - bucket versioning
  - lifecycle configuration
  - bucket policy
  - tags
- `cloudwatch`
  - metric alarms
- `kms`
  - only if you choose to supply customer-managed KMS keys in the environment tfvars

The easiest demo approach is:

1. Start from a tightly scoped custom policy that covers the above services and the target account/region.
2. Validate with pull request `plan`.
3. Add only the missing actions surfaced by Terraform errors.

For a short demo, the role is often split into:

- one policy for backend access
- one policy for provisioning access

## 5. Decide how many subnets you need

The current code requires at least two private subnets:

- Terraform enforces `length(var.private_subnet_ids) >= 2`
- RDS subnet groups need multiple subnets
- Redis subnet groups also expect subnet group placement
- EC2 currently uses the first subnet in the list, but the platform still requires at least two for compliant multi-subnet placement

So the practical answer is:

- minimum required: `2` private subnets
- recommended: `2` private subnets in different Availability Zones

Store those subnet IDs in the environment `.tfvars` files, not in GitHub Secrets.

## 6. Create the S3 backend bucket and DynamoDB lock table

Create:

1. an S3 bucket for state, for example `idp-demo-terraform-state`
2. a DynamoDB table for locking, for example `terraform-state-lock`

Recommended backend settings:

- S3 versioning enabled
- bucket encryption enabled
- DynamoDB partition key named `LockID` of type `String`

The workflow builds the state key like this:

- `idp/<environment>/<tenant_name>.tfstate`

That means each tenant and environment combination gets its own state object.

## 7. Create and prepare Vault step by step

Vault is required because the root module always writes outputs through the `vault-inject` module.

Create and prepare Vault in this order:

1. Create or start a Vault server.
2. Initialize and unseal Vault if it is a fresh instance.
3. Enable the KV v2 secrets engine at `secret/` if it is not already mounted.
4. Create a policy for the automation token with write access to the IDP path.
5. Create a token tied to that policy.
6. Save the Vault address and token in GitHub Secrets.

You need these values:

- `VAULT_ADDRESS = http://<vault-host>:8200`
- `VAULT_TOKEN = hvs.xxxxx`

Terraform writes tenant outputs and generated credentials under:

- `secret/idp/<environment>/<tenant_name>`

The automation token should be able to:

- create secrets under `secret/data/idp/*`
- update secrets under `secret/data/idp/*`
- read metadata under `secret/metadata/idp/*`
- optionally list metadata under `secret/metadata/idp/*`
- create the tenant read policy that Terraform manages

Example Vault policy for the automation token:

```hcl
path "secret/data/idp/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "secret/metadata/idp/*" {
  capabilities = ["read", "list", "delete"]
}

path "sys/policies/acl/idp-tenant-*" {
  capabilities = ["create", "update", "read", "list"]
}
```

## 8. Create the Gmail app password step by step

The project sends mail through Gmail SMTP over port `465`.

Create it in this order:

1. Sign in to the Gmail account you want to use.
2. Open your Google Account settings.
3. Go to `Security`.
4. Enable `2-Step Verification` if it is not already enabled.
5. Return to `Security`.
6. Open `App passwords`.
7. Choose `Mail` as the app.
8. Choose `Other` or a custom device name such as `GitHub Actions IDP Demo`.
9. Generate the password.
10. Copy the 16-character app password Google shows.
11. Store that value in the GitHub secret `GMAIL_APP_PASSWORD`.

Also store:

- `GMAIL_SENDER_EMAIL = platform.team.demo@gmail.com`

Important note:

- store the app password value itself in GitHub Secrets
- if Google displays it with spaces, that is fine; GitHub can store it exactly as shown

## 9. Create GitHub repository secrets

In the GitHub repository, create these secrets:

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `VAULT_ADDRESS`
- `VAULT_TOKEN`
- `GMAIL_SENDER_EMAIL`
- `GMAIL_APP_PASSWORD`

These are the secret values the current workflow injects into Terraform.

## 10. Create GitHub Environments and understand why they matter

Create these GitHub Environments:

- `idp-nonprod`
- `idp-production`

Recommended setup:

- add required reviewers to `idp-production`
- optionally add required reviewers to `idp-nonprod`
- optionally scope environment secrets to these environments if you later want stronger separation

The significance of the GitHub Environments in this repo is:

- they act as the deployment approval gate after merge
- the workflow maps `production` requests to `idp-production`
- the workflow maps `dev`, `test`, `qa`, and `staging` to `idp-nonprod`
- reviewers approve the deployment job, not just the pull request
- this creates an auditable separation between code review and deployment authorization

In other words:

- PR review decides whether the change is acceptable
- GitHub Environment approval decides whether the workflow is allowed to apply it

## 11. Fill the environment tfvars files

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

Environment significance in this repository:

- `dev`
  - early team testing and fast feedback
- `test`
  - integration checks and functional validation
- `qa`
  - broader validation before staging or release signoff
- `staging`
  - production-like pre-release verification
- `production`
  - real deployment path with stricter approval expectations

Workflow mapping detail:

- a request with `environment: production` uses `files/environments/prod.tfvars`
- every other environment uses `files/environments/<environment>.tfvars`

## 12. Do you need GitHub secrets for VPC and subnet IDs?

For the current codebase: no.

Right now:

- `vpc_id` comes from the environment `.tfvars` files
- `private_subnet_ids` come from the environment `.tfvars` files
- the workflow does not pass `TF_VAR_vpc_id`
- the workflow does not pass `TF_VAR_private_subnet_ids`

So for the current implementation, update the environment tfvars files rather than GitHub secrets.

## 13. Ignore local fallback tfvars for this demo

`files/terraform.tfvars` exists only as a placeholder or local fallback.

For your operating model:

- do not depend on it
- do not treat it as the source of truth
- GitHub Actions is the source of truth for secret injection

The workflow passes these values at runtime:

- `TF_VAR_vault_address`
- `TF_VAR_vault_token`
- `TF_VAR_gmail_sender_email`
- `TF_VAR_gmail_app_password`

## 14. Prepare the request file

Before running the workflow, update:

- `files/infra-management/infra.yaml`

Set:

- `tenant_name`
- `environment`
- `team_email`
- required resource blocks under `resources`

Make sure pull requests modify the same request file the workflow reads:

- `files/infra-management/infra.yaml`

## 15. Make sure the GitHub runner can reach Vault and Gmail

The workflow runs on `ubuntu-latest`, so plan and apply happen from the GitHub-hosted runner unless you later move to self-hosted runners.

Confirm:

1. the runner can reach `VAULT_ADDRESS`
2. outbound TCP access to `smtp.gmail.com:465` is not blocked
3. Vault policy and token are valid
4. Gmail credentials are valid

If you later move to self-hosted runners, also confirm:

- DNS resolution works
- NAT or internet egress exists
- host firewalls allow outbound traffic
- proxy rules do not block Gmail SMTP or Vault access

## 16. First validation steps before demoing

Run through this order:

1. Confirm the workflow file uses GitHub Secrets for Vault and Gmail.
2. Confirm `files/infra-management/infra.yaml` is the request file being edited.
3. Confirm all repository secrets exist.
4. Confirm `idp-nonprod` and `idp-production` GitHub Environments exist.
5. Confirm `GitHubActionsRole` can be assumed by GitHub Actions.
6. Confirm the target environment `.tfvars` file has a valid `vpc_id` and at least two private subnets.
7. Confirm Vault is reachable and the token can write to `secret/idp/...`.
8. Confirm Gmail SMTP authentication works with the app password.
9. Open a pull request that changes `files/infra-management/infra.yaml`.
10. Verify `validate-request` and `terraform-plan` succeed.
11. Merge to `main`.
12. Approve the deployment in the correct GitHub Environment if approval is required.
13. Verify `terraform-apply`, Vault write, and Gmail notification succeed.

## 17. Quick checklist

You need to create first:

- AWS OIDC provider and `GitHubActionsRole`
- Terraform state bucket
- Terraform lock table
- environment VPC and at least two private subnets
- Vault server, policy, and token
- Gmail sender account and app password
- GitHub Secrets
- GitHub Environments
