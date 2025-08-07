# Cloudflare DNS and SSL Configuration
# This file manages DNS records and SSL settings for the K3s cluster

# Variables
variable "cloudflare_api_token" {
  description = "Cloudflare API token or Global API Key"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for travelspirit.cloud"
  type        = string
  default     = "813e1cee01722c062f8371ac8fa462d3"
}

# Data source to get the load balancer created by the module
data "hcloud_load_balancers" "cluster" {
  with_selector = "cluster=${module.kube-hetzner.cluster_name}"
}

# DNS Records
resource "cloudflare_record" "k8s" {
  zone_id         = var.cloudflare_zone_id
  name            = "k8s"
  content         = data.hcloud_load_balancers.cluster.load_balancers[0].ipv4
  type            = "A"
  ttl             = 1
  proxied         = true # Enable Cloudflare proxy for SSL
  allow_overwrite = true # Allow updating existing record
}

resource "cloudflare_record" "k8s_ipv6" {
  zone_id         = var.cloudflare_zone_id
  name            = "k8s"
  content         = data.hcloud_load_balancers.cluster.load_balancers[0].ipv6
  type            = "AAAA"
  ttl             = 1
  proxied         = true # Enable Cloudflare proxy for SSL
  allow_overwrite = true
}

# Wildcard for all services under k8s subdomain
resource "cloudflare_record" "k8s_wildcard" {
  zone_id         = var.cloudflare_zone_id
  name            = "*.k8s"
  content         = data.hcloud_load_balancers.cluster.load_balancers[0].ipv4
  type            = "A"
  ttl             = 1
  proxied         = true
  allow_overwrite = true
}

# Note: Zone settings and page rules require additional permissions
# For now, we'll just manage DNS records. SSL is automatic with Cloudflare proxy.

# Output the DNS records
output "k8s_domain" {
  value = "https://k8s.travelspirit.cloud"
}

output "k8s_dns_records" {
  value = {
    domain     = cloudflare_record.k8s.hostname
    ipv4       = cloudflare_record.k8s.content
    ipv6       = cloudflare_record.k8s_ipv6.content
    proxied    = cloudflare_record.k8s.proxied
    ssl_mode   = "flexible"
  }
  depends_on = [cloudflare_record.k8s, cloudflare_record.k8s_ipv6]
}