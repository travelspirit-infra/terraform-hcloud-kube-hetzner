#!/bin/bash
set -e

echo "Installing Harbor registry..."

# Add Harbor Helm repository
helm repo add harbor https://helm.goharbor.io
helm repo update

# Create namespace
kubectl create namespace harbor --dry-run=client -o yaml | kubectl apply -f -

# Install Harbor
helm upgrade --install harbor harbor/harbor \
  --namespace harbor \
  --values values.yaml \
  --timeout 10m \
  --wait

echo "Harbor installation completed!"
echo "Access Harbor at: https://harbor.k8s.travelspirit.cloud"
echo "Admin credentials: admin / Harbor12345!"