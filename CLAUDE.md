# K3s Hetzner Cluster - Key Information

@docs/llms.md

# Individual Preferences
@~/.claude/terraform-hcloud-kube-hetzner.md

## Cluster Overview
- **Location**: Nuremberg (nbg1)
- **Architecture**: Mixed (ARM64 CAX + x86 CX instances)
- **Network**: IPv4 public IPs with IPv6 support
- **K3s Version**: v1.33.3+k3s1

## Current Infrastructure

### Servers
```
Control Plane: 1x CAX21 (4 vCPU, 8GB RAM) - 91.98.16.104 / 2a01:4f8:1c1a:47f9::/64
Workers:       
  - 2x CAX21 (ARM64) - 49.12.232.188 / 91.98.16.108
  - 1x CX22 (x86)    - 91.98.124.43 (added recently)
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
- **`*.travelspirit.cloud`**: Covers harbor.travelspirit.cloud and future subdomains
- **`*.visualtourbuilder.com`**: Ready for future VTB subdomains  
- **`*.api.visualtourbuilder.com`**: Covers tst.api.visualtourbuilder.com and future API environments

#### Certificate Issuer:
- **`letsencrypt-dns01`**: DNS01 challenges via Cloudflare API (ONLY issuer)
- **Benefits**: Works with Cloudflare proxy, automatic subdomain coverage, no temporary ingress needed

### Networking
- **Private Network**: k3s-cluster (10.0.0.0/8)
- **Control Plane Subnet**: 10.255.0.0/16
- **Worker Subnet**: 10.0.0.0/16

## Access

### SSH Access (IPv4 - Primary)
```bash
# Control plane (current active IP)
ssh root@91.98.16.104
```

### SSH Access (IPv6 - when available)
```bash
# Control plane
ssh -6 root@2a01:4f8:1c1b:f096::1

# Workers
ssh -6 root@2a01:4f8:1c1a:47f9::1  # agent-bqb
ssh -6 root@2a01:4f8:1c1c:86d8::1  # agent-nld
```

### Using Control Plane as Jump Host
```bash
# Access workers via control plane when IPv6 is down
ssh -J root@195.201.28.253 root@10.0.0.101  # agent-nld
ssh -J root@195.201.28.253 root@10.0.0.102  # agent-bqb
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
ssh -6 root@2a01:4f8:1c1b:f096::1 "kubectl get certificate -A"

# Check cert-manager pods
ssh -6 root@2a01:4f8:1c1b:f096::1 "kubectl get pods -n cert-manager"

# View ingress with SSL
ssh -6 root@2a01:4f8:1c1b:f096::1 "kubectl get ingress -A"
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
- **ARM64 nodes**: 3 nodes with `architecture=arm64:NoSchedule` taint
- **x86 node**: 1 node (k3s-cluster-agent-x86-uro) without architecture taint
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