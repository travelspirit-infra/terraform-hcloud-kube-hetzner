# Barry's K3s Cluster Access Guide

## Overview
Barry has been granted co-owner access to the k3s cluster with full cluster-admin privileges. This document outlines how Barry can access and manage the cluster.

## Access Methods

### 1. Kubernetes API Access 

**Kubeconfig Location**: `barry-kubeconfig.yaml` in the project root

**Usage**:
```bash
# Set as default kubeconfig
export KUBECONFIG=/path/to/barry-kubeconfig.yaml

# Or specify per command
kubectl --kubeconfig barry-kubeconfig.yaml get nodes
kubectl --kubeconfig barry-kubeconfig.yaml get pods -A
```

**Identity**: Barry authenticates as `system:serviceaccount:default:barry-admin`

**Permissions**: Full cluster-admin access (appropriate for co-owner status)

### 2. SSH Access to Nodes

Barry's GitHub SSH keys have been added to all cluster nodes.

**Control Plane Access**:
```bash
ssh root@91.98.16.104
```

**Agent Node Access** (via control plane as jump host):
```bash
ssh -J root@91.98.16.104 root@10.0.0.101  # agent-1
ssh -J root@91.98.16.104 root@10.1.0.101  # agent-2  
ssh -J root@91.98.16.104 root@10.1.0.102  # agent-x86
```

## Cluster Information

**API Server**: `https://91.98.16.104:6443`
**Cluster Name**: `k3s-cluster`
**Architecture**: Mixed (ARM64 + x86_64)
**Ingress**: Traefik
**CNI**: Flannel
**Storage**: Hetzner CSI + Local storage

## Key Cluster Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -n kube-system

# View ingress services
kubectl get ingress -A

# Monitor resource usage
kubectl top nodes
kubectl top pods -A
```

## Security Notes

- Barry's GitHub SSH keys (`https://github.com/bseycorp.keys`) are automatically synchronized
- Authentication token is long-lived but can be revoked if needed
- Full cluster-admin privileges allow all operations
- SSH access provides direct node management capabilities

## Key Management

### SSH Keys
SSH keys are managed via GitHub profiles:
- Patrick: `https://github.com/pcmulder.keys`
- Barry: `https://github.com/bseycorp.keys`

Keys are automatically synchronized when Terraform is applied.

### Kubernetes Access
Barry's access is managed through:
- ServiceAccount: `barry-admin` (default namespace)
- ClusterRoleBinding: `barry-cluster-admin`
- Secret: `barry-admin-token`

To revoke access:
```bash
kubectl delete clusterrolebinding barry-cluster-admin
kubectl delete serviceaccount barry-admin
kubectl delete secret barry-admin-token
```

## Important Infrastructure Details

- **Single Control Plane**: Currently non-HA setup (cost optimization)
- **Auto-upgrades**: k3s upgrades enabled, OS upgrades disabled (prevents downtime)
- **Backup**: No automated etcd backups configured yet
- **Load Balancer**: Hetzner LB handles ingress traffic
- **SSL**: cert-manager with Let's Encrypt for automatic certificates

## Next Steps for Production

1. Add HA control plane (3 nodes minimum)
2. Configure etcd backups to S3
3. Set up monitoring (Prometheus/Grafana)
4. Enable OS auto-upgrades once HA is established
5. Consider network policies and pod security standards

---
*Generated: August 2025*
*Managed by: terraform-hcloud-kube-hetzner*