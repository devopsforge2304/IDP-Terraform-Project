# Netflix Terraform Project: Absolute End-to-End Explanation

## 1. Purpose of this project

This repository models an Internal Developer Platform for infrastructure provisioning with Terraform.

The main idea is simple:

- developers do not write raw Terraform modules for every request
- developers describe what they need in `files/infra-management/infra.yaml`
- the repository and pipeline enforce standards, validation, governance, and review
- approved changes are applied through reusable Terraform modules

This gives the platform team control over security, networking, tagging, environments, and guardrails while still giving developers a self-service workflow.

## 2. What problem this project solves

Without a platform like this, infrastructure requests often happen through:

- manual tickets
- ad hoc Terraform edits
- inconsistent naming and tagging
- weak review and audit trails
- direct production changes without guardrails

This project standardizes that process.

A developer requests infrastructure through one file, the pull request becomes the approval and audit surface, and GitHub Actions plus Terraform perform the technical validation and provisioning.

## 3. Prerequisites before using this project

This section is intentionally first because the project is only meaningful when the operational prerequisites are in place.

## 3.1 GitHub repository prerequisites

You need a GitHub repository with:

- this Terraform project checked in
- the workflow file at `.github/workflows/idp-pipeline.yml`
- the default branch set to `main`
- Actions enabled for the repository
- branch protection on `main`
- required status checks configured if you want PRs blocked until validation passes
- GitHub Environments configured if you want controlled approval before apply

Recommended GitHub operating model:

- feature branches are created by developers
- pull requests target `main`
- `terraform-plan` must pass before merge
- platform/infrastructure owners review Terraform-impacting changes
- production applies require protected GitHub Environment approval

Important accuracy note:

This repository currently contains a real workflow file, but it does not contain a `CODEOWNERS` file or branch protection settings because those are configured in GitHub, not inside Terraform source files.

So when answering "who reviews the PR?", the honest answer is:

- the repo itself does not hard-code reviewers
- in practice, the reviewers should be the platform/infrastructure owners, and optionally the application owner
- production deployment approval is handled by GitHub Environment reviewers if you configure them

## 3.2 Required GitHub secrets

The current pipeline expects these repository or environment secrets:

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `VAULT_ADDRESS`
- `VAULT_TOKEN`
- `SLACK_BOT_TOKEN`
- `SLACK_CHANNEL_ID`

What each one is for:

- `AWS_ACCOUNT_ID`
  Used to build the AWS role ARN that GitHub Actions assumes.

- `TF_STATE_BUCKET`
  The S3 bucket used for remote Terraform state.

- `TF_LOCK_TABLE`
  The DynamoDB table used for Terraform state locking.

- `VAULT_ADDRESS`
  Address of the Vault server.

- `VAULT_TOKEN`
  Token Terraform uses to write outputs and generated secrets into Vault.

- `SLACK_BOT_TOKEN`
  Token used by the Slack module to send a provisioning summary.

- `SLACK_CHANNEL_ID`
  Slack channel destination for pipeline/provisioning notifications.

## 3.3 AWS prerequisites

Before any apply can succeed, AWS must already contain the shared platform foundation.

At minimum you need:

- an AWS account
- an IAM role for GitHub Actions to assume
- an S3 bucket for Terraform remote state
- a DynamoDB table for Terraform state locking
- a VPC for each environment or a shared VPC model
- private subnet IDs for each environment
- network routes and security posture appropriate for RDS, Redis, and EC2

The workflow assumes GitHub Actions can assume a role like:

`arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActionsRole`

That role must be allowed to:

- read and write Terraform state in S3
- use the DynamoDB lock table
- create and manage the AWS services this Terraform stack provisions
- create networking attachments that these modules require
- create IAM resources referenced by the modules

## 3.4 Terraform backend prerequisites

This project uses a remote S3 backend with DynamoDB locking.

That means you need:

- an S3 bucket already created
- a DynamoDB table already created
- the GitHub Actions role allowed to access both

