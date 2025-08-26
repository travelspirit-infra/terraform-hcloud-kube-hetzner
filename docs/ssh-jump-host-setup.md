# SSH Jump Host Configuration for K3s Cluster

## Overview
This document explains how to use the K3s control plane as a jump host to access worker nodes when direct IPv6 connectivity is unavailable.

## Problem
When IPv6 connectivity fails, worker nodes become inaccessible since they only have IPv6 addresses. The control plane has been configured with a public IPv4 address (195.201.28.253) to provide reliable access.

## Initial Issue
MicroOS (the operating system used on all nodes) has SSH hardened by default with the following settings:
```
allowtcpforwarding no
permittunnel no
gatewayports no
```

This prevents the control plane from acting as a jump host, resulting in the error:
```
channel 0: open failed: administratively prohibited: open failed
```

## Solution

### 1. Enable TCP Forwarding on Control Plane
SSH to the control plane and enable TCP forwarding:

```bash
ssh root@195.201.28.253

# Create SSH configuration to allow forwarding
mkdir -p /etc/ssh/sshd_config.d
echo 'AllowTcpForwarding yes' > /etc/ssh/sshd_config.d/99-allow-forwarding.conf

# Restart SSH daemon
systemctl restart sshd
```

### 2. Access Worker Nodes via Jump Host

Once TCP forwarding is enabled, you can access worker nodes through the control plane:

```bash
# Access worker node 1 (nld)
ssh -J root@195.201.28.253 root@10.0.0.101

# Access worker node 2 (bqb)
ssh -J root@195.201.28.253 root@10.0.0.102
```

## SSH Configuration

Add this to your `~/.ssh/config` for easier access:

```ssh
Host k3s-control
    HostName 195.201.28.253
    User root
    Port 22

Host k3s-worker-1
    HostName 10.0.0.101
    User root
    ProxyJump k3s-control
    
Host k3s-worker-2
    HostName 10.0.0.102
    User root
    ProxyJump k3s-control
```

Then simply use:
```bash
ssh k3s-worker-1
ssh k3s-worker-2
```

## Network Architecture

The cluster uses Hetzner's private network with two subnets:
- **Control Plane**: 10.255.0.0/16 (IP: 10.255.0.101)
- **Worker Nodes**: 10.0.0.0/16 (IPs: 10.0.0.101, 10.0.0.102)

Both subnets are on the same Hetzner network (ID: 11243089) with routing handled by Hetzner's infrastructure.

## Access Methods Summary

1. **Direct IPv4** (Always works):
   ```bash
   ssh root@195.201.28.253  # Control plane only
   ```

2. **Direct IPv6** (When IPv6 is available):
   ```bash
   ssh -6 root@2a01:4f8:1c1b:f096::1  # Control plane
   ssh -6 root@2a01:4f8:1c1a:47f9::1  # Worker bqb
   ssh -6 root@2a01:4f8:1c1c:86d8::1  # Worker nld
   ```

3. **Via Jump Host** (When IPv6 is down):
   ```bash
   ssh -J root@195.201.28.253 root@10.0.0.101  # Worker nld
   ssh -J root@195.201.28.253 root@10.0.0.102  # Worker bqb
   ```

## Security Considerations

Enabling TCP forwarding on the control plane allows it to act as a jump host. This is a calculated security trade-off:
- **Risk**: The control plane can forward TCP connections
- **Benefit**: Reliable access to all cluster nodes when IPv6 fails
- **Mitigation**: The control plane is already a critical component with root access to the cluster

## Persistence

The configuration in `/etc/ssh/sshd_config.d/99-allow-forwarding.conf` persists across reboots. However, MicroOS uses transactional updates, so major system updates might reset this configuration. Check and reapply if needed after system updates.