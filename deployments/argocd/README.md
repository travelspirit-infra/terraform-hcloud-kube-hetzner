# ArgoCD Deployment for TravelSpirit K3s Cluster

This directory contains the complete ArgoCD deployment configuration following GitOps and production best practices.

## Overview

ArgoCD is deployed using the official Helm chart with custom values tailored for the TravelSpirit infrastructure. The deployment includes:

- **Production-ready configuration** with proper resource limits and health checks
- **RBAC configuration** with role-based access control
- **SSL/TLS termination** via cert-manager and Let's Encrypt
- **Ingress configuration** for Traefik with automatic HTTPS redirection
- **ARM64 optimized deployment** - all ArgoCD components scheduled on ARM64 nodes
- **Monitoring integration** with Prometheus metrics endpoints

## Architecture

```
Internet → Hetzner LB → Traefik → ArgoCD Server (ARM64)
                                ↓
                           ArgoCD Components (All ARM64):
                           - Controller (ARM64 node)
                           - Repository Server (ARM64 node)  
                           - ApplicationSet Controller (ARM64 node)
                           - Notifications Controller (ARM64 node)
                           - Redis (ARM64 node + Hetzner volumes)
```

## ARM64 Deployment Strategy

This ArgoCD deployment is optimized to run exclusively on ARM64 nodes for several benefits:

### Why ARM64?
- **Cost efficiency**: ARM64 instances (CAX series) offer better price/performance ratio
- **Energy efficiency**: ARM processors are more power-efficient  
- **Resource optimization**: Dedicates ARM64 resources to ArgoCD while keeping x86 available for workloads that require it
- **Performance**: ARM64 containers often show better performance for I/O intensive operations like Git clones

### Node Scheduling Configuration
All ArgoCD components use:
```yaml
nodeSelector:
  architecture: arm64
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: architecture
              operator: In
              values:
                - arm64
```

This ensures ArgoCD pods **only** run on your `agent-arm64` nodes (CAX21 instances).

## Prerequisites

Before deploying ArgoCD, ensure:

1. **K3s cluster is running** with the Hetzner terraform configuration
2. **cert-manager is enabled** in the terraform configuration (already configured)
3. **Traefik is configured** as the ingress controller (already configured)
4. **kubectl is configured** to access your cluster
5. **Helm 3.x is installed**

## Quick Start

### 1. Deploy the Cluster
First, ensure your k3s cluster is deployed:

```bash
cd /Users/pcmulder/projects/terraform-hcloud-kube-hetzner
terraform plan
terraform apply
```

### 2. Configure DNS
Set up DNS records for ArgoCD access:

```bash
# Add A record: argocd.k8s.travelspirit.cloud → <load-balancer-ip>
# Get the load balancer IP:
kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 3. Configure Cloudflare API Token
Update the certificate issuer with your Cloudflare API token:

```bash
# Edit cert-issuer.yaml and replace the placeholder
vim cert-issuer.yaml

# Or create the secret directly:
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN \
  -n cert-manager
```

### 4. Install ArgoCD

```bash
cd deployments/argocd

# Make the install script executable (if not already)
chmod +x install-argocd.sh

# Run the installation
./install-argocd.sh
```

### 5. Apply RBAC and Certificates

```bash
# Apply RBAC configuration
kubectl apply -f rbac-config.yaml

# Apply certificate issuer (update API token first!)
kubectl apply -f cert-issuer.yaml
```

## Configuration Files

### `values.yaml`
Production-ready Helm values for ArgoCD including:
- Resource limits and requests
- High availability configuration (when multiple nodes available)
- Ingress configuration for Traefik
- Metrics and monitoring setup
- Repository and OIDC configuration templates

### `install-argocd.sh`
Automated installation script that:
- Validates prerequisites
- Creates necessary namespaces
- Adds Helm repositories
- Installs/upgrades ArgoCD
- Provides access credentials and instructions

### `rbac-config.yaml`
Comprehensive RBAC configuration with:
- **Custom roles**: admin, developer, devops, readonly, ci-cd
- **AppProjects**: travelspirit, infrastructure
- **Security policies** and access controls
- **User/group assignments** (to be updated with OIDC)

### `cert-issuer.yaml`
Let's Encrypt certificate configuration:
- **DNS01 challenges** via Cloudflare API
- **Wildcard certificate support** for `*.k8s.travelspirit.cloud`
- **Automatic renewal** handled by cert-manager

## Access ArgoCD

### Web UI Access

1. **Wait for certificate**: Check certificate status
   ```bash
   kubectl get certificate -n argocd
   kubectl describe certificate argocd-tls -n argocd
   ```

2. **Access via HTTPS**: https://argocd.k8s.travelspirit.cloud

3. **Login credentials**:
   ```bash
   # Username: admin
   # Password: 
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d; echo
   ```

### CLI Access

1. **Install ArgoCD CLI**:
   ```bash
   # Linux/macOS
   curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
   sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
   rm argocd-linux-amd64
   ```

2. **Login to ArgoCD**:
   ```bash
   argocd login argocd.k8s.travelspirit.cloud
   ```

### Port Forwarding (Alternative)

If DNS/ingress isn't ready:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
```