The backend key is environment and tenant aware. The workflow builds it like this:

`idp/<environment>/<tenant_name>.tfstate`

That means each tenant/environment request gets its own Terraform state object path.

## 3.5 Vault prerequisites

Vault is not optional in the current Terraform design because the root module always calls the `vault-inject` module.

You therefore need:

- a reachable Vault server
- a working `VAULT_ADDRESS`
- a valid `VAULT_TOKEN`
- policy permissions allowing writes under the chosen path pattern

The platform stores generated or discovered values in Vault under a path like:

`secret/idp/<environment>/<tenant>`

## 3.6 Slack prerequisites

Slack is also part of the current flow because the root module always calls the `slack-notify` module.

You need:

- a Slack bot token
- a valid Slack channel ID
- the bot invited to that channel

Even though SNS alarm actions are commented out for demo mode, Slack notification is still part of the post-provisioning flow.

## 3.7 Environment configuration prerequisites

Each environment file under `files/environments/` should contain the non-secret values for that environment.

Examples:

- `aws_region`
- `vpc_id`
- `private_subnet_ids`
- `default_ec2_ami_id`
- `default_rds_backup_retention_days`
- allowed size lists
- `global_tags`

For demo mode in this repo:

- SNS alarm action lines are commented out
- KMS key lines are commented out
- default AWS-managed encryption behavior is used where supported

## 3.8 Developer prerequisites

A developer using this repo should understand:

- how to create a Git branch
- how to edit `infra-management/infra.yaml`
- how to open a pull request
- what each environment means
- which resource types are available
- what instance sizes are allowed

The developer does not need to understand every Terraform module implementation detail to request infrastructure, but the reviewers and platform owners should.

## 4. Repository structure and what each file does

## 4.1 Root-level documentation files

- `e2e-sequence.md`
  Business-level sequence of the platform flow.

- `governance-security.md`
  Explains the control plane and governance story.

- `internal-tf-module-execution-layer.md`
  Shows module execution sequencing.

- `env.md`
  Explains how environments are represented.

## 4.2 Main implementation directory

Everything operational lives under `files/`.

- `files/main.tf`
  Root Terraform orchestration layer. Reads YAML, validates, computes tags, and calls all modules.

- `files/variables.tf`
  Defines Terraform inputs from env tfvars, secrets, or defaults.

- `files/infra-management/infra.yaml`
  The developer request surface.

- `files/terraform.tfvars`
  Local/manual/demo values for shared secret-like inputs.

- `files/environments/dev.tfvars`
- `files/environments/test.tfvars`
- `files/environments/qa.tfvars`
- `files/environments/staging.tfvars`
- `files/environments/prod.tfvars`
  Environment-specific non-secret inputs.

- `files/modules/iam/main.tf`
  Creates role, policy, and instance profile.

- `files/modules/rds/main.tf`
  Creates Postgres RDS resources and alarm.

- `files/modules/redis/main.tf`
  Creates ElastiCache Redis resources and alarm.

- `files/modules/ec2/main.tf`
  Creates EC2 instances, snapshots, and alarm.

- `files/modules/s3/main.tf`
  Creates S3 bucket, encryption, policy, and lifecycle controls.

- `files/modules/vault-inject/main.tf`
  Writes selected outputs and credentials into Vault.

- `files/modules/slack-notify/main.tf`
  Sends a Slack summary after provisioning.

- `files/scripts/policy-check.sh`
  Shell-based policy gate for early validation of `infra-management/infra.yaml`.

## 4.3 GitHub workflow location

The real GitHub Actions workflow is:

- `.github/workflows/idp-pipeline.yml`

There is also a reference copy at:

- `files/idp-pipeline.yml`

GitHub Actions only executes the file under `.github/workflows/`.

## 5. The developer journey from branch creation to production of infrastructure

This is the most important section because it explains the operational lifecycle in the exact order it happens.

## 5.1 Step 1: Developer creates a branch

A developer starts from the latest `main` branch and creates a feature branch.

