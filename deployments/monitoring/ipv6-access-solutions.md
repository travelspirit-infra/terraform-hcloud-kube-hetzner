# Free IPv6 Access Solutions for K3s Cluster Management

## Option 1: Tailscale (Recommended)
**Free tier includes IPv6 support**
```bash
# Install Tailscale on your Mac
brew install --cask tailscale

# Install on one of the cluster nodes (via Hetzner console)
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --advertise-routes=2a01:4f8::/32

# This creates a secure tunnel with IPv6 support
```

## Option 2: Cloudflare WARP
**Free VPN with IPv6 support**
```bash
# Install Cloudflare WARP on Mac
brew install --cask cloudflare-warp

# Enable WARP mode (not just DNS)
# This provides IPv6 connectivity through Cloudflare's network
```

## Option 3: Hurricane Electric Free IPv6 Tunnel Broker
**Completely free IPv6 tunnels**
1. Sign up at https://tunnelbroker.net/
2. Create a tunnel with server location in Germany (Frankfurt)
3. Configure on your Mac:
```bash
# Example configuration (replace with your tunnel details)
sudo ifconfig gif0 create
sudo ifconfig gif0 tunnel <your-ipv4> <he-server-ipv4>
sudo ifconfig gif0 inet6 <your-ipv6-address> <he-ipv6-address> prefixlen 128
sudo route -n add -inet6 default <he-ipv6-address>
```

## Option 4: Use GitHub Codespaces
**Free 120 hours/month with IPv6 support**
```bash
# Create a codespace for this repo
# Codespaces have IPv6 connectivity by default
# Install kubectl in the codespace
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Copy kubeconfig and deploy
```

## Option 5: Free Cloud Shell with IPv6
**Google Cloud Shell (free, 5GB storage, 60 hours/week)**
```bash
# Access at https://shell.cloud.google.com
# Has IPv6 enabled by default
# Upload your kubeconfig and deployment files
```

## Option 6: Zerotier (Free for up to 25 nodes)
```bash
# Install on Mac
brew install --cask zerotier-one

# Install on control plane (via console)
curl -s https://install.zerotier.com | sudo bash

# Create network at https://my.zerotier.com
# Join both machines to the network
# Enable IPv6 auto-assign in network settings
```

## Option 7: WireGuard with IPv6 Tunnel
**Set up on a free VPS with IPv6 (Oracle Cloud, etc.)**
```bash
# Many providers offer free tier VPS with IPv6:
# - Oracle Cloud: Always Free tier includes IPv6
# - Google Cloud: Free trial with IPv6
# - AWS EC2: Free tier with IPv6

# Install WireGuard on the VPS and create IPv6 tunnel
```

## Quick Solution: Deploy via Terraform

Since you already have Terraform set up, add this to your configuration:

```hcl
# In a new file: deployments.tf
resource "kubernetes_manifest" "monitoring_namespace" {
  manifest = yamldecode(file("${path.module}/deployments/monitoring/namespace.yaml"))
}

resource "kubernetes_manifest" "monitoring_deployment" {
  manifest = yamldecode(file("${path.module}/deployments/monitoring/all-in-one.yaml"))
  depends_on = [kubernetes_manifest.monitoring_namespace]
}
```

Then run:
```bash
terraform apply
```

This uses your existing Terraform connection to the cluster!