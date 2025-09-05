#!/bin/bash
# ArgoCD Installation Script for TravelSpirit K3s Cluster
# This script follows ArgoCD best practices for production deployment

set -euo pipefail

# Configuration
NAMESPACE="argocd"
CHART_VERSION="7.6.8"  # Pin to stable version
RELEASE_NAME="argocd"
VALUES_FILE="./values.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed or not in PATH"
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    fi
    
    # Check if values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        error "Values file not found: $VALUES_FILE"
    fi
    
    success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        warn "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        success "Namespace $NAMESPACE created"
    fi
}

# Add ArgoCD Helm repository
add_helm_repo() {
    log "Adding ArgoCD Helm repository..."
    
    if helm repo list | grep -q "argo.*https://argoproj.github.io/argo-helm"; then
        log "ArgoCD Helm repo already added"
    else
        helm repo add argo https://argoproj.github.io/argo-helm
        success "ArgoCD Helm repository added"
    fi
    
    helm repo update
    log "Helm repositories updated"
}

# Install or upgrade ArgoCD
install_argocd() {
    log "Installing/upgrading ArgoCD..."
    
    # Check if release exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        log "Upgrading existing ArgoCD installation..."
        helm upgrade "$RELEASE_NAME" argo/argo-cd \
            --namespace "$NAMESPACE" \
            --version "$CHART_VERSION" \
            --values "$VALUES_FILE" \
            --wait \
            --timeout 10m
        success "ArgoCD upgraded successfully"
    else
        log "Installing ArgoCD..."
        helm install "$RELEASE_NAME" argo/argo-cd \
            --namespace "$NAMESPACE" \
            --version "$CHART_VERSION" \
            --values "$VALUES_FILE" \
            --wait \
            --timeout 10m \
            --create-namespace
        success "ArgoCD installed successfully"
    fi
}

# Wait for ArgoCD to be ready
wait_for_argocd() {
    log "Waiting for ArgoCD to be ready..."
    
    # Wait for deployments
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-application-controller \
        deployment/argocd-server \
        deployment/argocd-repo-server \
        -n "$NAMESPACE"
    
    # Wait for ApplicationSet controller if enabled
    if kubectl get deployment argocd-applicationset-controller -n "$NAMESPACE" &> /dev/null; then
        kubectl wait --for=condition=available --timeout=300s \
            deployment/argocd-applicationset-controller \
            -n "$NAMESPACE"
    fi
    
    success "ArgoCD is ready!"
}

# Get ArgoCD initial admin password
get_admin_password() {
    log "Retrieving ArgoCD admin password..."
    
    # Wait for the secret to be created
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if kubectl get secret argocd-initial-admin-secret -n "$NAMESPACE" &> /dev/null; then
            break
        fi
        sleep 5
        ((retries--))
    done
    
    if [[ $retries -eq 0 ]]; then
        warn "ArgoCD initial admin secret not found. Password might be set via values.yaml"
        return
    fi
    
    local password
    password=$(kubectl get secret argocd-initial-admin-secret -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 -d)
    
    success "ArgoCD Admin Credentials:"
    echo -e "${GREEN}Username: admin${NC}"
    echo -e "${GREEN}Password: $password${NC}"
    echo ""
    warn "Please change the admin password after first login!"
}

# Display access information
display_access_info() {
    log "Getting access information..."
    
    # Get ingress information
    if kubectl get ingress -n "$NAMESPACE" | grep -q argocd; then
        local ingress_host
        ingress_host=$(kubectl get ingress argocd-server -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "N/A")
        success "ArgoCD Web UI: https://$ingress_host"
    fi
    
    # Get service information for port forwarding alternative
    success "Alternative access via port forwarding:"
    echo -e "${GREEN}kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443${NC}"
    echo -e "${GREEN}Then access: https://localhost:8080${NC}"
}

# Install ArgoCD CLI (optional)
install_argocd_cli() {
    log "Checking for ArgoCD CLI..."
    
    if command -v argocd &> /dev/null; then
        log "ArgoCD CLI already installed: $(argocd version --client --short)"
        return
    fi
    
    warn "ArgoCD CLI not found. Install it manually:"
    echo "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
    echo "rm argocd-linux-amd64"
}

# Main execution
main() {
    success "Starting ArgoCD installation..."
    
    check_prerequisites
    create_namespace
    add_helm_repo
    install_argocd
    wait_for_argocd
    get_admin_password
    display_access_info
    install_argocd_cli
    
    success "ArgoCD installation completed!"
    echo ""
    log "Next steps:"
    echo "1. Access ArgoCD UI and change the admin password"
    echo "2. Configure RBAC and user management"
    echo "3. Set up your first Application or ApplicationSet"
    echo "4. Configure repository access credentials if needed"
}

# Run main function
main "$@"