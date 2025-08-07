# VPN Access for Private K3s Cluster

## Option 1: Tailscale (Easiest)

Install on your local machine and each node:
```bash
# On each node
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# Now SSH directly via Tailscale IPs
ssh root@[tailscale-ip]
```

## Option 2: WireGuard

1. Install WireGuard on one node as VPN server
2. Configure peers for your devices
3. Access all private IPs through VPN

## Option 3: Hetzner Cloud Network VPN

Use Hetzner's native VPN solution to access private network directly.

## Option 4: Bastion Host

Create a minimal CAX11 instance:
```hcl
resource "hcloud_server" "bastion" {
  name        = "k3s-bastion"
  server_type = "cax11"
  location    = "nbg1"
  image       = data.hcloud_image.ubuntu.id
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  
  network {
    network_id = hcloud_network.k3s.id
    ip         = "10.0.0.2"
  }
}
```

Then SSH through it:
```bash
# One-liner
ssh -J root@bastion.public.ip root@10.255.0.101

# Or add to ~/.ssh/config
Host bastion
  HostName bastion.public.ip
  User root

Host 10.255.0.* 10.0.0.*
  ProxyJump bastion
  User root
```

Cost: ~€3.79/month for CAX11 bastion