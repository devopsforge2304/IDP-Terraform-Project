# ============================================================
# DEMO SETUP GUIDE — Run Everything Locally for Your Video
# Estimated setup time: 15 minutes
# Estimated AWS cost for a 1-hour demo: ~$0.05
# ============================================================


## PART 1 — HashiCorp Vault (Local, Free, No Sign-Up)
# ─────────────────────────────────────────────────────────

# Step 1: Install Vault CLI
# On Mac:
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# On Ubuntu/Debian:
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Step 2: Start Vault in DEV mode (one terminal — keep it open)
vault server -dev

# Vault will print something like:
#   Root Token: hvs.XXXXXXXXXXXXXXXX
#   Unseal Key: XXXXXXXXXXXXXXXX
#   API addr: http://127.0.0.1:8200

# Step 3: In a NEW terminal — set environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='hvs.XXXXXXXXXXXXXXXX'   # ← paste your root token here

# Step 4: Verify Vault is running
vault status
# Should show: Initialized=true  Sealed=false

# Step 5: Enable KV secrets engine (Vault dev mode already does this,
#          but run this just to be safe)
vault secrets enable -path=secret kv-v2

# Step 6: Open the Vault UI in your browser
# URL: http://localhost:8200/ui
# Login method: Token
# Token: paste your root token
# → You will see the secrets engine UI — looks great on camera!


## PART 2 — Slack Workspace + Bot (Free, ~10 minutes)
# ─────────────────────────────────────────────────────────

# Step 1: Create a free Slack workspace
# → Go to https://slack.com/get-started
# → Create a new workspace (e.g. "terraform-demo")
# → Use your personal email — no credit card needed

# Step 2: Create a Slack App (bot)
# → Go to https://api.slack.com/apps
# → Click "Create New App" → "From scratch"
# → App Name: "Terraform IDP Bot"
# → Workspace: select your new workspace

# Step 3: Give the bot permission to post messages
# → In your app settings, click "OAuth & Permissions"
# → Scroll to "Scopes" → "Bot Token Scopes"
# → Add these scopes:
#     chat:write
#     chat:write.public

# Step 4: Install the app to your workspace
# → Click "Install to Workspace" → Allow
# → Copy the "Bot User OAuth Token" (starts with xoxb-)
#   This is your SLACK_BOT_TOKEN

# Step 5: Get your channel ID
# → Open Slack in browser (not the desktop app)
# → Go to your channel (e.g. #general)
# → The URL looks like: https://app.slack.com/client/TXXXXXXXX/CXXXXXXXXX
# → The last part (CXXXXXXXXX) is your SLACK_CHANNEL_ID

# Step 6: Invite the bot to your channel
# → In Slack, type: /invite @Terraform IDP Bot


## PART 3 — AWS Setup (Minimal, ~5 minutes)
# ─────────────────────────────────────────────────────────

# You need:
# 1. An AWS account with an existing VPC + subnets (or create one below)
# 2. AWS CLI configured locally

# Configure AWS CLI (if not done already):
aws configure
# Enter: Access Key ID, Secret Access Key, region (ap-south-1), output (json)

# If you don't have a VPC, create a simple one for the demo:
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region ap-south-1 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=idp-demo-vpc}]'
# Note the VPC ID from the output (vpc-XXXXXXXXX)

# Create two subnets (needed for RDS subnet group):
aws ec2 create-subnet \
  --vpc-id vpc-XXXXXXXXX \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=idp-demo-subnet-1}]'

aws ec2 create-subnet \
  --vpc-id vpc-XXXXXXXXX \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=idp-demo-subnet-2}]'
# Note both subnet IDs


## PART 4 — Configure Terraform Variables
# ─────────────────────────────────────────────────────────

