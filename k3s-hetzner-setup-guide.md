# High-Level Guide: Production k3s on Hetzner with Terraform

## Prerequisites

### Local Environment Setup
- **Terraform** v1.5+ installed
- **kubectl** matching your k3s version
- **Git** for cloning repositories
- **SSH key pair** for server access
- **Hetzner Cloud account** with API token

### Hetzner Cloud Preparation
1. Create a Hetzner Cloud project
2. Generate API token (Settings → Security → API Tokens)
3. Note your preferred locations (fsn1, nbg1, hel1)
4. Understand pricing: CX21 (€5.83/month) minimum for production

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Hetzner Cloud Network                  │
│                    (10.0.0.0/16)                        │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │ Master 1    │  │ Master 2    │  │ Master 3    │   │
│  │ (k3s-cp-1)  │  │ (k3s-cp-2)  │  │ (k3s-cp-3)  │   │
│  │ 10.0.1.1    │  │ 10.0.1.2    │  │ 10.0.1.3    │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
│           │               │               │            │
│           └───────────────┴───────────────┘            │
│                          │                             │
│                   Load Balancer                        │
│                   (API: 6443)                          │
│                          │                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │ Worker 1    │  │ Worker 2    │  │ Worker 3    │   │
│  │ (k3s-wk-1)  │  │ (k3s-wk-2)  │  │ (k3s-wk-3)  │   │
│  │ 10.0.2.1    │  │ 10.0.2.2    │  │ 10.0.2.3    │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Step 1: Use kube-hetzner Terraform Module

### Clone the Repository
```bash
git clone https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner.git
cd terraform-hcloud-kube-hetzner
```

### Create terraform.tfvars
```hcl
# terraform.tfvars
hcloud_token = "your-hetzner-api-token"

# Network configuration
network_region = "eu-central"
cluster_name = "production-k3s"

# Control plane nodes (odd number for etcd quorum)
control_plane_nodepools = [{
  name        = "control-plane"
  server_type = "cx21"  # 2 vCPU, 4GB RAM
  location    = "fsn1"
  labels      = []
  taints      = []
  count       = 3
}]

# Worker nodes
agent_nodepools = [{
  name        = "worker"
  server_type = "cx31"  # 2 vCPU, 8GB RAM
  location    = "fsn1"
  labels      = []
  taints      = []
  count       = 3
}]

# Enable Hetzner integrations
enable_metrics_server = true
enable_cert_manager = true
hetzner_ccm_enable = true
hetzner_csi_enable = true

# Load balancer for HA API access
load_balancer_type = "lb11"
load_balancer_location = "fsn1"

# Security
firewall_kube_api_source = ["0.0.0.0/0"]  # Restrict in production
firewall_ssh_source = ["YOUR_IP/32"]       # Your IP only

# Automatic updates
automatically_upgrade_k3s = true
automatically_upgrade_os = true

# Additional components
install_nginx_ingress = true
nginx_ingress_replica_count = 2
```

### Initialize and Apply
```bash
# Initialize Terraform
terraform init --upgrade

# Review plan
terraform plan

# Apply configuration (takes ~5 minutes)
terraform apply

# Save kubeconfig
terraform output -raw kubeconfig > ~/.kube/config
chmod 600 ~/.kube/config
```

## Step 2: Manual k3s Installation (Alternative)

If you prefer manual control over the kube-hetzner module:

### Terraform Infrastructure Setup
```hcl
# main.tf
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Network
resource "hcloud_network" "k3s" {
  name     = "k3s-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k3s" {
  network_id   = hcloud_network.k3s.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

# SSH Key
resource "hcloud_ssh_key" "k3s" {
  name       = "k3s-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Control plane nodes
resource "hcloud_server" "control_plane" {
  count       = 3
  name        = "k3s-cp-${count.index + 1}"
  server_type = "cx21"
  image       = "ubuntu-22.04"
  location    = "fsn1"
  ssh_keys    = [hcloud_ssh_key.k3s.id]
  
  network {
    network_id = hcloud_network.k3s.id
    ip         = "10.0.0.${count.index + 10}"
  }
  
  user_data = file("cloud-init.yaml")
}

# Load balancer
resource "hcloud_load_balancer" "k3s" {
  name               = "k3s-api"
  load_balancer_type = "lb11"
  location           = "fsn1"
}

resource "hcloud_load_balancer_target" "k3s" {
  count            = length(hcloud_server.control_plane)
  type             = "server"
  load_balancer_id = hcloud_load_balancer.k3s.id
  server_id        = hcloud_server.control_plane[count.index].id
}
```

