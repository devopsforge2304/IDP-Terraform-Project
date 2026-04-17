cd "/Users/rahuloli/Downloads/Terraform Projects/IDP-Terraform-Project/files"

export TF_VAR_gmail_sender_email="rahul230420@gmail.com"
export TF_VAR_gmail_app_password="knkz suyw ztmn cbjw"

terraform init -input=false \
  -backend-config="bucket=internal-developers-platoform-terraform-state-bucket" \
  -backend-config="dynamodb_table=idp-terraform-lock-table" \
  -backend-config="region=us-east-1" \
  -backend-config="key=idp/dev/acme-corp.tfstate"

terraform destroy -input=false \
  -var-file="environments/dev.tfvars"
