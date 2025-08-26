# VTB Test Environment Deployment Guide

## Overview

This guide explains how to deploy the Visual Tour Builder (VTB) API test environment to the K8s cluster.

## Prerequisites

### **1. Environment Setup**
```bash
# Copy and configure environment file
cp hcloud-env.sh.example hcloud-env.sh
# Edit hcloud-env.sh with your actual tokens
```

### **2. Required Tokens**
- **Hetzner Cloud API Token**: For infrastructure management
- **Cloudflare API Token**: For DNS management (zones: travelspirit.cloud, visualtourbuilder.com)

### **3. Cluster Access**
- SSH access to control plane: `ssh root@91.98.16.104`
- Or kubectl with kubeconfig file

## Current Infrastructure

### **DNS Architecture**
```bash
# Production (AWS ECS) - DO NOT MODIFY
api.visualtourbuilder.com → AWS Load Balancer (52.29.255.190)

# Test Environment (K8s Cluster) 
tst.api.visualtourbuilder.com → K8s Load Balancer (167.235.110.121)
```

### **Database**
- **PostgreSQL**: CloudNativePG cluster (2 instances, HA)
- **Connection**: `postgres-rw.postgres.svc.cluster.local:5432`
- **Database**: `appdb`
- **User**: `appuser`

### **SSL Certificates**
- **Wildcard**: `*.api.visualtourbuilder.com` (covers all API subdomains)
- **Method**: DNS01 challenge via Cloudflare API
- **Issuer**: Let's Encrypt

## Deployment Process

### **1. Build and Push VTB API Image**
```bash
# Navigate to VTB repository
cd /Users/pcmulder/projects/visual-tour-builder

# Pull latest main
git pull origin main

# Build image for ARM64 (Hetzner CAX instances)
./scripts/build-api-image.sh

# Login to Harbor registry
./scripts/login-registry.sh

# Push to Harbor
./scripts/push-api-image.sh
```

### **2. Deploy PostgreSQL (if not already done)**
```bash
# Deploy CloudNativePG cluster
kubectl apply -f cloudnative-pg-setup.yaml

# Wait for cluster to be ready
kubectl wait --for=condition=Ready cluster/postgres-cluster -n postgres --timeout=300s
```

### **3. Configure VTB Deployment**
```bash
# Copy template and edit with real values
cp deployments/vtb-test-deployment.yaml.example deployments/vtb-test-deployment.yaml

# Update the following in vtb-test-deployment.yaml:
# - Database passwords (match cloudnative-pg-setup.yaml)
# - Stripe API keys (test keys)
# - Auth0 configuration
# - Other service API keys
```

### **4. Deploy VTB API**
```bash
# Deploy the API
kubectl apply -f deployments/vtb-test-deployment.yaml

# Run database migrations
kubectl apply -f deployments/vtb-migration-job.yaml

# Check deployment status
kubectl get pods,svc,ingress -n vtb-test
```

### **5. Configure SSL (Wildcard Certificates)**
```bash
# Copy and configure Cloudflare DNS issuer
cp deployments/cloudflare-dns-issuer.yaml.example deployments/cloudflare-dns-issuer.yaml
# Edit with real Cloudflare API token

# Deploy DNS01 challenge issuer
kubectl apply -f deployments/cloudflare-dns-issuer.yaml

# Create wildcard certificate for *.api.visualtourbuilder.com
kubectl apply -f deployments/api-wildcard-cert.yaml

# Configure TLSStore for default certificate
kubectl apply -f deployments/traefik-tlsstore.yaml

# Apply ingress with wildcard certificate
kubectl apply -f deployments/vtb-wildcard-ingress.yaml
```

## Verification

### **1. Check Components**
```bash
# Database
kubectl get cluster -n postgres
kubectl get pods -n postgres

# VTB API
kubectl get pods,svc,ingress -n vtb-test

# Certificates
kubectl get certificates -n vtb-test
kubectl get clusterissuer
```