Example:

```bash
git checkout main
git pull origin main
git checkout -b feature/acme-staging-rds-request
```

Purpose of the branch:

- isolate the infrastructure request
- keep unreviewed changes out of `main`
- let CI run on a safe branch before any apply can happen

## 5.2 Step 2: Developer edits `files/infra-management/infra.yaml`

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

The developer is asking for outcomes, not writing infrastructure internals.

Example intent:

- enable RDS for a staging tenant
- request Redis for cache
- disable EC2 if not needed
- enable S3 with lifecycle rules

## 5.3 Step 3: Developer commits and pushes the branch

Example:

```bash
git add files/infra-management/infra.yaml
git commit -m "Request staging infrastructure for acme-corp"
git push origin feature/acme-staging-rds-request
```

At this point nothing is created in AWS yet.

The push only uploads the branch and makes it available for a pull request.

## 5.4 Step 4: Developer opens a pull request to `main`

The developer opens a PR from the feature branch into `main`.

This is the governance checkpoint where the request becomes reviewable.

The PR should ideally include:

- why the infrastructure is needed
- which environment it targets
- expected cost or impact
- whether the request is temporary or permanent
- any application dependency or rollout window

## 5.5 Step 5: GitHub Actions triggers on the pull request

The workflow is configured to trigger on:

- `pull_request`
- `push`
- `schedule`
- `workflow_dispatch`

For the developer PR path, the important event is `pull_request`.

The PR trigger watches these paths:

- `files/infra-management/infra.yaml`
- `files/**/*.tf`
- `files/**/*.tfvars`
- `files/scripts/**`
- `.github/workflows/idp-pipeline.yml`

So if a developer changes `infra-management/infra.yaml`, Terraform files, tfvars files, or the workflow itself, the pipeline runs.

## 5.6 Step 6: Who reviews the pull request

There are two separate review layers conceptually.

### Repository review

The pull request itself should be reviewed by:

- platform/infrastructure owners
- optionally the application or service owner
- optionally security or operations for sensitive changes

Important honesty point:

This repository does not currently include a `CODEOWNERS` file, so reviewer assignment is not hard-coded in source control.

That means the actual reviewers are determined by your GitHub repository settings and team process.

Recommended model:

- non-production requests: reviewed by platform/infrastructure owners
- production-impacting requests: reviewed by platform/infrastructure owners plus the service owner

### Deployment approval

A separate approval layer exists in the workflow through GitHub Environments.

The workflow routes applies to:

- `idp-nonprod` for non-production environments
- `idp-production` for production

If you configure Environment protection rules in GitHub, then approved people in those environments become the final approvers for deployment.

So the clean answer to "who reviews?" is:

- PR reviewers review the code/request before merge
- GitHub Environment approvers review the deployment before apply

## 5.7 Step 7: What reviewers look at in the PR

Reviewers should inspect:

- whether `tenant_name` is correct
- whether the requested `environment` is correct
- whether enabled resources make sense
- whether requested sizes match approved standards
- whether production flags like `multi_az` and backups are safe
- whether the tenant already exists in some other state path or operational process
- whether the request aligns with networking and cost expectations

The Terraform plan comment on the PR is especially useful here because it shows what Terraform intends to create.

## 5.8 Step 8: The PR pipeline jobs run

On a pull request, the workflow runs these jobs in order:

- `load-config`
- `validate-request`
- `terraform-plan`

It does not run `terraform-apply` on PRs.

That is a key protection.

A pull request gives visibility and review, not infrastructure mutation.

## 6. Exact explanation of every pipeline job

## 6.1 `load-config`

Purpose:

- read the request metadata from `files/infra-management/infra.yaml`
- expose values for downstream jobs

What it does:

- checks out the repository
- installs `yq`
- reads `.environment` from `infra-management/infra.yaml`
- reads `.tenant_name` from `infra-management/infra.yaml`
- writes those values into GitHub Actions outputs

Why this matters:

Later jobs need to know:

