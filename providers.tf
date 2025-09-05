terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.43.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.9"
    }
  }
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  # If var.hcloud_token is empty, provider will use HCLOUD_TOKEN env var automatically
  token = var.hcloud_token != "" ? var.hcloud_token : null
}

# Configure the Cloudflare Provider
provider "cloudflare" {
  # Will automatically use CLOUDFLARE_API_TOKEN environment variable
}