## Security Configuration

### RBAC Roles

- **admin**: Full cluster access (Patrick)
- **developer**: Application management (Barry, developers)  
- **devops**: Infrastructure and application management
- **readonly**: View-only access
- **ci-cd**: Automated deployment access

### Projects

- **travelspirit**: Main application deployments
- **infrastructure**: Platform and infrastructure components

### Best Practices Applied

✅ **Least privilege access** - Users only get needed permissions  
✅ **Project isolation** - Applications are isolated by project  
✅ **Resource whitelisting** - Only allowed Kubernetes resources  
✅ **Namespace restrictions** - Limited destination namespaces  
✅ **Audit logging** - All actions are logged  
✅ **TLS encryption** - All traffic encrypted in transit  

## First Application Deployment

### Option 1: Via Web UI
1. Login to ArgoCD web interface
2. Click "NEW APP"
3. Fill in application details
4. Configure sync policy
5. Deploy!

### Option 2: Via CLI
```bash
# Example: Deploy a test application
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

### Option 3: Declarative (GitOps)
Create Application manifests in your Git repository:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: travelspirit
  source:
    repoURL: https://github.com/travelspirit-infra/travelspirit
    targetRevision: HEAD
    path: applications/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: travelspirit-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Monitoring and Troubleshooting

### Health Checks
```bash
# Check ArgoCD components
kubectl get pods -n argocd
kubectl get ingress -n argocd  
kubectl get certificates -n argocd

# Check logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller
```

### Common Issues

**Certificate not ready:**
```bash
kubectl describe certificate argocd-tls -n argocd
kubectl logs -n cert-manager deployment/cert-manager
```

**Ingress not working:**
```bash
kubectl describe ingress -n argocd
kubectl logs -n kube-system deployment/traefik
```

**Application sync issues:**
```bash
kubectl logs -n argocd deployment/argocd-repo-server
argocd app get <app-name> --show-params
```

## Integration with TravelSpirit

### Repository Access
- Configure GitHub/GitLab access tokens in ArgoCD
- Use deploy keys for private repositories
- Set up webhooks for automatic sync triggers

### CI/CD Integration
- GitHub Actions can use ArgoCD CLI or API
- Deploy keys and service accounts for automation
- Image update automation via ArgoCD Image Updater

### Monitoring Integration
- ArgoCD metrics exported to Prometheus
- Grafana dashboards for ArgoCD monitoring
- Alerts for failed deployments and sync issues

## Backup and Recovery

### Configuration Backup
```bash
# Export ArgoCD configuration
argocd admin export > argocd-backup.yaml

# Backup RBAC and projects
kubectl get appprojects -n argocd -o yaml > projects-backup.yaml
kubectl get configmap argocd-rbac-cm -n argocd -o yaml > rbac-backup.yaml
```

### Disaster Recovery
1. Redeploy ArgoCD using this configuration
2. Restore configuration from backups
3. Applications will self-heal from Git repositories

## Maintenance

### Updates
```bash
# Update Helm chart
helm repo update
./install-argocd.sh  # Script handles upgrades

# Update RBAC
kubectl apply -f rbac-config.yaml
```

### Cleanup
```bash
# Remove ArgoCD (careful!)
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

## Support and Documentation

- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Helm Chart**: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
- **TravelSpirit DevOps**: Contact Patrick or Barry for cluster-specific issues

---

**★ Insight ─────────────────────────────────────**  
This ArgoCD deployment follows cloud-native best practices with proper RBAC, TLS termination, and GitOps workflows. The configuration is designed to scale with your team while maintaining security and observability.  
**─────────────────────────────────────────────────**