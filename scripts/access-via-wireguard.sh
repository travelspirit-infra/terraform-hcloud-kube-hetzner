#!/bin/bash

# Helper script to access K3s cluster via WireGuard when IPv6 fails

echo "=== K3s Cluster Access via WireGuard ==="
echo ""
echo "1. Connect to WireGuard:"
echo "   sudo wg-quick up k3s-hetzner-wg"
echo ""
echo "2. Access nodes directly via internal IPs:"
echo "   ssh root@10.255.0.101  # Control plane"
echo "   ssh root@10.0.0.101     # Worker node 1" 
echo "   ssh root@10.0.0.102     # Worker node 2"
echo ""
echo "3. Use kubectl via internal network:"
echo "   export KUBECONFIG=~/.kube/k3s-internal"
echo "   kubectl --server=https://10.255.0.101:6443 get nodes"
echo ""
echo "4. Access services in cluster:"
echo "   - Any ClusterIP service is accessible"
echo "   - Use internal DNS names"
echo ""

# Quick connectivity test
if command -v wg &> /dev/null; then
    echo "Current WireGuard status:"
    sudo wg show 2>/dev/null | grep -E "interface:|endpoint:|latest handshake:" || echo "  Not connected"
fi