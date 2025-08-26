#!/bin/bash

# Deployment script for K3s cluster
# Can be used locally or in CI/CD pipelines

set -e

# Configuration
CLUSTER_NAME="k3s-cluster"
KUBECONFIG_FILE="k3s-cluster_kubeconfig.yaml"
CONTROL_PLANE_IP="2a01:4f8:1c1b:f096::1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check if running in CI or locally
check_environment() {
    if [ "$CI" = "true" ]; then
        log_info "Running in CI environment"
        # In CI, kubeconfig should be set via KUBE_CONFIG secret
        if [ -z "$KUBE_CONFIG" ]; then
            log_error "KUBE_CONFIG environment variable not set"
            exit 1
        fi
        echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
        export KUBECONFIG=/tmp/kubeconfig
    else
        log_info "Running locally"
        # Check for local kubeconfig
        if [ -f "$KUBECONFIG_FILE" ]; then
            export KUBECONFIG="$KUBECONFIG_FILE"
            log_info "Using kubeconfig: $KUBECONFIG_FILE"
        else
            log_error "Kubeconfig file not found: $KUBECONFIG_FILE"
            log_info "Trying to connect via SSH..."
            USE_SSH=true
        fi
    fi
}

# Verify cluster connectivity
verify_cluster() {
    log_info "Verifying cluster connectivity..."
    
    if [ "$USE_SSH" = "true" ]; then
        if ssh -6 -o ConnectTimeout=5 root@$CONTROL_PLANE_IP "kubectl get nodes" > /dev/null 2>&1; then
            log_info "Successfully connected to cluster via SSH"
            SSH_PREFIX="ssh -6 root@$CONTROL_PLANE_IP"
        else
            log_error "Failed to connect to cluster via SSH"
            exit 1
        fi
    else
        if kubectl get nodes > /dev/null 2>&1; then
            log_info "Successfully connected to cluster"
        else
            log_error "Failed to connect to cluster"
            log_info "Cluster details:"
            kubectl config current-context || true
            kubectl config view --minify || true
            exit 1
        fi
    fi
}

# Deploy application
deploy_app() {
    local manifest_path=$1
    local namespace=${2:-default}
    
    if [ -z "$manifest_path" ]; then
        log_error "Manifest path not provided"
        exit 1
    fi
    
    if [ ! -f "$manifest_path" ] && [ ! -d "$manifest_path" ]; then
        log_error "Manifest not found: $manifest_path"
        exit 1
    fi
    
    log_info "Deploying to namespace: $namespace"
    
    # Create namespace if it doesn't exist
    if [ "$USE_SSH" = "true" ]; then
        $SSH_PREFIX "kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -"
    else
        kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Apply manifests
    log_info "Applying manifests from: $manifest_path"
    if [ "$USE_SSH" = "true" ]; then
        # For SSH deployment, we need to copy files first
        scp -6 -r "$manifest_path" root@[$CONTROL_PLANE_IP]:/tmp/deploy/
        $SSH_PREFIX "kubectl apply -f /tmp/deploy/$(basename $manifest_path) -n $namespace"
        $SSH_PREFIX "rm -rf /tmp/deploy"
    else
        kubectl apply -f "$manifest_path" -n "$namespace"
    fi
    
    log_info "Deployment initiated"
}

# Wait for deployment
wait_for_deployment() {
    local deployment_name=$1
    local namespace=${2:-default}
    local timeout=${3:-300}
    
    log_info "Waiting for deployment: $deployment_name in namespace: $namespace"
    
    if [ "$USE_SSH" = "true" ]; then
        $SSH_PREFIX "kubectl rollout status deployment/$deployment_name -n $namespace --timeout=${timeout}s"
    else
        kubectl rollout status deployment/$deployment_name -n $namespace --timeout=${timeout}s
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Deployment $deployment_name is ready"
    else
        log_error "Deployment $deployment_name failed or timed out"
        # Show pod status for debugging
        if [ "$USE_SSH" = "true" ]; then
            $SSH_PREFIX "kubectl get pods -n $namespace -l app=$deployment_name"
        else
            kubectl get pods -n $namespace -l app=$deployment_name
        fi
        exit 1
    fi
}

# Get deployment status
get_status() {
    local namespace=${1:-default}
    
    log_info "Getting deployment status for namespace: $namespace"
    
    if [ "$USE_SSH" = "true" ]; then
        $SSH_PREFIX "kubectl get all -n $namespace"
        echo ""
        $SSH_PREFIX "kubectl get ingress -n $namespace"
    else
        kubectl get all -n $namespace
        echo ""
        kubectl get ingress -n $namespace
    fi
}

# Main execution
main() {
    local action=${1:-deploy}
    local manifest_path=${2:-deployments/}
    local namespace=${3:-default}
    local deployment_name=${4:-}
    
    check_environment
    verify_cluster
    
    case $action in
        deploy)
            deploy_app "$manifest_path" "$namespace"
            if [ ! -z "$deployment_name" ]; then
                wait_for_deployment "$deployment_name" "$namespace"
            fi
            get_status "$namespace"
            ;;
        status)
            get_status "$namespace"
            ;;
        rollback)
            if [ -z "$deployment_name" ]; then
                log_error "Deployment name required for rollback"
                exit 1
            fi
            log_info "Rolling back deployment: $deployment_name"
            if [ "$USE_SSH" = "true" ]; then
                $SSH_PREFIX "kubectl rollout undo deployment/$deployment_name -n $namespace"
            else
                kubectl rollout undo deployment/$deployment_name -n $namespace
            fi
            wait_for_deployment "$deployment_name" "$namespace"
            ;;
        logs)
            if [ -z "$deployment_name" ]; then
                log_error "Deployment name required for logs"
                exit 1
            fi
            log_info "Getting logs for deployment: $deployment_name"
            if [ "$USE_SSH" = "true" ]; then
                $SSH_PREFIX "kubectl logs -n $namespace -l app=$deployment_name --tail=100"
            else
                kubectl logs -n $namespace -l app=$deployment_name --tail=100
            fi
            ;;
        *)
            echo "Usage: $0 [action] [manifest_path] [namespace] [deployment_name]"
            echo ""
            echo "Actions:"
            echo "  deploy   - Deploy application (default)"
            echo "  status   - Get deployment status"
            echo "  rollback - Rollback deployment"
            echo "  logs     - Get deployment logs"
            echo ""
            echo "Examples:"
            echo "  $0 deploy deployments/example-app.yaml travelspirit-apps example-app"
            echo "  $0 status travelspirit-apps"
            echo "  $0 rollback travelspirit-apps example-app"
            echo "  $0 logs travelspirit-apps example-app"
            exit 1
            ;;
    esac
    
    log_info "Operation completed successfully"
}

# Run main function
main "$@"