- which environment tfvars file to use
- which Terraform backend key to use

Without this job, downstream steps would not know whether to plan against `dev.tfvars`, `staging.tfvars`, or `prod.tfvars`.

## 6.2 `validate-request`

Purpose:

- fail fast on invalid YAML requests before Terraform planning

What it does:

- checks out the repository
- installs `yq`
- runs `./scripts/policy-check.sh infra-management/infra.yaml`

What the shell script validates:

- `tenant_name` exists
- `tenant_name` is lowercase and hyphen-safe
- `environment` is one of `dev`, `test`, `qa`, `staging`, `production`
- `team_email` exists
- if RDS is enabled, the class must be supported
- if Redis is enabled, the node type must be supported
- if EC2 is enabled, the instance type must be supported
- if production RDS is requested, `multi_az` must be `true`
- if production EC2 is requested, `backup_enabled` must be `true`

Why this matters:

This gives quick feedback before Terraform even starts evaluating the full graph.

## 6.3 `terraform-plan`

Purpose:

- format-check Terraform
- initialize Terraform with the remote backend
- validate the configuration
- create a plan for reviewers

When it runs:

- only on pull requests

Detailed behavior:

1. Checks out the repository.
2. Configures AWS credentials by assuming the GitHub Actions role.
3. Installs Terraform.
4. Runs `terraform fmt -check -recursive`.
5. Runs `terraform init` with backend config supplied from secrets.
6. Passes secret inputs for Vault and Slack through `TF_VAR_*` environment variables.
7. Runs `terraform validate`.
8. Runs `terraform plan` with the correct environment tfvars file.
9. Saves the plan as an artifact.
10. Posts a plan summary as a PR comment.

How the environment file is selected:

- if the YAML environment is `production`, the workflow uses `environments/prod.tfvars`
- otherwise it uses `environments/<environment>.tfvars`

Examples:

- `dev` -> `environments/dev.tfvars`
- `staging` -> `environments/staging.tfvars`
- `production` -> `environments/prod.tfvars`

Why the PR plan matters:

- reviewers can see the exact resource impact before merge
- unexpected changes can be caught early
- this becomes part of the change record

## 6.4 `approval-gate`

Purpose:

- stop automatic apply until the right deployment approval path is satisfied

When it runs:

- on push to `main`

What it does:

- maps production to the `idp-production` GitHub Environment
- maps everything else to `idp-nonprod`

Why this matters:

GitHub Environments can require manual approval before the job is allowed to proceed.

So even after code is merged into `main`, apply can still be held until the correct environment approver signs off.

## 6.5 `terraform-apply`

Purpose:

- actually create, update, or destroy infrastructure after merge and approval

When it runs:

- on push to `main`
- after `load-config`
- after `validate-request`
- after `approval-gate`

What it does:

1. Checks out the repository.
2. Configures AWS credentials.
3. Installs Terraform.
4. Runs `terraform init` with remote backend settings.
5. Supplies Vault and Slack secrets through `TF_VAR_*` environment variables.
6. Runs `terraform apply -auto-approve` with the matching environment tfvars file.

What this means operationally:

- the merge to `main` is the point where the request becomes eligible for real infrastructure changes
- GitHub Environment approval is the final gate before apply

## 6.6 `drift-detection`

Purpose:

- detect whether real infrastructure has drifted away from code

When it runs:

- on the configured schedule

What it does:

- initializes Terraform against the same backend
- runs `terraform plan -detailed-exitcode`
- uses the same environment tfvars selection logic

Why it matters:

If someone changes AWS resources manually outside Terraform, drift detection can reveal that the real state no longer matches the repository.

## 6.7 `workflow_dispatch`

The workflow also supports manual execution from GitHub Actions.

This is useful for:

- testing the pipeline
- manually rerunning after fixing secrets or permissions
- controlled operational runs

## 7. How the PR becomes a merge to `main`

This is the sequence that answers your question about how `infra-management/infra.yaml` gets pushed to `main`.

