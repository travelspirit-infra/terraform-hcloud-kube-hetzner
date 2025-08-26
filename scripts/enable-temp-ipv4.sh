#!/bin/bash

# Script to temporarily enable IPv4 on a node for WireGuard access

source hcloud-env.sh

echo "Temporarily enabling IPv4 for WireGuard access..."

# Create temporary IPv4
IPV4_ID=$(hcloud primary-ip create --type ipv4 --datacenter nbg1-dc3 --name wireguard-temp-access -o json | jq -r '.primary_ip.id')
IPV4_ADDR=$(hcloud primary-ip describe $IPV4_ID -o json | jq -r '.ip')

echo "Created temporary IPv4: $IPV4_ADDR (ID: $IPV4_ID)"
echo ""
echo "To assign to a node (requires server restart):"
echo "  1. hcloud server poweroff k3s-cluster-agent-nbg1-bqb"
echo "  2. hcloud primary-ip assign $IPV4_ID --server k3s-cluster-agent-nbg1-bqb"  
echo "  3. hcloud server poweron k3s-cluster-agent-nbg1-bqb"
echo ""
echo "Update your WireGuard config:"
echo "  Endpoint = $IPV4_ADDR:30382"
echo ""
echo "When done, cleanup:"
echo "  hcloud primary-ip unassign $IPV4_ID"
echo "  hcloud primary-ip delete $IPV4_ID"