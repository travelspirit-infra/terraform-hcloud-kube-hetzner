# Kubernetes Test Environment Strategy

## Overview
This document outlines the strategy for implementing test environments on our K3s Hetzner cluster, providing both long-lived acceptance environments and short-lived ephemeral environments for development and testing.

## Environment Types

### Long-Lived Environments
- **Acceptance/Staging**: `vtb-api-acceptance` - Permanent environment for UAT
- **Test**: `vtb-api-test` - Shared testing environment for integration tests

### Short-Lived Environments (Auto-cleanup)
- **PR Environments**: `vtb-api-pr-{number}` - Created on PR, deleted when PR closes
- **Feature Branches**: `vtb-api-feature-{name}` - On-demand feature testing
- **Developer Personal**: `vtb-api-dev-{username}` - Personal development environments

## Implementation Architecture

### Namespace-Based Isolation
Each environment runs in its own Kubernetes namespace:
```bash
vtb-api-acceptance    # Long-lived acceptance environment
vtb-api-test         # Long-lived test environment
vtb-api-pr-123       # Ephemeral PR environment
vtb-api-dev-patrick  # Ephemeral developer environment
```

### DNS Strategy
Wildcard DNS configuration: `*.k8s.travelspirit.cloud` → `167.235.110.121`

Environment-specific URLs:
- `vtb-api-acceptance.k8s.travelspirit.cloud`
- `vtb-api-pr-123.k8s.travelspirit.cloud`
- `vtb-api-dev-patrick.k8s.travelspirit.cloud`

### Database Strategy

#### Long-Lived Environments
- Dedicated PostgreSQL databases or schemas
- Persistent data for acceptance testing
- Full feature compatibility

#### Short-Lived Environments
- Shared test database with environment-specific schemas
- SQLite option for ultra-lightweight testing
- Automatic cleanup on environment destruction

### Resource Management

#### Acceptance Environment
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi" 
    cpu: "500m"
replicaCount: 2  # HA for acceptance testing
```

#### Ephemeral Environments
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "200m"
replicaCount: 1  # Single replica for testing
```

## CI/CD Integration

### Automatic PR Environments
- Created on PR open/sync
- Deleted on PR close
- Accessible via `vtb-api-pr-{number}.k8s.travelspirit.cloud`

### Deployment Pipeline
1. Build Docker image
2. Push to ECR with PR tag
3. Deploy to K8s namespace
4. Run smoke tests
5. Comment PR with environment URL

### Cleanup Automation
- TTL-based cleanup (7-day default for ephemeral environments)
- GitHub Actions integration for PR-based cleanup
- Daily cron job for orphaned environments

## Developer Experience

### Quick Commands
```bash
# Create personal dev environment
make dev-env-create name=patrick

# Deploy feature branch
make feature-deploy branch=feature/new-api

# List all environments
kubectl get namespaces -l app=vtb-api

# Cleanup personal environment
make dev-env-cleanup name=patrick
```

### Environment Access
All environments accessible via:
- Direct URL: `https://{env-name}.k8s.travelspirit.cloud`
- K8s port-forward: `kubectl port-forward -n {namespace} svc/{service} 3000:3000`

## Cost Optimization

### Resource Efficiency
- Minimal resource allocation for ephemeral environments
- Automatic cleanup prevents resource waste
- Shared test database reduces overhead

### Estimated Costs
- Acceptance environment: ~€5/month (similar to small ECS task)
- 10 concurrent PR environments: ~€2/month total
- Zero additional infrastructure costs (uses existing K3s cluster)

## Security & Isolation

### Network Isolation
- Namespace-based network policies
- Ingress controller handles SSL termination
- Cert-manager for automatic SSL certificates

### Secret Management
- Environment-specific secrets per namespace
- ConfigMaps for non-sensitive configuration
- Integration with existing AWS SSM for sensitive data

## Implementation Phases

### Phase 1: Acceptance Environment (Current)
1. Create Helm chart for VTB-API
2. Deploy long-lived acceptance environment
3. Set up DNS and SSL certificates

### Phase 2: Ephemeral Environments
1. Implement PR-based environment automation
2. Set up cleanup mechanisms
3. Create developer tooling

### Phase 3: Advanced Features
1. Database schema automation
2. Environment monitoring and alerting
3. Cost tracking and optimization

## Benefits

✅ **Fast deployments**: ~30 seconds vs 5+ minutes for ECS
✅ **Cost-effective**: ~90% cost reduction vs separate ECS environments
✅ **Developer-friendly**: Easy environment creation/destruction
✅ **CI/CD integrated**: Automatic PR environments
✅ **Scalable**: K3s cluster handles many small environments efficiently
✅ **Isolated**: Complete separation between environments