## 7.1 The request exists only in the feature branch at first

When the developer edits `infra-management/infra.yaml` in their branch, only that branch contains the change.

`main` is untouched.

## 7.2 The PR pipeline runs against the branch change

GitHub Actions runs the pull request workflow using the branch contents.

That means:

- validation happens before merge
- the plan is generated before merge
- reviewers can inspect both the YAML and the Terraform plan before merge

## 7.3 Reviewers approve or request changes

At this stage, reviewers can:

- approve the PR
- request changes
- reject the request operationally

If changes are requested, the developer updates the same branch and pushes again.

That push retriggers the PR pipeline.

## 7.4 The PR is merged into `main`

After approvals and required checks pass, someone merges the PR in GitHub.

That merge is what actually moves the updated `infra-management/infra.yaml` into `main`.

So the answer to "how does `infra-management/infra.yaml` get pushed to main?" is:

- it is first committed on a feature branch
- then reviewed through a pull request
- then merged into `main` through GitHub

The repository does not auto-merge by itself unless you separately configure GitHub auto-merge.

## 7.5 Merge to `main` triggers the deployment path

Once merged, GitHub emits a `push` event on `main`.

That triggers the `approval-gate` and `terraform-apply` path in the workflow.

This is the moment where real infrastructure can be changed.

## 8. Detailed explanation of `files/infra-management/infra.yaml`

This file is the self-service request contract.

Current shape:

- `tenant_name`
- `environment`
- `team_email`
- `data_sensitivity`
- `resources`

Under `resources`, the developer can request:

- `rds`
- `redis`
- `ec2`
- `s3`

Each resource block has its own options.

### RDS block

Examples of supported intent:

- `enabled`
- `instance_class`
- `db_name`
- `multi_az`
- `backup_retention_days`

### Redis block

Examples:

- `enabled`
- `node_type`
- `num_nodes`

### EC2 block

Examples:

- `enabled`
- `instance_type`
- `instance_count`
- `backup_enabled`
- optional `ami_id`

### S3 block

Examples:

- `enabled`
- `versioning`
- `lifecycle_days`

## 9. Detailed explanation of `files/scripts/policy-check.sh`

This script is the fast, lightweight policy gate before Terraform plan.

It uses `yq` to parse `infra-management/infra.yaml` and validate key rules.

Step by step, it does the following:

1. Reads `tenant_name`, `environment`, and `team_email`.
2. Fails if `tenant_name` is missing.
3. Fails if `tenant_name` is not lowercase letters, numbers, and hyphens only.
4. Fails if `environment` is not one of the allowed values.
5. Fails if `team_email` is missing.
6. If RDS is enabled, checks whether the requested class is allowed.
7. If production RDS is enabled, requires `multi_az=true`.
8. If Redis is enabled, checks the node type.
9. If EC2 is enabled, checks the instance type.
10. If production EC2 is enabled, requires `backup_enabled=true`.
11. Prints a success message if all checks pass.

Why keep this script when Terraform also has validation?

Because it gives a very fast and understandable CI signal before Terraform init/plan does more expensive work.

## 10. Detailed explanation of `files/main.tf`

`main.tf` is the root orchestration layer.

Its job is not to be the place where all resources are written directly. Its job is to:

- read the YAML request
- validate it
- calculate derived values
- call the right modules with standardized inputs

## 10.1 Terraform and providers block

This block defines:

- required Terraform version
- AWS provider
- Random provider
- Vault provider
- remote S3 backend configuration shape

The actual backend bucket/table values are injected during `terraform init` in the pipeline.

## 10.2 AWS provider block

The AWS provider uses `var.aws_region` and applies default tags using `local.mandatory_tags`.

That means most resources automatically inherit the standard governance tags.

## 10.3 Vault provider block

The Vault provider uses:

- `var.vault_address`
- `var.vault_token`

These come from pipeline secrets or local tfvars.

## 10.4 Locals block

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

This block is the bridge between the user-facing YAML model and the internal Terraform graph.

