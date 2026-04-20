# Demo Setup

This guide is the workflow-first setup for this repository. The intended operating model is:

- developers edit `files/infra-management/infra.yaml`
- GitHub Actions runs `terraform plan` on pull requests
- GitHub Actions runs `terraform apply` after merge and environment approval
- AWS Secrets Manager stores the generated tenant connection details
- you do not need to run Terraform locally for the demo

## 1. Create the base accounts

Create or confirm access to:

- a GitHub repository containing this project
- an AWS account for the demo
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
8. Optional KMS keys if you want customer-managed encryption for workloads or AWS Secrets Manager

Example values:

- `AWS_ACCOUNT_ID = 123456789012`
- `TF_STATE_BUCKET = idp-demo-terraform-state`
- `TF_LOCK_TABLE = terraform-state-lock`
- `vpc_id = vpc-0123456789abcdef0`
- `private_subnet_ids = ["subnet-aaa...", "subnet-bbb..."]`
- `secrets_manager_kms_key_id = arn:aws:kms:us-east-1:123456789012:key/abcd-1234`

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
            "Sid": "GitHubOidcTrust",
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::492646066724:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:<ORG/USERNAME>/IDP-Terraform-Project:ref:refs/heads/main",
                        "repo:<ORG/USERNAME>/IDP-Terraform-Project:pull_request"
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

### Custom Permission Policy 

```
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "TerraformStateS3",
			"Effect": "Allow",
			"Action": [
				"s3:ListBucket",
				"s3:GetBucketLocation"
			],
			"Resource": "arn:aws:s3:::internal-developers-platoform-terraform-state-bucket"
		},
		{
			"Sid": "TerraformStateObjects",
			"Effect": "Allow",
			"Action": [
				"s3:GetObject",
				"s3:PutObject",
				"s3:DeleteObject"
			],
			"Resource": "arn:aws:s3:::internal-developers-platoform-terraform-state-bucket/idp/*"
		},
		{
			"Sid": "TerraformLockTable",
			"Effect": "Allow",
			"Action": [
				"dynamodb:DescribeTable",
				"dynamodb:GetItem",
				"dynamodb:PutItem",
				"dynamodb:UpdateItem",
				"dynamodb:DeleteItem"
			],
			"Resource": "arn:aws:dynamodb:us-east-1:492646066724:table/idp-terraform-lock-table"
		},
		{
			"Sid": "EC2Access",
			"Effect": "Allow",
			"Action": [
				"ec2:Describe*",
				"ec2:CreateSecurityGroup",
				"ec2:DeleteSecurityGroup",
				"ec2:AuthorizeSecurityGroupIngress",
				"ec2:AuthorizeSecurityGroupEgress",
				"ec2:RevokeSecurityGroupIngress",
				"ec2:RevokeSecurityGroupEgress",
				"ec2:RunInstances",
				"ec2:TerminateInstances",
				"ec2:StartInstances",
				"ec2:StopInstances",
				"ec2:CreateTags",
				"ec2:DeleteTags",
				"ec2:CreateSnapshot",
				"ec2:DeleteSnapshot"
			],
			"Resource": "*"
		},
		{
			"Sid": "RDSAccess",
			"Effect": "Allow",
			"Action": [
				"rds:Describe*",
				"rds:CreateDBInstance",
				"rds:ModifyDBInstance",
				"rds:DeleteDBInstance",
				"rds:CreateDBSubnetGroup",
				"rds:ModifyDBSubnetGroup",
				"rds:DeleteDBSubnetGroup",
				"rds:AddTagsToResource",
				"rds:ListTagsForResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "ElastiCacheAccess",
			"Effect": "Allow",
			"Action": [
				"elasticache:Describe*",
				"elasticache:CreateCacheCluster",
				"elasticache:ModifyCacheCluster",
				"elasticache:DeleteCacheCluster",
				"elasticache:CreateCacheSubnetGroup",
				"elasticache:ModifyCacheSubnetGroup",
				"elasticache:DeleteCacheSubnetGroup",
				"elasticache:AddTagsToResource",
				"elasticache:ListTagsForResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "IAMAccessForTenantResources",
			"Effect": "Allow",
			"Action": [
				"iam:GetRole",
				"iam:CreateRole",
				"iam:DeleteRole",
				"iam:UpdateRole",
				"iam:AttachRolePolicy",
				"iam:DetachRolePolicy",
				"iam:PutRolePolicy",
				"iam:DeleteRolePolicy",
				"iam:GetPolicy",
				"iam:CreatePolicy",
				"iam:DeletePolicy",
				"iam:GetPolicyVersion",
				"iam:CreatePolicyVersion",
				"iam:DeletePolicyVersion",
				"iam:GetInstanceProfile",
				"iam:CreateInstanceProfile",
				"iam:DeleteInstanceProfile",
				"iam:AddRoleToInstanceProfile",
				"iam:RemoveRoleFromInstanceProfile",
				"iam:TagRole",
				"iam:TagPolicy",
				"iam:ListRolePolicies",
				"iam:ListAttachedRolePolicies",
				"iam:ListInstanceProfilesForRole",
				"iam:TagInstanceProfile",
				"iam:PassRole",
				"iam:CreateServiceLinkedRole"
			],
			"Resource": "*"
		},
		{
			"Sid": "GeneralIAMList",
			"Effect": "Allow",
			"Action": [
				"iam:ListRoles",
				"iam:ListPolicies"
			],
			"Resource": "*"
		},
		{
			"Sid": "S3ProvisioningAccess",
			"Effect": "Allow",
			"Action": [
				"s3:CreateBucket",
				"s3:DeleteBucket",
				"s3:GetBucketLocation",
				"s3:GetBucketPolicy",
				"s3:PutBucketPolicy",
				"s3:DeleteBucketPolicy",
				"s3:GetEncryptionConfiguration",
				"s3:PutEncryptionConfiguration",
				"s3:GetBucketVersioning",
				"s3:PutBucketVersioning",
				"s3:GetLifecycleConfiguration",
				"s3:PutLifecycleConfiguration",
				"s3:PutBucketPublicAccessBlock",
				"s3:GetBucketPublicAccessBlock",
				"s3:PutBucketTagging",
				"s3:GetBucketTagging"
			],
			"Resource": "*"
		},
		{
			"Sid": "CloudWatchAccess",
			"Effect": "Allow",
			"Action": [
				"cloudwatch:PutMetricAlarm",
				"cloudwatch:DeleteAlarms",
				"cloudwatch:DescribeAlarms",
				"cloudwatch:ListTagsForResource",
				"cloudwatch:TagResource",
				"cloudwatch:UntagResource"
			],
			"Resource": "*"
		},
		{
			"Sid": "SecretsManagerAccess",
			"Effect": "Allow",
			"Action": [
				"secretsmanager:CreateSecret",
				"secretsmanager:UpdateSecret",
				"secretsmanager:PutSecretValue",
				"secretsmanager:DescribeSecret",
				"secretsmanager:DeleteSecret",
				"secretsmanager:TagResource",
				"secretsmanager:UntagResource",
				"secretsmanager:GetSecretValue",
				"secretsmanager:GetResourcePolicy",
				"secretsmanager:PutResourcePolicy",
				"secretsmanager:DeleteResourcePolicy"
			],
			"Resource": "arn:aws:secretsmanager:us-east-1:492646066724:secret:idp/*"
		}
	]
}
```

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

