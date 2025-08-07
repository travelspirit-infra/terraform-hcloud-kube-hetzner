# K3s Hetzner Cluster - Complete Resource Documentation

## Project Overview
This project deploys a K3s Kubernetes cluster on Hetzner Cloud using the terraform-hcloud-kube-hetzner module. The cluster is optimized for cost with ARM64 instances and IPv6-only networking.

## Infrastructure Resources

### Hetzner Cloud Resources

#### Servers (3 total)
| ID | Name | Type | Location | IPv6 | Private IP | Role | Status |
|---|---|---|---|---|---|---|---|
| 103731993 | k3s-cluster-control-plane-nbg1-uwu | CAX21 | nbg1-dc3 | 2a01:4f8:1c1b:f096::/64 | 10.255.0.101 | Control Plane | Running |
| 103731974 | k3s-cluster-agent-nbg1-bqb | CAX21 | nbg1-dc3 | 2a01:4f8:1c1a:47f9::/64 | 10.0.0.102 | Worker | Running |
| 103732038 | k3s-cluster-agent-nbg1-nld | CAX21 | nbg1-dc3 | 2a01:4f8:1c1c:86d8::/64 | 10.0.0.101 | Worker | Running |

**Server Details:**
- **Type**: CAX21 (ARM64, 4 vCPU, 8GB RAM, 80GB disk)
- **OS**: openSUSE MicroOS (automatic updates enabled)
- **IPv4**: Disabled (cost optimization)
- **Monthly Cost**: ~€7.18 per server

#### Load Balancer
| ID | Name | Type | IPv4 | IPv6 | Purpose |
|---|---|---|---|---|---|
| 4100996 | k3s-cluster-traefik | lb11 | 167.235.110.121 | 2a01:4f8:1c1f:7a40::1 | Ingress (HTTP/HTTPS) |

**Load Balancer Configuration:**
- Port 80 → NodePort 31903 (HTTP with Proxy Protocol)
- Port 443 → NodePort 30492 (HTTPS with Proxy Protocol)
- Targets: All cluster nodes via label selector
- Monthly Cost: ~€6.70

#### Network
| ID | Name | IP Range | Subnets |
|---|---|---|---|
| 11243089 | k3s-cluster | 10.0.0.0/8 | Control: 10.255.0.0/16, Workers: 10.0.0.0/16 |

#### Firewall
| ID | Name | Applied To |
|---|---|---|
| 2276659 | k3s-cluster | All cluster nodes |

**Firewall Rules:**
- Inbound: SSH (22), Kubernetes API (6443), ICMP
- Outbound: HTTP (80), HTTPS (443), DNS (53), NTP (123), ICMP

#### Placement Groups
- **control_plane**: ID 1047830 (spread topology)
- **agent**: ID 1047829 (spread topology)

#### Primary IPs (IPv6)
- 94982260: 2a01:4f8:1c1a:47f9::/64 (auto-delete)
- 94982269: 2a01:4f8:1c1b:f096::/64 (auto-delete)
- 94982287: 2a01:4f8:1c1c:86d8::/64 (auto-delete)

### Kubernetes Resources

#### System Components
| Component | Namespace | Status | Purpose |
|---|---|---|---|
| CoreDNS | kube-system | Running (1/1) | Cluster DNS |
| Metrics Server | kube-system | Running (1/1) | Resource metrics |
| Hetzner CCM | kube-system | Running (1/1) | Cloud integration |
| Hetzner CSI | kube-system | Running | Storage provisioning |
| Traefik | kube-system | Running (2/2) | Ingress controller |

#### Storage
| StorageClass | Provisioner | Default | Volume Expansion |
|---|---|---|---|
| hcloud-volumes | csi.hetzner.cloud | Yes | Enabled |

#### Applications
| Name | Namespace | Type | Replicas | Access |
|---|---|---|---|---|
| hello-world | default | Deployment | 2 | http://167.235.110.121/ |
| hello-world-default | kube-system | Deployment | 1 | Default backend |

#### Services
| Name | Namespace | Type | Port | Purpose |
|---|---|---|---|---|
| kubernetes | default | ClusterIP | 443 | API server |
| hello-world | default | ClusterIP | 80 | App service |
| hello-nodeport | default | NodePort | 30080 | Direct node access |
| traefik | kube-system | NodePort | 80/443 | Ingress ports |

#### Ingresses
| Name | Namespace | Class | Backend | Path |
|---|---|---|---|---|
| hello-world | default | traefik | hello-world:80 | Default backend |

## Terraform Configuration