### **2. Test API Endpoints**
```bash
# Health check
curl https://tst.api.visualtourbuilder.com/health

# Root endpoint
curl https://tst.api.visualtourbuilder.com/

# GraphQL
curl https://tst.api.visualtourbuilder.com/graphql \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query":"query { __schema { queryType { name } } }"}'
```

### **3. Database Connection Test**
```bash
# From within cluster
kubectl exec -it -n postgres postgres-cluster-1 -- psql -U appuser -d appdb

# Via port-forward (for local tools)
kubectl port-forward -n postgres service/postgres-rw 5432:5432
psql -h localhost -p 5432 -U appuser -d appdb
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
           ┌─────────────────────────┐
           │    Cloudflare DNS       │
           │ *.api.visualtourbuilder │
           └─────────────┬───────────┘
                         │
                         ▼
                ┌─────────────────────┐
                │  Hetzner Cloud LB   │
                │  167.235.110.121    │
                └─────────┬───────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │    Traefik Proxy    │
                │   (SSL Termination) │
                └─────────┬───────────┘
                          │
           ┌──────────────┼──────────────┐
           ▼              ▼              ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  VTB API    │ │ PostgreSQL  │ │   Harbor    │
    │    Pod      │ │  Cluster    │ │  Registry   │
    └─────────────┘ └─────────────┘ └─────────────┘
```

## Security Best Practices

### **Secret Management**
- **Never commit** actual secrets to git
- **Use template files** with placeholder values
- **Store secrets** in Kubernetes secrets or environment variables
- **Rotate tokens** regularly

### **Files to NEVER Commit**
- `hcloud-env.sh` (contains real tokens)
- `deployments/vtb-test-deployment.yaml` (contains real secrets)
- `deployments/cloudflare-dns-issuer.yaml` (contains real tokens)
- `*.kubeconfig.yaml` (cluster access credentials)
- `terraform.tfstate*` (contains sensitive infrastructure state)

### **Repository Structure**
```
terraform-hcloud-kube-hetzner/
├── hcloud-env.sh.example          # ✅ Template (commit)
├── hcloud-env.sh                  # ❌ Real tokens (ignore)
├── deployments/
│   ├── vtb-test-deployment.yaml.example    # ✅ Template (commit)
│   ├── vtb-test-deployment.yaml            # ❌ Real secrets (ignore)
│   ├── cloudflare-dns-issuer.yaml.example  # ✅ Template (commit)
│   └── cloudflare-dns-issuer.yaml          # ❌ Real tokens (ignore)
└── docs/
    ├── database-access-guide.md   # ✅ Documentation (commit)
    └── vtb-deployment-guide.md    # ✅ Guide (commit)
```

## Troubleshooting

### **Common Issues**
1. **Pod CrashLoopBackOff**: Check database connectivity and secrets
2. **Certificate Not Ready**: Wait for DNS01 challenge (2-5 minutes)
3. **502/503 Errors**: Check pod readiness and service endpoints
4. **DNS Not Resolving**: Check DNS propagation (up to 15 minutes)

### **Debug Commands**
```bash
# Check pod logs
kubectl logs -n vtb-test deployment/vtb-api

# Check certificate events
kubectl describe certificate -n vtb-test

# Check DNS challenges
kubectl get challenges -A

# Check Traefik routing
kubectl logs -n traefik deployment/traefik
```

## Development Workflow

### **For Code Changes**
1. **Update code** in `/Users/pcmulder/projects/visual-tour-builder`
2. **Build new image**: `./scripts/build-api-image.sh`
3. **Push to Harbor**: `./scripts/push-api-image.sh`
4. **Restart deployment**: `kubectl rollout restart deployment/vtb-api -n vtb-test`
5. **Test changes**: Access `https://tst.api.visualtourbuilder.com/`

### **For Database Changes**
1. **Create migration** in visual-tour-builder repository
2. **Build new image** with migration
3. **Deploy migration job**: `kubectl apply -f deployments/vtb-migration-job.yaml`
4. **Restart API**: `kubectl rollout restart deployment/vtb-api -n vtb-test`

This guide ensures consistent deployment and proper secret management for the VTB test environment.