This repository can create IAM, RDS, Redis, EC2, S3, CloudWatch, AWS Secrets Manager, and supporting networking/security resources. In practice, `GitHubActionsRole` needs permission to manage:

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
- `secretsmanager`
  - secrets
  - secret versions
  - tags
- `kms`
  - only if you choose to supply customer-managed KMS keys in the environment tfvars

At minimum, the Secrets Manager side should include actions such as:

- `secretsmanager:CreateSecret`
- `secretsmanager:UpdateSecret`
- `secretsmanager:PutSecretValue`
- `secretsmanager:DescribeSecret`
- `secretsmanager:TagResource`
- `secretsmanager:GetSecretValue` if people or automation will read the secret with the same role

The easiest demo approach is:

1. Start from a tightly scoped custom policy that covers the above services and the target account/region.
2. Validate with pull request `plan`.
3. Add only the missing actions surfaced by Terraform errors.

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

## 7. Prepare AWS Secrets Manager

AWS Secrets Manager is the platform handoff for outputs and generated credentials.

Terraform writes one secret per tenant request using this naming pattern:

- `idp/<environment>/<tenant_name>`

The secret JSON contains fields such as:

- `rds_endpoint`
- `rds_username`
- `rds_password`
- `s3_bucket_name`
- `redis_endpoint`
- `ec2_private_ips`
- `enabled_modules`
- `provisioned_at`
- `environment`
- `tenant`

Preparation steps:

1. Decide whether you want the default AWS-managed key or a customer-managed KMS key.
2. If you want a customer-managed key, create it and allow the GitHub Actions role to use it.
3. Add `secrets_manager_kms_key_id` to each environment `.tfvars` file if you use that key.
4. Grant the GitHub Actions role Secrets Manager permissions.
5. Decide which humans or downstream apps are allowed to read `idp/<environment>/<tenant_name>` after provisioning.

