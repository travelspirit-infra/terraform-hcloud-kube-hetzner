# Cloudflare DNS Configuration
# Manages DNS records for k8s cluster endpoints

# Cloudflare Zone Configuration
locals {
  # Both domains appear to be in the same Cloudflare zone based on current setup
  cloudflare_zones = {
    travelspirit_cloud = {
      zone_id    = "813e1cee01722c062f8371ac8fa462d3"
      account_id = "5dee9a2cfa0d73e9c0e1a4a78c44f2fd"
      domain     = "travelspirit.cloud"
    }
    # visualtourbuilder.com has its own separate zone
    visualtourbuilder_com = {
      zone_id    = "ba732f360e9522aa3348eafef1e5feb2"  # Correct zone for visualtourbuilder.com
      account_id = "5dee9a2cfa0d73e9c0e1a4a78c44f2fd"
      domain     = "visualtourbuilder.com"
    }
  }
}

# Cloudflare Provider configuration in providers.tf

# Variables (optional - provider uses env var directly)
variable "cloudflare_api_token" {
  description = "Cloudflare API token (uses CLOUDFLARE_API_TOKEN env var if not set)"
  type        = string
  sensitive   = true
  default     = ""
}

# DNS Records for travelspirit.cloud
resource "cloudflare_record" "k8s_travelspirit" {
  zone_id         = local.cloudflare_zones.travelspirit_cloud.zone_id
  name            = "k8s"
  content         = "167.235.110.121" # Current ingress LB IP from your infrastructure
  type            = "A"
  ttl             = 1
  proxied         = true # Enable Cloudflare proxy for SSL
  allow_overwrite = true
  comment         = "K8s ingress load balancer"
}

resource "cloudflare_record" "k8s_ipv6_travelspirit" {
  zone_id         = local.cloudflare_zones.travelspirit_cloud.zone_id
  name            = "k8s"
  content         = "2a01:4f8:1c1f:7a40::1" # Current ingress LB IPv6 from your infrastructure
  type            = "AAAA"
  ttl             = 1
  proxied         = true
  allow_overwrite = true
  comment         = "K8s ingress load balancer IPv6"
}

# Wildcard for all services under k8s subdomain
resource "cloudflare_record" "k8s_wildcard_travelspirit" {
  zone_id         = local.cloudflare_zones.travelspirit_cloud.zone_id
  name            = "*.k8s"
  content         = "167.235.110.121"
  type            = "A"
  ttl             = 1
  proxied         = true
  allow_overwrite = true
  comment         = "Wildcard for k8s services"
}

# VTB test API subdomain (preserving existing api.visualtourbuilder.com → AWS ECS)
resource "cloudflare_record" "tst_api_vtb" {
  zone_id         = local.cloudflare_zones.visualtourbuilder_com.zone_id
  name            = "tst.api"
  content         = "167.235.110.121"
  type            = "A"
  ttl             = 1
  proxied         = false  # Direct connection to backend
  allow_overwrite = true
  comment         = "VTB test API environment"
}

# Output just the expected domain
output "k8s_domain" {
  value       = "https://k8s.travelspirit.cloud"
  description = "K8s cluster domain (DNS managed externally)"
}