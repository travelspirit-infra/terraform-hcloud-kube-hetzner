#!/bin/bash
# Setup script for GitHub Actions Runner Controller on K3s Hetzner cluster
# This script installs ARC with ARM64 support for self-hosted GitHub Actions runners

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ARC_VERSION="0.28.1"  # Latest stable version
NAMESPACE="actions-runner-system"
HELM_RELEASE_NAME="actions-runner-controller"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed. Please install helm v3 first."
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check if cert-manager is installed
    if ! kubectl get namespace cert-manager &> /dev/null; then
        log_warn "cert-manager namespace not found. Checking if cert-manager is installed..."
        if ! kubectl get crd certificates.cert-manager.io &> /dev/null; then
            log_error "cert-manager is required but not installed."
            log_info "Install cert-manager with: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml"
            exit 1
        fi
    fi
    
    log_info "Prerequisites check passed."
}

check_github_token() {
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log_error "GITHUB_TOKEN environment variable is not set."
        log_info "Please set your GitHub Personal Access Token:"
        log_info "  export GITHUB_TOKEN='your-github-pat-token'"
        log_info ""
        log_info "Token scopes required:"
        log_info "  - For repository runners: 'repo' scope"
        log_info "  - For organization runners: 'admin:org' scope"
        exit 1
    fi
    log_info "GitHub token found."
}

create_namespace() {
    log_info "Creating namespace..."
    kubectl apply -f k8s-manifests/actions-runner-controller/namespace.yaml
}

create_github_secret() {
    log_info "Creating GitHub token secret..."
    
    # Delete existing secret if it exists
    kubectl delete secret controller-manager -n $NAMESPACE --ignore-not-found=true
    
    # Create new secret
    kubectl create secret generic controller-manager \
        -n $NAMESPACE \
        --from-literal=github_token="$GITHUB_TOKEN"
    
    log_info "GitHub token secret created."
}

install_arc() {
    log_info "Installing Actions Runner Controller..."
    
    # Add helm repository
    helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
    helm repo update
    
    # Install or upgrade ARC
    helm upgrade --install $HELM_RELEASE_NAME \
        actions-runner-controller/actions-runner-controller \
        --namespace $NAMESPACE \
        --version $ARC_VERSION \
        --values k8s-manifests/actions-runner-controller/values.yaml \
        --wait \
        --timeout 5m
    
    log_info "Actions Runner Controller installed."
}

wait_for_deployment() {
    log_info "Waiting for ARC controller to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/actions-runner-controller -n $NAMESPACE
    
    log_info "Waiting for webhook to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/actions-runner-controller-webhook -n $NAMESPACE || true
}

verify_installation() {
    log_info "Verifying installation..."
    
    echo ""
    log_info "ARC Controller Status:"
    kubectl get deployment -n $NAMESPACE
    
    echo ""
    log_info "ARC Pods:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    log_info "CRDs installed:"
    kubectl get crd | grep actions.summerwind.dev
}

deploy_runners() {
    read -p "Do you want to deploy the runner configuration now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deploying runner configuration..."
        kubectl apply -f k8s-manifests/actions-runner-controller/runner-deployment.yaml
        
        echo ""
        log_info "Waiting for runners to be ready..."
        sleep 10
        
        echo ""
        log_info "Runner status:"
        kubectl get runnerdeployment -n $NAMESPACE
        kubectl get runners -n $NAMESPACE
    else
        log_info "Skipping runner deployment."
        log_info "You can deploy runners later with:"
        log_info "  kubectl apply -f k8s-manifests/actions-runner-controller/runner-deployment.yaml"
    fi
}

print_next_steps() {
    echo ""
    echo "========================================"
    log_info "Actions Runner Controller setup complete!"
    echo "========================================"
    echo ""
    log_info "Next steps:"
    echo "1. Check runner status:"
    echo "   kubectl get runners -n $NAMESPACE"
    echo ""
    echo "2. View runner logs:"
    echo "   kubectl logs -n $NAMESPACE -l app=github-runner"
    echo ""
    echo "3. Monitor autoscaling:"
    echo "   kubectl get hra -n $NAMESPACE"
    echo ""
    echo "4. Update your GitHub Actions workflows to use self-hosted runners:"
    echo "   runs-on: [self-hosted, linux, arm64, hetzner]"
    echo ""
    echo "5. To uninstall ARC:"
    echo "   helm uninstall $HELM_RELEASE_NAME -n $NAMESPACE"
    echo "   kubectl delete namespace $NAMESPACE"
}

# Main execution
main() {
    log_info "Starting GitHub Actions Runner Controller setup..."
    
    check_prerequisites
    check_github_token
    create_namespace
    create_github_secret
    install_arc
    wait_for_deployment
    verify_installation
    deploy_runners
    print_next_steps
}

# Run main function
main "$@"