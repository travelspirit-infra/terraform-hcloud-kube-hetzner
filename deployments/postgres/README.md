# PostgreSQL Cluster Deployment

This directory contains plain Kubernetes YAML manifests for deploying a PostgreSQL cluster using CloudNativePG operator.

## Architecture

- **CloudNativePG Operator**: Manages PostgreSQL clusters, handles HA, backups, and monitoring
- **PostgreSQL Cluster**: 2-instance HA setup with primary/replica configuration
- **Storage**: Uses Hetzner Cloud Volumes (`hcloud-volumes` StorageClass)
- **Services**: Separate endpoints for read-write (primary) and read-only (replica) access

## Directory Structure

```
manifests/
├── namespace.yaml                    # postgres namespace
├── secrets.yaml                     # superuser and app user credentials
├── cloudnative-pg-operator.yaml     # CloudNativePG operator deployment
├── postgres-cluster.yaml            # PostgreSQL cluster definition
├── services.yaml                    # ClusterIP services for database access
└── configmap.yaml                   # Connection information for apps
```

## Deployment

PostgreSQL is deployed automatically via ArgoCD using the application defined in:
- `argocd-apps/postgres/postgres-cluster.yaml`

The ArgoCD application points to `deployments/postgres/manifests/` and deploys all resources in the correct order.

### Manual Deployment (Development Only)
If you need to deploy manually for testing:
```bash
kubectl apply -f manifests/
kubectl wait --for=condition=available deployment/cnpg-controller-manager -n cnpg-system --timeout=300s
```

## Configuration

### Database Connection
- **Primary (Read/Write)**: `postgres-cluster-rw.postgres.svc.cluster.local:5432`
- **Replica (Read-Only)**: `postgres-cluster-ro.postgres.svc.cluster.local:5432` 
- **Any Instance**: `postgres-cluster-r.postgres.svc.cluster.local:5432`

### Credentials
- **Superuser**: `postgres` (see `postgres-superuser-secret`)
- **App User**: `appuser` (see `postgres-app-user` secret)

### Resource Allocation
- **CPU**: 250m request, 1000m limit per instance
- **Memory**: 512Mi request, 2Gi limit per instance  
- **Storage**: 10Gi per instance (expandable)

## Migration from Helm

Since we can afford to take down the current cluster, ArgoCD will handle the migration:

1. **ArgoCD will detect changes** in Git and automatically deploy the new plain YAML manifests
2. **Old Helm resources will be pruned** due to `prune: true` in the ArgoCD application
3. **Fresh PostgreSQL cluster** will be created with the same configuration

## Monitoring

The cluster is configured for CloudNativePG's built-in monitoring but currently disabled. To enable:

```yaml
# In postgres-cluster.yaml
monitoring:
  enabled: true
```

## Compatibility

- **ARM64/x86 Mixed Cluster**: Includes tolerations for ARM64 nodes
- **Pod Security Standards**: Namespace configured for restricted PSS
- **Kubernetes**: Compatible with K3s and standard Kubernetes 1.25+