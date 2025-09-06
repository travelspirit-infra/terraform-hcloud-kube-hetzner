# K3s Hetzner Cluster - Key Information

@docs/llms.md

# Individual Preferences
@~/.claude/terraform-hcloud-kube-hetzner.md

## Cluster Overview
- **Location**: Nuremberg (nbg1)
- **Architecture**: Mixed (ARM64 CAX + x86 CX instances)
- **Network**: IPv4 public IPs with IPv6 support
- **K3s Version**: v1.33.4+k3s1

## Current Infrastructure

### Servers
```
Control Plane: 1x control-plane-nbg1 - 91.98.16.104 / 2a01:4f8:1c1a:47f9::/64
Workers:       
  - 1x agent-arm64 (ARM64) - 91.98.124.43 / 2a01:4f8:c0c:59d2::/64
  - 1x agent-x86 (x86)     - 91.98.16.108 / 2a01:4f8:1c1b:f096::/64
```

### Load Balancers
- **Ingress LB**: 167.235.110.121 / 2a01:4f8:1c1f:7a40::1 (Traefik, ports 80/443)
- **Control Plane LB**: Removed to save costs (€6.70/month)

### Domains & SSL
- **k8s.travelspirit.cloud**: Points to ingress load balancer (167.235.110.121)
- **harbor.travelspirit.cloud**: Harbor container registry
- **tst.api.visualtourbuilder.com**: VTB test API environment
- **SSL Certificates**: Let's Encrypt wildcards via DNS01 challenges
- **Certificate Management**: cert-manager with Cloudflare DNS01 challenges
- **DNS**: Managed by Terraform (cloudflare.tf)

### SSL Certificate Architecture
**Preferred Method**: DNS01 challenges via Cloudflare API (no HTTP challenge complexity)

#### Active Wildcard Certificates:
- **`*.travelspirit.cloud`**: Covers harbor.travelspirit.cloud, argocd.travelspirit.cloud and future subdomains
  - **Namespaces**: cert-manager (primary), argocd (dedicated copy)
  - **Secret Names**: `wildcard-travelspirit-cloud-tls`, `travelspirit-wildcard-tls`
  - **Valid Until**: 2025-12-01 (auto-renewed by cert-manager)
- **`*.visualtourbuilder.com`**: Ready for future VTB subdomains  
  - **Namespace**: cert-manager
  - **Secret Name**: `wildcard-visualtourbuilder-com-tls`
- **`*.api.visualtourbuilder.com`**: Covers tst.api.visualtourbuilder.com and future API environments
  - **Used by**: VTB test API environment
- **`*.k8s.travelspirit.cloud`**: Legacy k8s subdomain certificates
  - **Example**: nginx-demo.k8s.travelspirit.cloud
  - **Note**: Being migrated to main travelspirit.cloud wildcard

#### Certificate Issuer:
- **`letsencrypt-dns01`**: DNS01 challenges via Cloudflare API (ONLY issuer)
- **Benefits**: Works with Cloudflare proxy, automatic subdomain coverage, no temporary ingress needed

#### Certificate Management Strategy:
- **Per-namespace Certificate resources**: Each namespace creates its own Certificate resource pointing to the same wildcard
- **Shared ClusterIssuer**: All certificates use the same `letsencrypt-dns01` ClusterIssuer
- **No certificate copying**: Certificates are provisioned directly in each namespace that needs them

### Networking
- **Private Network**: k3s-cluster (10.0.0.0/8)
- **Control Plane Subnet**: 10.255.0.0/16 (10.255.0.101)
- **ARM64 Worker Subnet**: 10.0.0.0/16 (10.0.0.101)  
- **x86 Worker Subnet**: 10.1.0.0/16 (10.1.0.101)

## Access

### SSH Access (IPv4 - Primary)
```bash
# Control plane (current active IP)
ssh root@91.98.16.104
```

