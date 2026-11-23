variable "cluster_name" {
  description = "Name of the local kind cluster."
  type        = string
  default     = "platform-dev"
}

variable "environment" {
  description = "Which clusters/<env> folder Flux should reconcile."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "kubernetes_version" {
  description = "kindest/node image tag."
  type        = string
  default     = "v1.32.2"
}

variable "github_owner" {
  description = "GitHub user or org that owns this repository."
  type        = string
}

variable "github_repository" {
  description = "Repository name Flux will sync from."
  type        = string
  default     = "k8s-multitenant-platform"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "github_token" {
  description = "GitHub PAT with repo scope. Pass via TF_VAR_github_token, never commit it."
  type        = string
  sensitive   = true
}
