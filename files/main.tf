# ============================================================
# Internal Developer Platform — Root Module
# Reads infra-management/infra.yaml and provisions AWS resources per tenant
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "idp/tenants/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.mandatory_tags
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

locals {
  config      = yamldecode(file("${path.module}/infra-management/infra.yaml"))
  tenant_name = trimspace(local.config.tenant_name)
  env         = trimspace(local.config.environment)

  resource_requests = try(local.config.resources, {})

  rds_config   = try(local.resource_requests.rds, {})
  redis_config = try(local.resource_requests.redis, {})
  ec2_config   = try(local.resource_requests.ec2, {})
  s3_config    = try(local.resource_requests.s3, {})

  enabled_resources = compact([
    try(local.rds_config.enabled, false) ? "rds" : "",
    try(local.redis_config.enabled, false) ? "redis" : "",
    try(local.ec2_config.enabled, false) ? "ec2" : "",
    try(local.s3_config.enabled, false) ? "s3" : "",
  ])

  monthly_cost_estimate = sum([
    lookup(var.rds_cost_map, try(local.rds_config.instance_class, "db.t3.micro"), 0),
    lookup(var.redis_cost_map, try(local.redis_config.node_type, "cache.t3.micro"), 0) * try(local.redis_config.num_nodes, 1),
    lookup(var.ec2_cost_map, try(local.ec2_config.instance_type, "t3.micro"), 0) * try(local.ec2_config.instance_count, 1),
    try(local.s3_config.enabled, false) ? var.s3_base_monthly_cost : 0,
  ])

  mandatory_tags = merge(var.global_tags, {
    ManagedBy       = "Terraform-IDP"
    Environment     = local.env
    Tenant          = local.tenant_name
    TeamEmail       = trimspace(try(local.config.team_email, ""))
    DataSensitivity = try(local.config.data_sensitivity, "internal")
    Monitoring      = "enabled"
    BackupRequired  = contains(local.enabled_resources, "rds") || contains(local.enabled_resources, "ec2") ? "true" : "false"
  })

  default_rds_backup_retention = local.env == "production" ? max(var.default_rds_backup_retention_days, 14) : var.default_rds_backup_retention_days
}

resource "terraform_data" "workflow_validation" {
  input = local.config

  lifecycle {
    precondition {
      condition     = contains(var.allowed_environments, local.env)
      error_message = "environment must be one of: ${join(", ", var.allowed_environments)}."
    }

    precondition {
      condition     = length(local.tenant_name) > 0 && can(regex("^[a-z0-9-]+$", local.tenant_name))
      error_message = "tenant_name must be lowercase and may contain only letters, numbers, and hyphens."
    }

    precondition {
      condition     = trimspace(try(local.config.team_email, "")) != ""
      error_message = "team_email is required for approval, cost, and monitoring workflows."
    }

    precondition {
      condition     = length(local.enabled_resources) > 0
      error_message = "At least one resource must be enabled in infra-management/infra.yaml."
    }

    precondition {
      condition = (
        !try(local.rds_config.enabled, false) ||
        contains(var.allowed_rds_instance_classes, try(local.rds_config.instance_class, "db.t3.micro"))
      )
      error_message = "Unsupported RDS instance_class requested."
    }

    precondition {
      condition = (
        !try(local.redis_config.enabled, false) ||
        contains(var.allowed_redis_node_types, try(local.redis_config.node_type, "cache.t3.micro"))
      )
      error_message = "Unsupported Redis node_type requested."
    }

    precondition {
      condition = (
        !try(local.ec2_config.enabled, false) ||
        contains(var.allowed_ec2_instance_types, try(local.ec2_config.instance_type, "t3.micro"))
      )
      error_message = "Unsupported EC2 instance_type requested."
    }

    precondition {
      condition = (
        !try(local.rds_config.enabled, false) ||
        local.env != "production" ||
        try(local.rds_config.multi_az, false)
      )
      error_message = "Production RDS requests must enable multi_az."
    }

    precondition {
      condition = (
        !try(local.ec2_config.enabled, false) ||
        local.env != "production" ||
        try(local.ec2_config.backup_enabled, true)
      )
      error_message = "Production EC2 requests must keep backup_enabled set to true."
    }

    precondition {
      condition     = length(var.private_subnet_ids) >= 2
      error_message = "At least two private subnet IDs are required for compliant placement."
    }
  }
}

module "iam" {
  source = "./modules/iam"