Example IAM policy fragment for the GitHub Actions role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:UpdateSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:TagResource"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:idp/*"
    }
  ]
}
```

If you use a customer-managed KMS key, also grant the role the KMS permissions needed for encrypt and decrypt operations.

## 8. Create the Gmail app password step by step

The project sends mail through Gmail SMTP over port `465`.

Create it in this order:

1. Sign in to the Gmail account you want to use.
2. Open your Google Account settings.
3. Go to `Security`.
4. Enable `2-Step Verification` if it is not already enabled.
5. Return to `Security`.
6. Open `App passwords`.
7. Create a password for Mail.
8. Save the generated 16-character password.

You need these values:

- `GMAIL_SENDER_EMAIL = platform.team.demo@gmail.com`
- `GMAIL_APP_PASSWORD = <16-character app password>`

## 9. Create the environment tfvars files

Each file under `files/environments/` should contain non-secret, environment-specific values.

Typical fields:

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

## 10. Add GitHub repository secrets

Create these repository secrets in GitHub:

- `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `GMAIL_SENDER_EMAIL`
- `GMAIL_APP_PASSWORD`

Only the GitHub secrets listed above are required for the workflow configuration.

## 11. Create GitHub Environments

Create these environments:

- `idp-nonprod`
- `idp-production`

Recommended protections:

- required reviewers for `idp-production`
- optional required reviewers for `idp-nonprod`
- deployment branch restrictions if you want tighter control

The workflow maps:

- `production` -> `idp-production`
- `dev`, `test`, `qa`, `staging` -> `idp-nonprod`

## 12. Test with a sample request

Update `files/infra-management/infra.yaml` with a safe non-production request and open a pull request.

Expected PR behavior:

1. `load-config` reads `tenant_name` and `environment`.
2. `validate-request` runs `policy-check.sh`.
3. `terraform-plan` runs `fmt`, `init`, `validate`, and `plan`.
4. The plan artifact and PR comment are generated.

Expected merge behavior:

1. Merge the PR to `main`.
2. Approve the GitHub Environment deployment if required.
3. `terraform-apply` provisions the requested resources.
4. Terraform writes the resulting connection details into AWS Secrets Manager.
5. Gmail sends the provisioning summary.

## 13. Verify the outputs after apply

After a successful apply, verify:

1. the AWS resources exist
2. the Terraform state object exists in S3
3. the DynamoDB lock is released
4. the AWS Secrets Manager secret `idp/<environment>/<tenant_name>` exists
5. the secret JSON contains the expected endpoints and generated credentials
6. the email arrived at the target `team_email`

Example CLI check:

```bash
aws secretsmanager get-secret-value \
  --secret-id idp/staging/acme-corp \
  --query SecretString \
  --output text
```

## 14. Local demo variables if you still want them

The intended demo path is GitHub Actions, but `files/terraform.tfvars` now only needs local values for:

- `aws_region`
- optional `secrets_manager_kms_key_id`
- `gmail_sender_email`
- `gmail_app_password`

AWS credentials for local testing would come from your normal AWS CLI or environment configuration.

## 15. Make sure the GitHub runner can reach AWS and Gmail

For a GitHub-hosted runner, the important checks are:

1. the runner can assume `GitHubActionsRole`
2. the AWS role can access S3, DynamoDB, Terraform-managed services, and Secrets Manager
3. the runner can reach `smtp.gmail.com:465`
4. Gmail credentials are valid

If you use self-hosted runners, also verify:

- outbound network access to AWS APIs and Gmail SMTP
- proxy rules do not block AWS or Gmail
- the runner clock is correct for OIDC and TLS

## 16. End-to-end flow summary

1. A developer updates `files/infra-management/infra.yaml`.
2. A PR triggers validation and Terraform plan.
3. Reviewers inspect the YAML and plan.
4. The PR is merged to `main`.
5. GitHub Environment approval gates the deployment.
6. Terraform applies the infrastructure.
7. AWS Secrets Manager becomes the secret/output handoff layer.
8. Gmail sends the summary to the requesting team.

## 17. Troubleshooting checklist

1. Confirm the workflow file uses GitHub Secrets for Gmail.
2. Confirm the AWS role trust policy allows your repository and event pattern.
3. Confirm the role can access the S3 backend bucket and DynamoDB table.
4. Confirm the role can create and update Secrets Manager secrets under `idp/*`.
5. Confirm any KMS key policy allows the role to use the configured key.
6. Confirm `files/environments/<env>.tfvars` contains valid VPC and subnet IDs.
7. Confirm `policy-check.sh` passes for the request.
8. Confirm Gmail app password setup is complete.
9. Verify `terraform-plan`, `terraform-apply`, Secrets Manager write, and Gmail notification succeed.

## 18. Final checklist

Before the demo, make sure you have:

- GitHub repository, Actions, and Environments ready
- AWS OIDC provider and `GitHubActionsRole`
- S3 backend bucket and DynamoDB lock table
- VPC and at least two private subnets
- Secrets Manager permissions and optional KMS key setup
- Gmail sender account and app password
- environment `.tfvars` files populated
- repository secrets configured
- a test `infra.yaml` request ready
