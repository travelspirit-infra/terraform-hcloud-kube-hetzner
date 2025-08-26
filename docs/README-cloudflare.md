# Cloudflare SSL Setup with Terraform

## Overview

This setup uses Cloudflare as a reverse proxy to provide automatic SSL certificates for your K3s cluster. Cloudflare handles all SSL termination, eliminating the need for cert-manager or Let's Encrypt configuration on your cluster.

## Benefits

- **Automatic SSL**: No certificate management needed
- **DDoS Protection**: Built-in Cloudflare protection
- **Caching**: Static content caching at edge locations
- **Zero Downtime**: SSL certificate renewals handled by Cloudflare
- **Simple Setup**: Just enable proxy in DNS records

## Setup Instructions

### 1. Get Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to "My Profile" → "API Tokens"
3. Create a token with these permissions:
   - Zone:DNS:Edit
   - Zone:Zone Settings:Edit
   - Zone:Page Rules:Edit

**Note**: The token in hcloud-env.sh appears to be a Global API Key. For better security, consider creating a scoped API Token instead.

### 2. Configure Terraform

```bash
# Source environment file
source hcloud-env.sh

# Set Terraform variables
export TF_VAR_hcloud_token=$HCLOUD_TOKEN
export TF_VAR_cloudflare_api_token=$CLOUDFLARE_API_TOKEN

# Or create terraform.tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your tokens
```

### 3. Apply Terraform

```bash
terraform init
terraform plan
terraform apply
```

## DNS Records Created

The Terraform configuration creates:

- `k8s.travelspirit.cloud` → Load Balancer IP (proxied)
- `*.k8s.travelspirit.cloud` → Load Balancer IP (proxied)

## SSL Modes

The configuration uses **Flexible SSL** by default:
- Browser → Cloudflare: HTTPS (encrypted)
- Cloudflare → Your Server: HTTP (unencrypted)

To change to **Full SSL** (encrypted end-to-end):
1. Edit `cloudflare.tf`
2. Change `ssl = "flexible"` to `ssl = "full"`
3. Ensure your cluster has valid certificates (self-signed is OK)

## Testing

After applying:
```bash
# Test HTTPS
curl -I https://k8s.travelspirit.cloud

# Should return HTTP 200 with Cloudflare headers
```

## Ingress Configuration

Your Kubernetes ingress resources don't need any SSL configuration:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: traefik
  rules:
  - host: myapp.k8s.travelspirit.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

Cloudflare automatically provides SSL for any subdomain under `k8s.travelspirit.cloud`.

## Troubleshooting

### Error 526 (Invalid SSL certificate)
- Switch to Flexible SSL mode in Cloudflare
- Or install valid certificates on your origin server

### Error 525 (SSL handshake failed)
- Your origin server rejected Cloudflare's SSL connection
- Check if your server is listening on port 443
- Verify SSL configuration on origin

### DNS not resolving
- Check if DNS records are created in Cloudflare dashboard
- Verify zone ID is correct
- Wait 1-2 minutes for propagation