  tenant_name  = local.tenant_name
  environment  = local.env
  enable_rds   = try(local.rds_config.enabled, false)
  enable_s3    = try(local.s3_config.enabled, false)
  enable_redis = try(local.redis_config.enabled, false)
  enable_ec2   = try(local.ec2_config.enabled, false)
  tags         = local.mandatory_tags
  depends_on   = [terraform_data.workflow_validation]
}

module "rds" {
  count  = try(local.rds_config.enabled, false) ? 1 : 0
  source = "./modules/rds"

  tenant_name      = local.tenant_name
  environment      = local.env
  instance_class   = try(local.rds_config.instance_class, "db.t3.micro")
  db_name          = try(local.rds_config.db_name, replace(local.tenant_name, "-", ""))
  subnet_ids       = var.private_subnet_ids
  vpc_id           = var.vpc_id
  backup_retention = try(local.rds_config.backup_retention_days, local.default_rds_backup_retention)
  multi_az         = try(local.rds_config.multi_az, local.env == "production")
  monitor_actions  = var.monitor_alarm_actions
  kms_key_id       = var.rds_kms_key_id
  tags             = local.mandatory_tags
  depends_on       = [module.iam]
}

module "redis" {
  count  = try(local.redis_config.enabled, false) ? 1 : 0
  source = "./modules/redis"

  tenant_name     = local.tenant_name
  environment     = local.env
  node_type       = try(local.redis_config.node_type, "cache.t3.micro")
  num_cache_nodes = try(local.redis_config.num_nodes, 1)
  subnet_ids      = var.private_subnet_ids
  vpc_id          = var.vpc_id
  monitor_actions = var.monitor_alarm_actions
  tags            = local.mandatory_tags
  depends_on      = [module.iam]
}

module "ec2" {
  count  = try(local.ec2_config.enabled, false) ? 1 : 0
  source = "./modules/ec2"

  tenant_name               = local.tenant_name
  environment               = local.env
  instance_type             = try(local.ec2_config.instance_type, "t3.micro")
  instance_count            = try(local.ec2_config.instance_count, 1)
  ami_id                    = try(local.ec2_config.ami_id, var.default_ec2_ami_id)
  subnet_id                 = try(var.private_subnet_ids[0], null)
  vpc_id                    = var.vpc_id
  iam_instance_profile_name = module.iam.instance_profile_name
  backup_enabled            = try(local.ec2_config.backup_enabled, true)
  monitor_actions           = var.monitor_alarm_actions
  kms_key_id                = var.ec2_kms_key_id
  tags                      = local.mandatory_tags
  depends_on                = [module.iam]
}

module "s3" {
  count  = try(local.s3_config.enabled, false) ? 1 : 0
  source = "./modules/s3"

  tenant_name    = local.tenant_name
  environment    = local.env
  versioning     = try(local.s3_config.versioning, true)
  lifecycle_days = try(local.s3_config.lifecycle_days, null)
  iam_role_arn   = module.iam.role_arn
  kms_key_id     = var.s3_kms_key_id
  tags           = local.mandatory_tags
  depends_on     = [module.iam]
}

module "vault_inject" {
  source = "./modules/vault-inject"

  tenant_name     = local.tenant_name
  environment     = local.env
  rds_endpoint    = try(module.rds[0].endpoint, "")
  rds_username    = try(module.rds[0].username, "")
  rds_password    = try(module.rds[0].password, "")
  s3_bucket_name  = try(module.s3[0].bucket_name, "")
  redis_endpoint  = try(module.redis[0].endpoint, "")
  ec2_private_ips = try(module.ec2[0].private_ips, [])
  enabled_modules = local.enabled_resources

  depends_on = [module.rds, module.redis, module.ec2, module.s3]
}

module "gmail_notify" {
  source = "./modules/gmail-notify"

  tenant_name          = local.tenant_name
  environment          = local.env
  team_email           = trimspace(try(local.config.team_email, ""))
  gmail_sender_email   = var.gmail_sender_email
  gmail_app_password   = var.gmail_app_password
  enabled_resources    = local.enabled_resources
  rds_endpoint         = try(module.rds[0].endpoint, "N/A")
  s3_bucket_name       = try(module.s3[0].bucket_name, "N/A")
  redis_endpoint       = try(module.redis[0].endpoint, "N/A")
  ec2_private_ips      = try(module.ec2[0].private_ips, [])
  vault_path           = module.vault_inject.vault_path
  estimated_cost_value = local.monthly_cost_estimate

  depends_on = [module.vault_inject]
}
