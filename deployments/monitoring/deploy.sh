#!/bin/bash

set -e

echo "======================================"
echo "Deploying OpenTelemetry Monitoring Stack"
echo "======================================"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
KUBECONFIG_PATH="${SCRIPT_DIR}/../../k3s-cluster_kubeconfig.yaml"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Error: Kubeconfig not found at $KUBECONFIG_PATH"
    echo "Please ensure terraform has been applied and kubeconfig is generated"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

echo ""
echo "Step 1: Checking cluster connectivity..."
if ! kubectl get nodes &>/dev/null; then
    echo "Error: Cannot connect to cluster. Please check if cluster is running."
    echo "You may need to update the kubeconfig with the correct IPv6 address."
    exit 1
fi

echo "✓ Cluster is accessible"
kubectl get nodes

echo ""
echo "Step 2: Deploying monitoring stack using Kustomize..."
kubectl apply -k "$SCRIPT_DIR"

echo ""
echo "Step 3: Waiting for deployments to be ready..."
kubectl wait --for=condition=ready pod -l app=node-exporter -n monitoring --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=otel-collector -n monitoring --timeout=120s || true

echo ""
echo "Step 4: Checking deployment status..."
echo ""
echo "Node Exporter DaemonSet:"
kubectl get daemonset -n monitoring node-exporter

echo ""
echo "OpenTelemetry Collector Deployment:"
kubectl get deployment -n monitoring otel-collector

echo ""
echo "All Pods in monitoring namespace:"
kubectl get pods -n monitoring -o wide

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "To check metrics collection:"
echo "  kubectl logs -n monitoring -l app=otel-collector --tail=50"
echo ""
echo "To check node exporter metrics:"
echo "  kubectl port-forward -n monitoring daemonset/node-exporter 9100:9100"
echo "  Then visit: http://localhost:9100/metrics"
echo ""
echo "To check OTel collector metrics:"
echo "  kubectl port-forward -n monitoring deployment/otel-collector 8888:8888"
echo "  Then visit: http://localhost:8888/metrics"
echo ""
echo "Metrics are being sent to: https://prometheus.travelspirit.cloud"