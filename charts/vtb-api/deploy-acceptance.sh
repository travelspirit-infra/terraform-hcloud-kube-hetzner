#!/bin/bash

# Deploy VTB-API to Acceptance Environment on K3s
set -e

# Configuration
NAMESPACE="vtb-api-acceptance"
RELEASE_NAME="vtb-api-acceptance"
CHART_PATH="."
KUBECONFIG="../../../terraform-hcloud-kube-hetzner/k3s-cluster_kubeconfig.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Deploying VTB-API to Acceptance Environment${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm is not installed or not in PATH${NC}"
    exit 1
fi

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
    echo -e "${RED}❌ Kubeconfig not found at: $KUBECONFIG${NC}"
    exit 1
fi

export KUBECONFIG

echo -e "${YELLOW}📋 Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Connected to cluster${NC}"

echo -e "${YELLOW}📦 Creating namespace if it doesn't exist...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo -e "${YELLOW}📚 Adding Bitnami repository for PostgreSQL...${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo -e "${YELLOW}⬇️ Updating chart dependencies...${NC}"
helm dependency update "$CHART_PATH"

echo -e "${YELLOW}🔍 Validating Helm chart...${NC}"
helm lint "$CHART_PATH" --values values-acceptance.yaml

# Prompt for sensitive values
echo -e "${YELLOW}🔐 Setting up secrets...${NC}"
echo "Please provide the following credentials for the acceptance environment:"

read -p "Auth0 Domain (e.g., acceptance.eu.auth0.com): " AUTH0_DOMAIN
read -p "Auth0 Client ID: " AUTH0_CLIENT_ID
read -s -p "Auth0 Client Secret: " AUTH0_CLIENT_SECRET
echo

read -p "Stripe Public Key (test): " STRIPE_PUBLIC_KEY
read -s -p "Stripe Secret Key (test): " STRIPE_SECRET_KEY
echo

# Get latest image tag if not provided
if [ -z "$IMAGE_TAG" ]; then
    echo -e "${YELLOW}🏷️ Using 'latest' image tag. Set IMAGE_TAG environment variable to use specific tag.${NC}"
    IMAGE_TAG="latest"
fi

echo -e "${YELLOW}🚢 Deploying to Kubernetes...${NC}"
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --values values-acceptance.yaml \
    --set image.tag="$IMAGE_TAG" \
    --set-string auth0.domain="$AUTH0_DOMAIN" \
    --set-string auth0.clientId="$AUTH0_CLIENT_ID" \
    --set-string auth0.clientSecret="$AUTH0_CLIENT_SECRET" \
    --set-string stripe.publicKey="$STRIPE_PUBLIC_KEY" \
    --set-string stripe.secretKey="$STRIPE_SECRET_KEY" \
    --wait \
    --timeout=10m

echo -e "${GREEN}✅ Deployment successful!${NC}"

echo -e "${YELLOW}📊 Checking deployment status...${NC}"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

echo -e "${YELLOW}🌐 Getting service information...${NC}"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

echo -e "${YELLOW}📡 Getting ingress information...${NC}"
kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"

echo -e "${GREEN}🎉 VTB-API Acceptance Environment is ready!${NC}"
echo -e "${GREEN}🔗 URL: https://vtb-api-acceptance.k8s.travelspirit.cloud${NC}"
echo
echo -e "${YELLOW}📝 Useful commands:${NC}"
echo "  View logs:    kubectl logs -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME -f"
echo "  Port forward: kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 3000:3000"
echo "  Shell access: kubectl exec -it -n $NAMESPACE deployment/$RELEASE_NAME -- /bin/sh"
echo "  Uninstall:    helm uninstall $RELEASE_NAME -n $NAMESPACE"