### k3s Bootstrap Script
```bash
#!/bin/bash
# bootstrap-k3s.sh

# First control plane node
k3sup install \
  --ip $MASTER1_IP \
  --user root \
  --cluster \
  --k3s-channel stable \
  --k3s-extra-args "--disable traefik --disable servicelb" \
  --merge \
  --local-path $HOME/.kube/config

# Additional control plane nodes
for i in 2 3; do
  k3sup join \
    --ip $MASTER${i}_IP \
    --user root \
    --server-ip $MASTER1_IP \
    --server \
    --k3s-channel stable \
    --k3s-extra-args "--disable traefik --disable servicelb"
done

# Worker nodes
for i in 1 2 3; do
  k3sup join \
    --ip $WORKER${i}_IP \
    --user root \
    --server-ip $MASTER1_IP \
    --k3s-channel stable
done
```

## Step 3: Essential Post-Installation

### Install Hetzner Cloud Controller Manager
```bash
kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm-networks.yaml
```

### Install Hetzner CSI Driver
```bash
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/main/deploy/kubernetes/hcloud-csi.yml
```

### Create Storage Class
```yaml
# hetzner-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hetzner-volumes
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.hetzner.cloud
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  csi.storage.k8s.io/fstype: ext4
```

### Install NGINX Ingress
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."load-balancer\.hetzner\.cloud/location"=fsn1
```

## Step 4: Production Hardening

### Network Policies
```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Cert-Manager for TLS
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Backup Configuration
```bash
# Install Velero for backups
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=your-backup-bucket \
  --set configuration.backupStorageLocation.config.s3Url=https://your-s3-endpoint
```

## Step 5: Monitoring Stack

### Prometheus & Grafana
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=hetzner-volumes \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi
```

## Validation Checklist

- [ ] All nodes show Ready: `kubectl get nodes`
- [ ] Core components healthy: `kubectl get pods -n kube-system`
- [ ] Storage class available: `kubectl get storageclass`
- [ ] Load balancer provisioned: `kubectl get svc -n ingress-nginx`
- [ ] Can create PVC: Test with sample deployment
- [ ] Metrics available: `kubectl top nodes`
- [ ] Backups configured: `velero backup-location get`
- [ ] TLS certificates working: Test with sample ingress

## Cost Optimization Tips

1. **Use ARM nodes** (CAX series) for 30% savings on compatible workloads
2. **Implement cluster autoscaling** to scale down during off-hours
3. **Use Hetzner Cloud Networks** to avoid public traffic charges
4. **Consider dedicated servers** for stable workloads (40% cheaper)
5. **Monitor with Prometheus** to identify oversized nodes

## Troubleshooting Common Issues

### Nodes Not Joining
- Check firewall rules (ports 6443, 10250)
- Verify network connectivity between nodes
- Check k3s service logs: `journalctl -u k3s`

### Storage Issues
- Ensure CSI driver is running: `kubectl get pods -n kube-system | grep csi`
- Check Hetzner API token permissions
- Verify volume limits (16 volumes per node)

### Network Problems
- Confirm Cilium/Flannel CNI is healthy
- Check iptables rules on nodes
- Verify cloud network configuration

## Next Steps

1. **Deploy sample application** to validate setup
2. **Configure DNS** with external-dns operator
3. **Set up GitOps** with Flux or ArgoCD
4. **Implement policy enforcement** with OPA/Gatekeeper
5. **Plan disaster recovery** procedures
6. **Document runbooks** for team operations

This setup provides a production-ready foundation supporting hundreds of microservices at 70-85% lower cost than major cloud providers.