### SSH Access (IPv6 - when available)
```bash
# Control plane  
ssh -6 root@2a01:4f8:1c1a:47f9::1

# Workers
ssh -6 root@2a01:4f8:c0c:59d2::1     # agent-arm64
ssh -6 root@2a01:4f8:1c1b:f096::1    # agent-x86
```

### Using Control Plane as Jump Host
```bash
# Access workers via control plane when IPv6 is down
ssh -J root@91.98.16.104 root@10.0.0.101  # agent-arm64
ssh -J root@91.98.16.104 root@10.1.0.101  # agent-x86
```

### kubectl Access
✅ **External kubectl access is WORKING**:
```bash
# Direct access via kubeconfig (points to control plane IPv4)
kubectl --kubeconfig k3s-cluster_kubeconfig.yaml get nodes
kubectl --kubeconfig k3s-cluster_kubeconfig.yaml get ingress -A

# Server endpoint: https://91.98.16.104:6443
# No need for SSH tunneling or jump hosts!
```

## Critical Components Status

✅ **Working**:
- Hetzner Cloud Controller Manager (CCM)
- CoreDNS
- Metrics Server
- Hetzner CSI Driver (storage) - `hcloud-volumes` StorageClass available
- Traefik Ingress Controller
- cert-manager (SSL certificate management)

❌ **Issues**:
- Only 1 control plane node (not HA)
- Mixed architecture cluster (ARM64 + x86) requires tolerations

✅ **Recently Fixed**:
- External kubectl access now working directly via kubeconfig

## Important Commands

### Hetzner CLI (Preferred)
```bash
source hcloud-env.sh  # Load API tokens
hcloud server list    # List all servers
hcloud load-balancer list
```

### Check cluster health
```bash
# Preferred: Direct kubectl access
kubectl --kubeconfig k3s-cluster_kubeconfig.yaml get nodes
kubectl --kubeconfig k3s-cluster_kubeconfig.yaml get pods -n kube-system

# Alternative: SSH if needed
ssh root@91.98.16.104 "kubectl get nodes && kubectl get pods -n kube-system"
```

### SSL & Certificate Management
```bash
# Setup SSL (run once)
./setup-ssl.sh

# Check certificate status
ssh -6 root@2a01:4f8:1c1a:47f9::1 "kubectl get certificate -A"

# Check cert-manager pods
ssh -6 root@2a01:4f8:1c1a:47f9::1 "kubectl get pods -n cert-manager"

# View ingress with SSL
ssh -6 root@2a01:4f8:1c1a:47f9::1 "kubectl get ingress -A"
```

### Hetzner CLI
```bash
source hcloud-env.sh  # Load API tokens (Hetzner & Cloudflare)
hcloud server list
hcloud load-balancer list
```

### Environment Setup
The `hcloud-env.sh` file contains required API tokens:
```bash
source hcloud-env.sh  # Load HCLOUD_TOKEN and CLOUDFLARE_API_TOKEN
```

## Known Issues & Workarounds

1. **IPv6 SSH Connection**: The terraform remote_file provider fails with IPv6. Use targeted applies or manual operations.

2. **Primary IP Limit**: Account is at IPv6 limit. To add more nodes:
   - Enable IPv4 temporarily during creation
   - Or request limit increase from Hetzner

3. **Mixed Architecture**: New x86 worker added alongside ARM64 nodes. Workloads need appropriate node selectors or tolerations.

## Cost Optimization Achieved
- ARM64 instances (better price/performance)
- IPv6-only (saves €3/month on IPv4 addresses)
- Properly sized instances (could use CAX11 for control plane in fresh deployment)

## Next Steps for Production
1. ~~Fix external API access~~ ✅ Completed (kubectl works directly)
2. Add more control plane nodes for HA 
3. Deploy monitoring stack (Prometheus/Grafana)
4. Configure backup strategy
5. ~~Set up proper ingress with SSL certificates~~ ✅ Completed
6. Standardize cluster architecture (decide on ARM64 vs x86 vs mixed)

