flowchart LR

A[YAML Request Input]
--> B[Environment tfvars loaded]

B --> C[Terraform Root Module]

C --> D[RDS Module]
C --> E[Redis Module]
C --> F[EC2 Module]
C --> G[S3 Module]

D --> H[Attach IAM Role]
E --> H
F --> H
G --> H

H --> I[Apply Security Groups]

I --> J[Select Private Subnets]

J --> K[Enable Encryption]

K --> L[Attach Monitoring + Alerts]

L --> M[Apply Mandatory Tags]

M --> N[Provision Resource]