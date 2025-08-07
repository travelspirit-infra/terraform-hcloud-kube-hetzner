# K3S Infrastructure Diagrams

This directory contains visual representations of our K3S cluster infrastructure on Hetzner Cloud.

## Generated Diagrams

### 1. k3s_infrastructure.png
**Main Infrastructure Overview**
- Shows all servers, load balancers, and network topology
- Includes IPv6 addresses and private network IPs
- Displays Kubernetes services and their relationships
- Color-coded by function (control plane, workers, services)

### 2. k3s_network_flow.png
**Traffic Flow Diagram**
- Step-by-step visualization of how traffic flows from client to application
- Shows DNS resolution, load balancing, and ingress routing
- Highlights proxy protocol and TLS termination points

### 3. k3s_cost_breakdown.png
**Cost Analysis**
- Visual breakdown of monthly infrastructure costs
- Total: €28.24/month
- Itemized by servers, load balancer, network, and traffic

## Regenerating Diagrams

To update the diagrams with latest infrastructure state:

```bash
# Activate virtual environment
source ../venv/bin/activate

# Install dependencies (if needed)
pip install diagrams

# Regenerate diagrams
python k3s_infrastructure.py
```

## Key Infrastructure Details

- **Location**: Nuremberg (nbg1)
- **Architecture**: ARM64 (CAX instances)
- **Networking**: IPv6-only nodes with private network
- **Load Balancer**: 167.235.110.121 (IPv4) / 2a01:4f8:1c1f:7a40::1 (IPv6)
- **Domain**: k8s.travelspirit.cloud

## Current State
- 1x Control Plane (CAX21)
- 2x Workers (CAX21)
- 1x Load Balancer (LB11)
- All nodes running OpenSUSE MicroOS