## Configuration Notes
- Using `kube-hetzner/kube-hetzner/hcloud` module with MicroOS
- CCM and CSI deployed separately due to initial terraform issues
- Key files: kube.tf (main), cloudflare.tf (DNS), providers.tf, variables.tf

## Multi-Architecture Notes
- **ARM64 nodes**: 1 node (k3s-cluster-agent-arm64-bml) with `architecture=arm64:NoSchedule` taint
- **x86 node**: 1 node (k3s-cluster-agent-x86-zmp) without architecture taint  
- Deployments targeting ARM64 nodes need tolerations:
  ```yaml
  tolerations:
  - key: architecture
    value: arm64
    effect: NoSchedule
  ```

## Storage
- **Default StorageClass**: `hcloud-volumes` (Hetzner CSI)
- **Dynamic provisioning**: Available via Hetzner Cloud Volumes
- **Access mode**: ReadWriteOnce (block storage)

## GitOps & Application Management

### ArgoCD Deployment
- **URL**: https://argocd.travelspirit.cloud
- **Admin Credentials**: admin / yJaGQOyloNe49qno
- **Status**: ✅ Deployed and operational
- **Keycloak Integration**: Configured for SSO with auth.travelspirit.app

### Management Level Strategy
**Recommended approach for managing cluster components:**

#### **Level 1: Infrastructure (Terraform)**
- K3s cluster nodes and networking ✅ Current
- Hetzner Load Balancers and DNS ✅ Current  
- Core k3s components (CoreDNS, kube-proxy) ✅ Current

#### **Level 2: Platform Services (Terraform - Current State)**
- ArgoCD itself ✅ Keep with Terraform (avoids circular dependencies)
- Traefik Ingress Controller ✅ Keep with Terraform (core platform)
- cert-manager ✅ Keep with Terraform (needed for ArgoCD)
- Hetzner CCM/CSI ✅ Keep with Terraform (infrastructure layer)

#### **Level 3: Applications (ArgoCD)**
- VTB API ⚡ **Target**: Deploy via ArgoCD with existing Helm chart
- TravelSpirit applications ⚡ **Target**: All future apps via GitOps
- Monitoring stack ⚡ **Future**: Prometheus/Grafana via ArgoCD
- Development/staging environments ⚡ **Target**: Self-service via Git

### ArgoCD RBAC Groups
**Keycloak groups for role-based access:**
- `argocd-admins`: Full admin access to ArgoCD
- `argocd-developers`: Application management in ArgoCD projects
- `argocd-devops`: Full application and infrastructure management in ArgoCD
- `argocd-vtb-team`: VTB-specific application admin access
- `argocd-readonly`: Read-only access to ArgoCD applications

### ArgoCD GitOps Workflow
Note: `argocd` cli too is available and logged in. Use it.

**CRITICAL**: Always use ArgoCD for application deployments. Never create deployment scripts.

**Directory Structure**:
- `argocd-apps/`: ArgoCD Application definitions (what ArgoCD manages)
- `deployments/`: Plain Kubernetes YAML manifests (what gets deployed)

**Deployment Process**:
1. **Create plain YAML manifests** in `deployments/app-name/manifests/`
2. **Create ArgoCD Application** in `argocd-apps/app-name/` pointing to the manifests
3. **Commit and push** - ArgoCD automatically detects and deploys
4. **Never use `kubectl apply`** directly or create deployment scripts

**Example Structure**:
```
deployments/postgres/manifests/     # Plain Kubernetes YAML
argocd-apps/postgres/               # ArgoCD Application pointing to manifests/
```

**Benefits**:
- **Git as single source of truth**: What's in Git is what's running
- **Automatic sync**: Push to Git → ArgoCD deploys automatically  
- **Rollback capability**: Git revert → automatic rollback
- **Audit trail**: All changes tracked in Git history

### Next Actions
1. **Immediate**: Deploy VTB API via ArgoCD using existing Helm chart
2. **Short-term**: Set up Keycloak SSO integration
3. **Medium-term**: Establish GitOps workflow for all applications
4. **Future**: Consider migrating platform services to ArgoCD (Phase 2)