# Create terraform.tfvars (DO NOT commit this file — it's in .gitignore)
cat > terraform.tfvars << 'EOF'
aws_region         = "ap-south-1"
vpc_id             = "vpc-XXXXXXXXX"           # ← your VPC ID
private_subnet_ids = ["subnet-AAAA", "subnet-BBBB"]  # ← your subnet IDs
vault_address      = "http://127.0.0.1:8200"
vault_token        = "hvs.XXXXXXXXXXXXXXXX"    # ← your Vault root token
slack_bot_token    = "xoxb-XXXXXXXXXX"         # ← your Slack bot token
slack_channel_id   = "CXXXXXXXXX"              # ← your Slack channel ID
EOF


## PART 5 — Run Terraform
# ─────────────────────────────────────────────────────────

# Initialize
terraform init

# Preview what will be created (great to show on camera!)
terraform plan

# Apply — this creates everything
terraform apply
# Type: yes
# Wait ~5-8 minutes for RDS to spin up

# After apply completes, check Slack — your notification should arrive!


## PART 6 — Retrieve Secrets from Vault CLI (Show on Camera!)
# ─────────────────────────────────────────────────────────

# Make sure these are set in your terminal:
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='hvs.XXXXXXXXXXXXXXXX'

# The money shot — one command to see all credentials:
vault kv get secret/idp/staging/acme-corp

# Output will look like:
# ======= Secret Path =======
# secret/data/idp/staging/acme-corp
#
# ======= Metadata =======
# version    1
# created    2026-04-07T10:30:00Z
#
# ========== Data ==========
# rds_endpoint     = acme-corp-staging.xyz.rds.amazonaws.com:5432
# rds_username     = admin_acme_corp
# rds_password     = Xk9mP2qR7vL3nWsY
# s3_bucket_name   = acme-corp-staging-123456789012
# redis_endpoint   = acme-corp-staging.abc.cache.amazonaws.com
# environment      = staging
# tenant           = acme-corp

# To get just one value (e.g. password):
vault kv get -field=rds_password secret/idp/staging/acme-corp

# To see it in JSON format (good for apps to consume):
vault kv get -format=json secret/idp/staging/acme-corp


## PART 7 — View Secrets in Vault UI (Show on Camera!)
# ─────────────────────────────────────────────────────────

# 1. Open http://localhost:8200/ui in your browser
# 2. Login with Token → paste your root token → Sign In
# 3. Click "secret" engine → "idp" → "staging" → "acme-corp"
# 4. You'll see all the key-value pairs with a "Copy" button
# 5. Click "Secret" tab to see the actual values
# 6. Click "Metadata" to show version history (looks impressive!)


## PART 8 — DESTROY EVERYTHING (Run this after recording!)
# ─────────────────────────────────────────────────────────

# This deletes ALL AWS resources Terraform created:
terraform destroy
# Type: yes
# Wait ~5 minutes

# Verify nothing is left (RDS takes longest to delete):
aws rds describe-db-instances --region ap-south-1
# Should return empty list

# Stop Vault (Ctrl+C in the terminal running vault server -dev)
# All Vault data is gone since dev mode is in-memory only

# Optionally delete the demo VPC (if you created one):
aws ec2 delete-subnet --subnet-id subnet-AAAA
aws ec2 delete-subnet --subnet-id subnet-BBBB
aws ec2 delete-vpc --vpc-id vpc-XXXXXXXXX

# Total AWS cost for ~1 hour demo: approximately $0.02 - $0.10
# RDS t3.micro = $0.017/hour
# ElastiCache t3.micro = $0.016/hour
# S3 = negligible for a demo


## QUICK REFERENCE — What Each Step Shows on Camera
# ─────────────────────────────────────────────────────────

# 1. Show infra.yaml        → "This 12-line file is all a developer writes"
# 2. terraform plan         → "Watch it detect RDS, Redis, S3 from the YAML"
# 3. terraform apply        → "One command, everything provisions itself"
# 4. Vault UI               → "Secrets are here — not in Slack, not in email"
# 5. vault kv get ...       → "Developer retrieves their DB password like this"
# 6. Slack message          → "Team gets notified automatically — no ticket"
# 7. terraform destroy      → "Clean teardown — nothing left, no surprise bill"
