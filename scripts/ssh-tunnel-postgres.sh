#!/bin/bash

# SSH tunnel script for PostgreSQL access
# This creates a tunnel through the control plane node

CONTROL_PLANE_IP="91.98.16.104"
LOCAL_PORT="5436"
SSH_USER="root"

echo "🔐 Setting up SSH tunnel for PostgreSQL"
echo "📍 Local port: $LOCAL_PORT"
echo "🎯 Remote: postgres-rw.postgres.svc.cluster.local:5432"
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
echo "Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create SSH tunnel
ssh -L $LOCAL_PORT:postgres-rw.postgres.svc.cluster.local:5432 \
    -N -v $SSH_USER@$CONTROL_PLANE_IP