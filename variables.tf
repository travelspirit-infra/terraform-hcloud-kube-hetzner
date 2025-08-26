# Hetzner Cloud Variables
variable "hcloud_token" {
  description = "Hetzner Cloud API Token (defaults to HCLOUD_TOKEN env var)"
  type        = string
  sensitive   = true
  default     = ""
}

# GitHub Actions Runner Controller Variables
variable "github_token" {
  description = "GitHub Personal Access Token for Actions Runner Controller"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_organization" {
  description = "GitHub organization for runners (e.g., travelspirit-infra)"
  type        = string
  default     = "travelspirit-infra"
}

variable "arc_runner_replicas" {
  description = "Number of GitHub Actions runners to deploy"
  type        = number
  default     = 2
}