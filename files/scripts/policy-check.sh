#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-infra.yaml}"

tenant_name="$(yq -r '.tenant_name' "$CONFIG_FILE")"
environment="$(yq -r '.environment' "$CONFIG_FILE")"
team_email="$(yq -r '.team_email' "$CONFIG_FILE")"

if [[ -z "$tenant_name" || "$tenant_name" == "null" ]]; then
  echo "tenant_name is required"
  exit 1
fi

if [[ ! "$tenant_name" =~ ^[a-z0-9-]+$ ]]; then
  echo "tenant_name must be lowercase and hyphenated only"
  exit 1
fi

case "$environment" in
  dev|test|qa|staging|production) ;;
  *)
    echo "environment must be dev, test, qa, staging, or production"
    exit 1
    ;;
esac

if [[ -z "$team_email" || "$team_email" == "null" ]]; then
  echo "team_email is required"
  exit 1
fi

rds_enabled="$(yq -r '.resources.rds.enabled // false' "$CONFIG_FILE")"
rds_class="$(yq -r '.resources.rds.instance_class // "db.t3.micro"' "$CONFIG_FILE")"
rds_multi_az="$(yq -r '.resources.rds.multi_az // false' "$CONFIG_FILE")"

if [[ "$rds_enabled" == "true" ]]; then
  case "$rds_class" in
    db.t3.micro|db.t3.small|db.r5.large) ;;
    *)
      echo "Unsupported RDS instance_class: $rds_class"
      exit 1
      ;;
  esac

  if [[ "$environment" == "production" && "$rds_multi_az" != "true" ]]; then
    echo "Production RDS requires multi_az=true"
    exit 1
  fi
fi

redis_enabled="$(yq -r '.resources.redis.enabled // false' "$CONFIG_FILE")"
redis_type="$(yq -r '.resources.redis.node_type // "cache.t3.micro"' "$CONFIG_FILE")"

if [[ "$redis_enabled" == "true" ]]; then
  case "$redis_type" in
    cache.t3.micro|cache.t3.small) ;;
    *)
      echo "Unsupported Redis node_type: $redis_type"
      exit 1
      ;;
  esac
fi

ec2_enabled="$(yq -r '.resources.ec2.enabled // false' "$CONFIG_FILE")"
ec2_type="$(yq -r '.resources.ec2.instance_type // "t3.micro"' "$CONFIG_FILE")"
ec2_backup="$(yq -r '.resources.ec2.backup_enabled // true' "$CONFIG_FILE")"

if [[ "$ec2_enabled" == "true" ]]; then
  case "$ec2_type" in
    t3.micro|t3.small|m6i.large) ;;
    *)
      echo "Unsupported EC2 instance_type: $ec2_type"
      exit 1
      ;;
  esac

  if [[ "$environment" == "production" && "$ec2_backup" != "true" ]]; then
    echo "Production EC2 requires backup_enabled=true"
    exit 1
  fi
fi

echo "Policy checks passed for tenant=$tenant_name env=$environment"
