#!/bin/bash

# Stable port-forward script using compatible kubectl version
# Usage: ./stable-port-forward.sh [local_port] [target_port]

LOCAL_PORT=${1:-5438}
TARGET_PORT=${2:-5432}
KUBECONFIG_FILE="barry-kubeconfig.yaml"
NAMESPACE="postgres"
POD="postgres-cluster-1"

# Use the older kubectl version that's compatible with k3s v1.33.3
KUBECTL_CMD="/usr/local/bin/kubectl"

if [[ ! -x "$KUBECTL_CMD" ]]; then
    echo "❌ Compatible kubectl not found at $KUBECTL_CMD"
    echo "💡 Current kubectl version: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    echo "💡 Need kubectl v1.32.x or v1.33.x for k3s v1.33.3+k3s1"
    exit 1
fi

echo "🚀 Starting stable port-forward for DBeaver"
echo "📍 kubectl: $KUBECTL_CMD"
echo "📍 Version: $($KUBECTL_CMD version --client --short 2>/dev/null || echo "v1.32.2")"
echo "📍 Local port: $LOCAL_PORT"
echo "🎯 Target: $NAMESPACE/$POD:$TARGET_PORT"
echo ""
echo "💡 Configure DBeaver with:"
echo "   Host: localhost"
echo "   Port: $LOCAL_PORT"
echo "   Database: testing"
echo "   User: testuser"
echo "   Password: test123"
echo "   SSL Mode: disable"
echo ""
echo "Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cleanup() {
    echo ""
    echo "🧹 Stopping port-forward..."
    pkill -f "kubectl.*port-forward.*$LOCAL_PORT:$TARGET_PORT" 2>/dev/null
    exit 0
}

trap cleanup INT TERM

# Start stable port-forward
exec $KUBECTL_CMD --kubeconfig "$KUBECONFIG_FILE" port-forward \
    -n "$NAMESPACE" "pod/$POD" "$LOCAL_PORT:$TARGET_PORT"