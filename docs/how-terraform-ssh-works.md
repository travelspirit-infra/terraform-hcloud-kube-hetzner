# How Terraform SSH Connections Work

## The Basics

Terraform uses **SSH (Secure Shell)** to connect to Linux servers, just like when you type `ssh root@server`. 

## Connection Block

Every time Terraform needs to run commands on a server, it uses a `connection` block:

```hcl
connection {
  type        = "ssh"              # Connection type (always SSH for Linux)
  user        = "root"              # Username to login as
  private_key = file("~/.ssh/id_rsa")  # Your SSH private key
  host        = "195.201.28.253"   # Server IP address
  port        = 22                  # SSH port (default 22)
}
```

## What Terraform Does

### 1. Creates Resources
First, Terraform creates the server at Hetzner:
```hcl
resource "hcloud_server" "server" {
  name        = "my-server"
  server_type = "cax21"
  image       = "ubuntu-24.04"
}
```

### 2. Waits for SSH
After creating the server, Terraform waits for SSH to be ready (server booted, SSH daemon running).

### 3. Connects via SSH
Terraform then SSHs to the server using:
- The IP address Hetzner assigned (IPv4 or IPv6)
- Your SSH private key for authentication
- Root user (usually)

### 4. Runs Provisioners
Once connected, Terraform can:
- **Upload files** (`file` provisioner)
- **Run commands** (`remote-exec` provisioner)
- **Execute scripts** (`local-exec` provisioner)

## Real Example from Your Module

```hcl
# This is what happens in your kube-hetzner module:

# 1. Connection configuration
connection {
  user        = "root"
  private_key = var.ssh_private_key      # Your ~/.ssh/id_rsa content
  host        = coalesce(                # Pick first available:
    hcloud_server.server.ipv4_address,   # 1st choice: IPv4
    hcloud_server.server.ipv6_address,   # 2nd choice: IPv6  
    try(one(hcloud_server.server.network).ip, null)  # 3rd: Private IP
  )
  port        = var.ssh_port             # Default: 22
}

# 2. Upload a file
provisioner "file" {
  content     = "some config"
  destination = "/etc/config.yaml"
}

# 3. Run commands
provisioner "remote-exec" {
  inline = [
    "systemctl restart k3s",
    "kubectl get nodes"
  ]
}
```

## Current Situation in Your Cluster

```
Your Machine (Terraform runs here)
    |
    ├──[SSH over IPv4]──> Control Plane (195.201.28.253)  ✅ Works
    |
    ├──[SSH over IPv6]──> Worker 1 (2a01:4f8:1c1a:47f9::1)  ❌ Fails when IPv6 down
    |
    └──[SSH over IPv6]──> Worker 2 (2a01:4f8:1c1c:86d8::1)  ❌ Fails when IPv6 down
```

## How Terraform SSH Actually Runs

When you run `terraform apply`, here's what happens behind the scenes:

1. **Terraform reads the connection block**
2. **Builds an SSH command** like:
   ```bash
   ssh -i ~/.ssh/id_rsa \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -p 22 \
       root@2a01:4f8:1c1a:47f9::1 \
       "kubectl get nodes"
   ```
3. **Executes it from your machine**

## The IPv6 Problem

When your IPv6 connectivity fails:
- Terraform tries: `ssh root@2a01:4f8:1c1a:47f9::1`
- Your machine can't reach IPv6 addresses
- SSH connection fails
- Terraform provisioning fails

## Solutions

### 1. When IPv6 Works
Just run Terraform normally:
```bash
terraform apply
```

### 2. When IPv6 is Down
SSH to control plane and work from there:
```bash
ssh root@195.201.28.253
# Now you're inside the cluster network
# You can reach all nodes via private IPs
```

### 3. For Terraform When IPv6 is Down
Either:
- Wait for IPv6 to work again
- Add IPv4 addresses to worker nodes (costs €3/month each)
- Run Terraform from inside the cluster (control plane)

## Key Points

- **Terraform uses standard SSH** - Nothing special, just automated SSH
- **Needs direct connectivity** - Can't use jump hosts without module changes
- **Uses your SSH key** - Same key you use for manual SSH
- **Runs from your machine** - Unless you run Terraform elsewhere

Think of Terraform as a robot that types SSH commands for you!