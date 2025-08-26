# Configuring Terraform to Use Bastion Host

## Overview
This guide explains how to configure Terraform to use the control plane node (195.201.28.253) as a bastion host for all SSH connections, ensuring reliable access even when IPv6 connectivity fails.

## Option 1: SSH Config File (Recommended)

### 1. Create SSH Config
Add this to your `~/.ssh/config`:

```ssh
# Control plane with IPv4
Host k3s-control
    HostName 195.201.28.253
    User root
    Port 22
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Worker nodes via bastion
Host 10.0.0.*
    User root
    ProxyJump k3s-control
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host 10.255.0.*
    User root
    ProxyJump k3s-control
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# IPv6 addresses via bastion (when local IPv6 fails)
Host 2a01:4f8:*
    User root
    ProxyJump k3s-control
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### 2. No Terraform Changes Needed
With this SSH config, Terraform will automatically use the bastion for all matching hosts.

## Option 2: Terraform Module Variables

### 1. Add Bastion Variables
Create `bastion.tf`:

```hcl
variable "use_bastion" {
  description = "Use control plane as bastion host"
  type        = bool
  default     = true
}

variable "bastion_host" {
  description = "Bastion host IP address"
  type        = string
  default     = "195.201.28.253"
}

variable "bastion_user" {
  description = "Bastion host SSH user"
  type        = string
  default     = "root"
}

variable "bastion_private_key" {
  description = "Private key for bastion host"
  type        = string
  default     = ""  # Uses same key as nodes by default
}

locals {
  bastion_private_key = var.bastion_private_key != "" ? var.bastion_private_key : var.ssh_private_key
}
```

### 2. Modify Module Connection Blocks
Update `modules/host/main.tf` to add bastion support to all connection blocks:

```hcl
connection {
  type           = "ssh"
  user           = "root"
  private_key    = var.ssh_private_key
  agent_identity = local.ssh_agent_identity
  host           = coalesce(self.ipv4_address, self.ipv6_address, try(one(self.network).ip, null))
  port           = var.ssh_port
  
  # Add bastion configuration
  bastion_host        = var.use_bastion ? var.bastion_host : ""
  bastion_user        = var.use_bastion ? var.bastion_user : ""
  bastion_private_key = var.use_bastion ? local.bastion_private_key : ""
}
```

### 3. Pass Variables to Module
In `kube.tf`:

```hcl
module "kube-hetzner" {
  # ... existing configuration ...
  
  # Add bastion configuration
  use_bastion         = true
  bastion_host        = "195.201.28.253"
  bastion_user        = "root"
  bastion_private_key = file("~/.ssh/id_rsa")
}
```

## Option 3: Environment-Based Configuration

### 1. Use Environment Variable
Set an environment variable to control bastion usage:

```bash
export TF_VAR_use_bastion=true
export TF_VAR_bastion_host="195.201.28.253"
```

### 2. Conditional Connection
In Terraform modules, use conditional logic:

```hcl
resource "null_resource" "example" {
  # Use direct connection when node has IPv4
  dynamic "connection" {
    for_each = var.use_bastion ? [] : [1]
    content {
      type        = "ssh"
      user        = "root"
      private_key = var.ssh_private_key
      host        = local.node_ip
    }
  }
  
  # Use bastion when needed
  dynamic "connection" {
    for_each = var.use_bastion ? [1] : []
    content {
      type                = "ssh"
      user                = "root"
      private_key         = var.ssh_private_key
      host                = local.node_ip
      bastion_host        = var.bastion_host
      bastion_user        = "root"
      bastion_private_key = var.ssh_private_key
    }
  }
}
```

## Testing the Configuration

### 1. Test SSH Access
```bash
# Direct test
ssh root@195.201.28.253 "echo 'Control plane works'"

# Via bastion test
ssh -J root@195.201.28.253 root@10.0.0.101 "echo 'Worker via bastion works'"
```

### 2. Test Terraform Connection
```bash
# Plan with bastion
terraform plan -var="use_bastion=true"

# Apply with bastion
terraform apply -var="use_bastion=true" -auto-approve
```

## Troubleshooting

### Common Issues

1. **"administratively prohibited" error**
   - SSH TCP forwarding is disabled on bastion
   - Fix: Enable `AllowTcpForwarding yes` in sshd_config

2. **Connection timeout**
   - Firewall blocking SSH
   - Fix: Ensure port 22 is open on bastion

3. **Host key verification failed**
   - Add `StrictHostKeyChecking no` to SSH config
   - Or manually accept host keys first

### Debug Commands
```bash
# Test bastion connectivity
ssh -v root@195.201.28.253 "echo test"

# Test jump host
ssh -v -J root@195.201.28.253 root@10.0.0.101 "echo test"

# Check SSH forwarding on bastion
ssh root@195.201.28.253 "sshd -T | grep tcpforwarding"
```

## Security Considerations

Using a bastion host:
- **Pros**: Centralized access control, audit logging, reduced attack surface
- **Cons**: Single point of failure, requires hardening

Recommendations:
1. Use SSH keys only (disable password auth)
2. Implement fail2ban on bastion
3. Log all SSH sessions
4. Regularly update the bastion host
5. Consider using SSH certificates instead of keys