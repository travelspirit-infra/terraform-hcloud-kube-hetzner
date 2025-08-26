# PostgreSQL Database Access Guide

## Overview

The K8s cluster runs a high-availability PostgreSQL cluster using **CloudNativePG** operator with 2 instances (1 primary, 1 standby).

## Database Connection Details

### **Cluster Information**
- **Cluster Name**: `postgres-cluster`
- **Namespace**: `postgres`
- **Database**: `appdb`
- **Username**: `appuser`
- **Password**: `AppUserP@ssw0rd456!`

### **Service Endpoints**
```bash
# Read-Write (Primary) - Use for writes and transactions
postgres-rw.postgres.svc.cluster.local:5432

# Read-Only (Standby) - Use for reports and queries
postgres-ro.postgres.svc.cluster.local:5432

# Any Instance (Load Balanced) - General purpose
postgres-r.postgres.svc.cluster.local:5432
```

## Connection Methods

### **Method 1: Port Forwarding (Recommended for Development)**

#### **For You (Current Access)**
```bash
# 1. SSH to control plane
ssh root@91.98.16.104

# 2. Set up port forward
kubectl port-forward -n postgres service/postgres-rw 5432:5432 --address 0.0.0.0

# 3. Connect from your local machine
psql -h 91.98.16.104 -p 5432 -U appuser -d appdb
# Password: AppUserP@ssw0rd456!
```

#### **For Other Developers**
```bash
# 1. Get the kubeconfig
# Contact admin for k3s-cluster_kubeconfig.yaml file

# 2. Set up kubectl access
export KUBECONFIG=./k3s-cluster_kubeconfig.yaml
kubectl get nodes  # Verify connection

# 3. Port forward to database
kubectl port-forward -n postgres service/postgres-rw 5432:5432

# 4. Connect with any PostgreSQL client
psql -h localhost -p 5432 -U appuser -d appdb
# Password: AppUserP@ssw0rd456!
```

### **Method 2: Database Pod Direct Access**

#### **For Quick Admin Tasks**
```bash
# SSH to cluster
ssh root@91.98.16.104

# Connect directly to database pod
kubectl exec -it -n postgres postgres-cluster-1 -- psql -U appuser -d appdb

# Or connect as superuser for admin tasks
kubectl exec -it -n postgres postgres-cluster-1 -- psql -U postgres
```

### **Method 3: Temporary Client Pod**

#### **For Developers Without Direct SSH Access**
```bash
# Create a PostgreSQL client pod
kubectl run pgclient --image=postgres:16 --rm -it --restart=Never \
  --env="PGPASSWORD=AppUserP@ssw0rd456!" \
  -- psql -h postgres-rw.postgres.svc.cluster.local -U appuser -d appdb
```

## Connection Strings

### **Application Connection**
```bash
# Read-Write (for applications)
postgresql://appuser:AppUserP@ssw0rd456!@postgres-rw.postgres.svc.cluster.local:5432/appdb?sslmode=require

# Read-Only (for reports/analytics)
postgresql://appuser:AppUserP@ssw0rd456!@postgres-ro.postgres.svc.cluster.local:5432/appdb?sslmode=require
```

### **Local Development**
```bash
# After port-forwarding
postgresql://appuser:AppUserP@ssw0rd456!@localhost:5432/appdb

# Using kubectl proxy
postgresql://appuser:AppUserP@ssw0rd456!@127.0.0.1:5432/appdb
```

## Developer Setup Instructions

### **Prerequisites**
1. **kubectl** installed and configured
2. **PostgreSQL client** (`psql`) installed
3. **Kubeconfig file** (request from admin)

### **Quick Setup Script for Developers**
```bash
#!/bin/bash
# db-connect.sh - Easy database access script

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Install: brew install kubectl"
    exit 1
fi

if ! command -v psql &> /dev/null; then
    echo "❌ psql not found. Install: brew install postgresql"
    exit 1
fi

# Check kubeconfig
if [ ! -f "k3s-cluster_kubeconfig.yaml" ]; then
    echo "❌ Kubeconfig not found. Request k3s-cluster_kubeconfig.yaml from admin"
    exit 1
fi

# Set kubeconfig
export KUBECONFIG=./k3s-cluster_kubeconfig.yaml

# Test cluster connection
echo "🔍 Testing cluster connection..."
if ! kubectl get nodes &>/dev/null; then
    echo "❌ Cannot connect to cluster. Check kubeconfig and network access"
    exit 1
fi

echo "✅ Cluster connection successful"
echo "🔗 Setting up database port forward..."

# Start port forward in background
kubectl port-forward -n postgres service/postgres-rw 5432:5432 &
PF_PID=$!

# Wait for port forward to establish
sleep 3

echo "✅ Port forward active (PID: $PF_PID)"
echo "📊 Connecting to database..."
echo ""
echo "💡 Connection details:"
echo "   Host: localhost"
echo "   Port: 5432"
echo "   Database: appdb"
echo "   Username: appuser"
echo "   Password: AppUserP@ssw0rd456!"
echo ""

# Connect to database
psql -h localhost -p 5432 -U appuser -d appdb

# Cleanup on exit
kill $PF_PID 2>/dev/null
echo "🧹 Port forward stopped"
```

### **Database Tools**

#### **Recommended GUI Tools**
```bash
# pgAdmin (Web-based)
# Connection: localhost:5432 after port-forward

# DBeaver (Desktop app)
# Connection: localhost:5432 after port-forward

# DataGrip (JetBrains)
# Connection: localhost:5432 after port-forward
```

#### **Command Line Tools**
```bash
# Connect with psql
psql -h localhost -p 5432 -U appuser -d appdb

# Export data
pg_dump -h localhost -p 5432 -U appuser -d appdb > backup.sql

# Import data
psql -h localhost -p 5432 -U appuser -d appdb < backup.sql
```

## Security Notes

### **For Developers**
- **Never commit** database credentials to code
- **Use environment variables** in applications
- **Use read-only connection** for reporting/analytics
- **Request specific database access** rather than superuser

### **Network Access**
- **Cluster Access Required**: Database is only accessible from within K8s cluster or via port-forward
- **No Direct External Access**: Database is not exposed to the internet (secure by design)
- **IPv6 Cluster**: May require IPv6 connectivity or SSH tunneling

## Current VTB API Configuration

The VTB test API (`tst.api.visualtourbuilder.com`) is already configured with:

```yaml
POSTGRES_HOST: "postgres-rw.postgres.svc.cluster.local"
POSTGRES_USER: "appuser"  
POSTGRES_PASSWORD: "AppUserP@ssw0rd456!"
POSTGRES_PORT: "5432"
POSTGRES_DB: "appdb"
```

## Troubleshooting

### **Common Issues**
1. **Connection Refused**: Check if port-forward is active
2. **DNS Resolution**: Ensure kubeconfig is set correctly
3. **Password Authentication**: Use exact password including special characters
4. **SSL Mode**: Add `?sslmode=require` for production connections

### **Health Checks**
```bash
# Check PostgreSQL cluster status
kubectl get cluster -n postgres

# Check pod status
kubectl get pods -n postgres

# Check logs
kubectl logs -n postgres postgres-cluster-1
```

## Database Schema

The database contains VTB-specific tables created by TypeORM migrations:
- `users` - User accounts
- `stripe_customers` - Stripe customer data
- `stripe_subscriptions` - Subscription management
- Additional tables defined in the VTB API migrations

Access the VTB API GraphQL endpoint at `https://tst.api.visualtourbuilder.com/graphql` to explore the schema interactively.