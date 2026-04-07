flowchart TD

A[infra-management repo]

A --> B[dev]
A --> C[test]
A --> D[qa]
A --> E[staging]
A --> F[production]

B --> G[dev.tfvars]
C --> H[test.tfvars]
D --> I[qa.tfvars]
E --> J[staging.tfvars]
F --> K[prod.tfvars]