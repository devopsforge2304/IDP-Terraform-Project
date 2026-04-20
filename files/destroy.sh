cd "/Terraform Projects/IDP-Terraform-Project/files"

export TF_VAR_gmail_sender_email="sender-email-id"
export TF_VAR_gmail_app_password="sender-app-password"

terraform init -input=false \
  -backend-config="bucket=your-bucket-name" \
  -backend-config="dynamodb_table=dynamodb-table-name" \
  -backend-config="region=us-east-1" \
  -backend-config="key=idp/dev/acme-corp.tfstate"

terraform destroy -input=false \
  -var-file="environments/dev.tfvars" \
  -lock=false
