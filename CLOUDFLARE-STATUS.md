# Cloudflare SSL Setup Status

## ✅ Completed

1. **DNS Records Created**:
   - `k8s.travelspirit.cloud` → 167.235.110.121 (proxied)
   - `k8s.travelspirit.cloud` → 2a01:4f8:1c1f:7a40::1 (IPv6, proxied)
   - `*.k8s.travelspirit.cloud` → 167.235.110.121 (wildcard, proxied)

2. **Terraform Configuration**:
   - Added `cloudflare.tf` for DNS management
   - Created `providers.tf` for provider configuration
   - Updated `hcloud-env.sh` with `CLOUDFLARE_API_TOKEN`

## 🔧 Current Status

- **HTTP**: ✅ Working (http://k8s.travelspirit.cloud)
- **HTTPS**: ⚠️ Error 526 (Invalid SSL certificate)

## 📝 To Fix HTTPS

The HTTPS error occurs because Cloudflare is set to "Full" SSL mode but your origin server doesn't have a valid certificate.

### Option 1: Change to Flexible SSL (Recommended)
Log into Cloudflare Dashboard → SSL/TLS → Overview → Set to "Flexible"

### Option 2: Install Origin Certificate
1. Generate a Cloudflare Origin Certificate
2. Configure Traefik to use it
3. Keep SSL mode as "Full"

## 🚀 Next Steps

1. Change SSL mode to "Flexible" in Cloudflare Dashboard
2. Test: `curl https://k8s.travelspirit.cloud`
3. Deploy your applications with ingress rules

## 📌 Example Ingress

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

Cloudflare will automatically provide SSL for any subdomain!