## 10.5 `terraform_data.workflow_validation`

This resource is used as a validation guardrail.

Its lifecycle preconditions enforce:

- approved environments
- naming pattern for tenant
- required team email
- at least one resource enabled
- approved RDS instance classes
- approved Redis node types
- approved EC2 instance types
- production RDS must be Multi-AZ
- production EC2 backups cannot be disabled
- at least two private subnets must be available

This prevents invalid requests from moving deeper into provisioning.

## 10.6 Module orchestration order

The root module calls:

- `module.iam`
- `module.rds`
- `module.redis`
- `module.ec2`
- `module.s3`
- `module.vault_inject`
- `module.slack_notify`

Important execution idea:

- IAM is foundational
- workload modules are conditional based on the YAML request
- Vault and Slack happen after resources exist

## 11. Detailed explanation of every module

## 11.1 IAM module

Purpose:

- create tenant-specific IAM access boundaries for provisioned resources

What it creates:

- IAM role
- IAM policy
- IAM instance profile

Why it matters:

- EC2 instances need an instance profile
- S3 bucket access is restricted to the tenant role
- permissions are built from the resource request, which reduces unnecessary access

## 11.2 RDS module

Purpose:

- create a tenant-scoped PostgreSQL database layer

What it creates:

- random database password
- DB subnet group
- security group
- PostgreSQL RDS instance
- CloudWatch CPU alarm

Key behavior:

- private subnet placement
- encrypted storage
- optional custom KMS key if supplied, otherwise default encryption path
- no public access
- backup retention set from YAML or environment defaults
- deletion protection in production
- final snapshot behavior differs by environment
- Multi-AZ support for production-safe topology

## 11.3 Redis module

Purpose:

- create tenant-scoped ElastiCache Redis

What it creates:

- security group
- ElastiCache subnet group
- Redis cluster
- CloudWatch CPU alarm

Key behavior:

- private network placement
- node type and node count driven by YAML request
- monitoring alarm actions remain optional; in demo mode they are empty

## 11.4 EC2 module

Purpose:

- create compute instances for tenant workloads

What it creates:

- security group
- one or more EC2 instances
- optional EBS snapshots for backups
- CloudWatch CPU alarms per instance

Key behavior:

- instance count driven by YAML
- AMI comes from the YAML request if provided, otherwise from env tfvars
- detailed monitoring enabled
- root volume encryption enabled
- optional custom KMS key if supplied, otherwise default encryption path
- production backup guardrail enforced in root validation

## 11.5 S3 module

Purpose:

- create a tenant-specific storage bucket

What it creates:

- S3 bucket
- versioning configuration
- default server-side encryption configuration
- optional lifecycle policy
- public access block
- bucket policy scoped to the tenant IAM role

Key behavior:

- bucket is private
- versioning is configurable
- encryption is always on
- if a KMS key is provided, S3 uses KMS
- if no KMS key is provided, S3 falls back to AES256

## 11.6 Vault injection module

Purpose:

- store infrastructure outputs and generated credentials in Vault

Examples of values written:

- RDS endpoint
- RDS username
- RDS password
- S3 bucket name
- Redis endpoint
- EC2 private IPs

Why it matters:

Applications and operators should retrieve important runtime values from Vault rather than hunting through Terraform output manually.

## 11.7 Slack notify module

Purpose:

- send a provisioning summary after Terraform completes

What it communicates:

- tenant name
- environment
- enabled resources
- selected endpoints or outputs
- Vault path
- estimated cost information

Operational note:

Slack still requires valid secrets in the current design.

## 12. Explanation of `variables.tf`

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

Examples of variables supplied by secrets:

- `vault_address`
- `vault_token`
- `slack_bot_token`
- `slack_channel_id`

## 13. Explanation of environment tfvars files

These files define environment-wide, non-secret defaults and guardrails.

Examples:

