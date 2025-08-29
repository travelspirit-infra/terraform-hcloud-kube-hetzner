#!/bin/bash

# Auto-reconnecting port-forward script for DBeaver
# Usage: ./dbeaver-port-forward.sh [local_port] [remote_port]

LOCAL_PORT=${1:-5435}
REMOTE_PORT=${2:-5432}
KUBECONFIG_FILE="barry-kubeconfig.yaml"
NAMESPACE="postgres"
POD="postgres-cluster-1"

echo "🚀 Starting auto-reconnecting port-forward for DBeaver"
echo "📍 Local port: $LOCAL_PORT"
echo "🎯 Remote port: $REMOTE_PORT"
echo "🔧 Pod: $NAMESPACE/$POD"
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
    echo "🧹 Cleaning up port-forward processes..."
    pkill -f "port-forward.*$LOCAL_PORT:$REMOTE_PORT" 2>/dev/null
    exit 0
}

trap cleanup INT TERM

while true; do
    echo "$(date '+%H:%M:%S') 🔄 Starting port-forward..."
    
    kubectl --kubeconfig "$KUBECONFIG_FILE" port-forward \
        -n "$NAMESPACE" "pod/$POD" "$LOCAL_PORT:$REMOTE_PORT" \
        2>&1 | while read line; do
            if [[ "$line" == *"Forwarding from"* ]]; then
                echo "$(date '+%H:%M:%S') ✅ Port-forward active: $line"
            elif [[ "$line" == *"error"* || "$line" == *"Error"* ]]; then
                echo "$(date '+%H:%M:%S') ❌ Error: $line"
            fi
        done
    
    echo "$(date '+%H:%M:%S') ⚠️  Port-forward died, restarting in 3 seconds..."
    sleep 3
done