#!/bin/bash

# PostgreSQL SSH Tunnel for DBeaver
# Bypasses kubectl port-forward network namespace issues

CONTROL_PLANE_IP="91.98.16.104"
LOCAL_PORT="5443"
REMOTE_HOST="postgres-cluster-1.postgres.svc.cluster.local"
REMOTE_PORT="5432"
SSH_USER="root"

echo "🔐 Starting PostgreSQL SSH Tunnel"
echo "📍 Local port: $LOCAL_PORT"
echo "🎯 Remote: $REMOTE_HOST:$REMOTE_PORT"
echo "🌉 Via: $SSH_USER@$CONTROL_PLANE_IP"
echo ""
echo "💡 Configure DBeaver with:"
echo "   Host: localhost"
echo "   Port: $LOCAL_PORT"
echo "   Database: testing"
echo "   User: testuser"
echo "   Password: test123"
echo "   SSL Mode: disable"
echo ""
echo "Press Ctrl+C to stop tunnel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cleanup() {
    echo ""
    echo "🧹 Closing SSH tunnel..."
    exit 0
}

trap cleanup INT TERM

# Create SSH tunnel with auto-retry
while true; do
    echo "$(date '+%H:%M:%S') 🔄 Creating SSH tunnel..."
    
    # Use direct pod IP instead of service name for more reliability
    POD_IP=$(ssh -q $SSH_USER@$CONTROL_PLANE_IP "kubectl get pod -n postgres postgres-cluster-1 -o jsonpath='{.status.podIP}'")
    
    if [[ -n "$POD_IP" ]]; then
        echo "$(date '+%H:%M:%S') 📍 Using postgres pod IP: $POD_IP"
        ssh -L $LOCAL_PORT:$POD_IP:$REMOTE_PORT -N -v $SSH_USER@$CONTROL_PLANE_IP
    else
        echo "$(date '+%H:%M:%S') 🔄 Using service name: $REMOTE_HOST"
        ssh -L $LOCAL_PORT:$REMOTE_HOST:$REMOTE_PORT -N -v $SSH_USER@$CONTROL_PLANE_IP
    fi
    
    echo "$(date '+%H:%M:%S') ⚠️  SSH tunnel died, restarting in 3 seconds..."
    sleep 3
done