- [dev.tfvars](/Users/rahuloli/Downloads/Terraform%20Projects/Netflix-Terraform-Project/files/environments/dev.tfvars)
- [test.tfvars](/Users/rahuloli/Downloads/Terraform%20Projects/Netflix-Terraform-Project/files/environments/test.tfvars)
- [qa.tfvars](/Users/rahuloli/Downloads/Terraform%20Projects/Netflix-Terraform-Project/files/environments/qa.tfvars)
- [staging.tfvars](/Users/rahuloli/Downloads/Terraform%20Projects/Netflix-Terraform-Project/files/environments/staging.tfvars)
- [prod.tfvars](/Users/rahuloli/Downloads/Terraform%20Projects/Netflix-Terraform-Project/files/environments/prod.tfvars)

They now carry:

- region
- VPC ID
- private subnets
- AMI defaults
- backup defaults
- allowed sizes
- tags

For the current demo setup:

- SNS alarm action examples are commented out
- KMS key examples are commented out

That keeps the demo easier to run while preserving the extension points.

## 14. What happens after Terraform apply succeeds

After apply:

- AWS resources exist or are updated
- Terraform state is stored in the remote S3 backend
- state locking is released in DynamoDB
- infrastructure outputs are written to Vault
- a Slack summary is sent
- the merged PR plus workflow run form the audit trail

## 15. What happens if something fails

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

## 16. Clean mental model of the whole system

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
- Vault is the secret/output handoff layer
- Slack is the notification layer

## 17. End-to-end sequence in one continuous story

Here is the full story in one pass.

1. A developer needs infrastructure.
2. The developer creates a branch from `main`.
3. The developer edits `files/infra-management/infra.yaml` to request resources.
4. The developer commits and pushes the branch.
5. The developer opens a PR targeting `main`.
6. GitHub Actions triggers because `infra-management/infra.yaml` changed.
7. `load-config` reads `tenant_name` and `environment`.
8. `validate-request` runs `policy-check.sh`.
9. `terraform-plan` runs `fmt`, `init`, `validate`, and `plan`.
10. The plan is uploaded and commented on the PR.
11. Reviewers inspect both the YAML request and the Terraform plan.
12. If changes are needed, the developer updates the same branch and pushes again.
13. The pipeline reruns on the updated PR.
14. Once reviewers are satisfied, the PR is approved.
15. Someone merges the PR into `main`.
16. The merge causes a `push` event on `main`.
17. The workflow starts the deployment path.
18. `approval-gate` routes the deployment through the correct GitHub Environment.
19. If environment approval is configured, an authorized approver must approve.
20. `terraform-apply` runs after approval.
21. Terraform reads the merged `infra-management/infra.yaml` from `main`.
22. Terraform loads the matching environment tfvars file.
23. Terraform uses secret inputs for Vault and Slack from GitHub secrets.
24. `main.tf` validates the request and orchestrates the modules.
25. IAM is created first.
26. Requested workload modules are created next.
27. Outputs and credentials are written into Vault.
28. Slack notification is sent.
29. Terraform state is updated in S3 and unlocked in DynamoDB.
30. Later, the scheduled drift detection job checks whether real infrastructure still matches code.

## 18. Final summary

This repository is not just Terraform code. It is a controlled delivery system for infrastructure.

It combines:

- developer self-service through `infra-management/infra.yaml`
- governance through PR review
- fast policy validation through shell scripting
- standardized resource creation through reusable Terraform modules
- environment-specific defaults through `environments/*.tfvars`
- deployment control through GitHub Actions and GitHub Environments
- secret/output handling through Vault
- operational visibility through Slack
- safety and consistency through remote Terraform state and locking

If you want this to behave cleanly in a real team, the critical operational controls outside the code are:

- branch protection on `main`
- required status checks
- PR review discipline
- GitHub Environment approval rules
- correct repository secrets
- correct AWS IAM permissions for the GitHub Actions role

With those in place, the full lifecycle becomes predictable:

request -> validate -> review -> plan -> approve -> merge -> apply -> store secrets -> notify -> monitor drift
