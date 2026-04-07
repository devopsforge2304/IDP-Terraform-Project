flowchart TD

A[Terraform Execution Request]
--> B[Permission Boundary Check]

B --> C[IAM Role Validation]

C --> D[Secrets Retrieval\n(HashiCorp Vault / AWS Secrets Manager)]

D --> E[Remote State Locking]

E --> F[Drift Detection]

F --> G[Policy Compliance Engine]

G --> H{Compliant?}

H -->|Yes| I[Apply Infrastructure]

H -->|No| J[Pipeline Blocked]