### Main Configuration File: `kube.tf`
```hcl
module "kube-hetzner" {
  source = "kube-hetzner/kube-hetzner/hcloud"
  
  # Authentication
  hcloud_token = var.hcloud_token
  hcloud_ssh_key_id = "100071493"
  ssh_public_key = file("~/.ssh/id_rsa.pub")
  ssh_private_key = file("~/.ssh/id_rsa")
  
  # Network
  network_region = "eu-central"
  cluster_name = "k3s-cluster"
  
  # Nodes
  control_plane_nodepools = [{
    name = "control-plane-nbg1"
    server_type = "cax21"
    location = "nbg1"
    count = 1
    enable_public_ipv4 = false
    enable_public_ipv6 = true
  }]
  
  agent_nodepools = [{
    name = "agent-nbg1"
    server_type = "cax21"
    location = "nbg1"
    count = 2
    enable_public_ipv4 = false
    enable_public_ipv6 = true
  }]
  
  # Features
  load_balancer_type = "lb11"
  load_balancer_location = "nbg1"
  use_control_plane_lb = false  # Disabled for cost
  enable_metrics_server = true
  enable_cert_manager = true
  automatically_upgrade_k3s = true
  automatically_upgrade_os = true
  ingress_controller = "traefik"
}
```

### Environment Setup
- **API Token**: Stored in `hcloud-env.sh`
- **SSH Key**: Using existing key ID 100071493
- **Terraform Version**: >= 0.15.0
- **Provider**: hetznercloud/hcloud >= 1.0.0, < 2.0.0

## Access Methods

### SSH Access
```bash
# Control plane
ssh -6 root@2a01:4f8:1c1b:f096::1

# Worker nodes
ssh -6 root@2a01:4f8:1c1a:47f9::1  # agent-bqb
ssh -6 root@2a01:4f8:1c1c:86d8::1  # agent-nld
```

### Kubernetes Access
```bash
# Direct via IPv6 (update kubeconfig)
kubectl --kubeconfig k3s-cluster_kubeconfig.yaml get nodes

# Via SSH tunnel
ssh -6 root@2a01:4f8:1c1b:f096::1 "kubectl get nodes"
```

### Application Access
- **Hello World**: http://167.235.110.121/
- **Direct NodePort**: http://[node-ipv6]:30080/

## Cost Breakdown

### Monthly Costs
- **Servers**: 3x CAX21 @ €7.18 = €21.54
- **Load Balancer**: 1x lb11 = €6.70
- **Total**: €28.24/month

### Cost Optimizations Implemented
1. **ARM64 instances**: Better price/performance than x86
2. **IPv6-only**: Saves €1/month per server (€3 total)
3. **No control plane LB**: Saves €6.70/month
4. **Right-sized instances**: Could use CAX11 for control plane in future

## Known Issues & Limitations

### Current Issues
1. **IPv4 connectivity**: Nodes can't reach IPv4-only services (e.g., some GitHub endpoints)
2. **Primary IP limit**: Hit account limit preventing additional nodes
3. **External kubectl**: Must use IPv6 or SSH tunnel (no IPv4 endpoint)

### Architectural Decisions
1. **Single control plane**: Not HA, but saves costs
2. **IPv6-only**: Requires IPv6 connectivity for management
3. **Manual deployments**: Some components deployed manually due to GitHub connectivity

## Maintenance Tasks

### Regular Tasks
- Monitor MicroOS automatic updates
- Check K3s automatic upgrades
- Review resource usage for right-sizing

### Backup Considerations
- No automated etcd backups configured
- No persistent volume backups
- Terraform state should be backed up

## Future Improvements

### High Priority
1. Add more control plane nodes for HA
2. Configure automated backups
3. Deploy monitoring stack (Prometheus/Grafana)
4. Set up proper DNS instead of IP access

### Medium Priority
1. Configure cert-manager for SSL
2. Add network policies
3. Implement pod security standards
4. Set up log aggregation

### Low Priority
1. Add autoscaling for worker nodes
2. Implement GitOps with ArgoCD
3. Configure multi-tenancy with namespaces
4. Add service mesh (optional)

## Troubleshooting

### Common Commands
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Check Hetzner resources
hcloud server list
hcloud load-balancer list

# View logs
kubectl logs -n kube-system deployment/hcloud-cloud-controller-manager
kubectl logs -n kube-system daemonset/traefik
```

### Known Workarounds
1. **GitHub connectivity**: Use IPv6-enabled mirrors or proxy
2. **Primary IP limits**: Request increase from Hetzner support
3. **Terraform IPv6 issues**: Use targeted applies or manual steps

## Security Notes

### Current Security Posture
- ✅ Firewall enabled with restrictive rules
- ✅ SSH key-only authentication
- ✅ Private networking for node communication
- ✅ Automatic OS updates enabled
- ⚠️ No network policies configured
- ⚠️ No pod security policies
- ⚠️ Basic RBAC only

### Recommendations
1. Implement network policies for pod isolation
2. Enable audit logging
3. Configure RBAC for users/services
4. Use secrets management (Sealed Secrets or similar)
5. Regular security updates and patches