#!/bin/bash

# Simple kubectl version aliases
# Add to your ~/.zshrc or ~/.bashrc:
# source ~/projects/terraform-hcloud-kube-hetzner/scripts/kubectl-aliases.sh

# Define kubectl versions
alias kubectl-1.34="/opt/homebrew/bin/kubectl"
alias kubectl-1.32="/usr/local/bin/kubectl"
alias kubectl-latest="/opt/homebrew/bin/kubectl"
alias kubectl-stable="/usr/local/bin/kubectl"

# Default to stable version for k3s compatibility
alias kubectl="/usr/local/bin/kubectl"

# Port-forward aliases using compatible kubectl
alias kubectl-pf='kubectl port-forward'
alias kubectl-pf-postgres='kubectl --kubeconfig barry-kubeconfig.yaml port-forward -n postgres pod/postgres-cluster-1'

echo "✅ kubectl aliases loaded:"
echo "  kubectl-1.34  → v1.34.0 (homebrew)"  
echo "  kubectl-1.32  → v1.32.2 (docker/stable)"
echo "  kubectl-latest → v1.34.0 (homebrew)"
echo "  kubectl-stable → v1.32.2 (docker)"
echo "  kubectl       → v1.32.2 (default for k3s compatibility)"
echo ""
echo "💡 Port-forward shortcuts:"
echo "  kubectl-pf-postgres 5439:5432  # Start postgres port-forward"