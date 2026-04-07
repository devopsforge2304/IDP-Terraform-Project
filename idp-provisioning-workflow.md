flowchart TD

A[Developer identifies infrastructure requirement\n(RDS / Redis / EC2 / S3)] 
--> B[Create YAML request configuration]

B --> C[Commit config to infra-management repository\n(dev / test / stage / prod)]

C --> D[Raise Pull Request]

D --> E[Platform Engineering Review]

E --> F{Validation Checks}

F --> F1[Tagging compliance]
F --> F2[IAM permission boundary validation]
F --> F3[Subnet placement verification]
F --> F4[Encryption enforcement]
F --> F5[Cost impact evaluation]
F --> F6[Monitoring & backup requirements]

F --> G[Engineering Lead / Manager Approval]

G --> H[Merge PR into main branch]

H --> I[CI/CD Pipeline Triggered]

I --> J[Terraform fmt + validate]

J --> K[Policy as Code checks\n(Sentinel / OPA)]

K --> L[Terraform plan]

L --> M[Manual or automated approval gate]

M --> N[Terraform apply executed]

N --> O[Resource provisioned using standard modules]

O --> P[State stored in remote backend\n(S3 + DynamoDB locking / Terraform Cloud)]

P --> Q[Monitoring + Logging attached automatically]