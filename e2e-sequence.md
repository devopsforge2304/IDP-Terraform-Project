flowchart LR

DevRequest --> PR
PR --> PlatformReview
PlatformReview --> ApprovalGate
ApprovalGate --> MergeMain
MergeMain --> PipelineTrigger
PipelineTrigger --> TerraformPlan
TerraformPlan --> PolicyCheck
PolicyCheck --> TerraformApply
TerraformApply --> ResourceProvisioned
ResourceProvisioned --> StateRecorded
StateRecorded --> MonitoringAttached