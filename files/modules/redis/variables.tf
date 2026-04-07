variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "node_type" { type = string }
variable "num_cache_nodes" { type = number }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "monitor_actions" { type = list(string) }
variable "tags" { type = map(string) }