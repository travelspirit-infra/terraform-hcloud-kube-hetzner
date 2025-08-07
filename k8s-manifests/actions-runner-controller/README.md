# GitHub Actions Runner Controller Setup

This directory contains the configuration for deploying GitHub Actions Runner Controller (ARC) on the K3s Hetzner cluster.

## Overview

Actions Runner Controller enables self-hosted GitHub Actions runners on Kubernetes, providing:
- Automatic scaling based on workflow demand
- ARM64 support for cost-effective Hetzner CAX instances
- Ephemeral runners for better security
- Docker-in-Docker support for container builds

## Prerequisites

1. **K3s Cluster**: Ensure your cluster is running and accessible
2. **cert-manager**: Required for webhook certificates (already enabled in the cluster)
3. **Helm 3**: For installing the controller
4. **GitHub Token**: Personal Access Token or GitHub App credentials

## Installation

### 1. Generate GitHub Token

Create a GitHub Personal Access Token with appropriate scopes:
- **Repository runners**: `repo` scope
- **Organization runners**: `admin:org` scope

### 2. Run Setup Script

```bash
# Set your GitHub token
export GITHUB_TOKEN='your-github-pat-token'

# Run the setup script
./setup-arc.sh
```

The script will:
- Verify prerequisites
- Create namespace and secrets
- Install ARC using Helm
- Deploy runner configuration
- Verify the installation

### 3. Manual Installation (Alternative)

If you prefer manual steps:

```bash
# Create namespace
kubectl apply -f k8s-manifests/actions-runner-controller/namespace.yaml

# Create GitHub token secret
kubectl create secret generic controller-manager \
  -n actions-runner-system \
  --from-literal=github_token="$GITHUB_TOKEN"

# Add Helm repository
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

# Install ARC
helm install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  --namespace actions-runner-system \
  --values k8s-manifests/actions-runner-controller/values.yaml

# Deploy runners
kubectl apply -f k8s-manifests/actions-runner-controller/runner-deployment.yaml
```

## Configuration

### values.yaml
- Configured for ARM64 architecture (Hetzner CAX instances)
- Controller and webhook pods scheduled on ARM64 nodes
- Metrics enabled for monitoring
- Resource limits optimized for efficiency

### runner-deployment.yaml
- Creates 2 runner replicas by default
- Configured for `travelspirit-infra/travelspirit` repository
- Labels: `self-hosted`, `linux`, `arm64`, `hetzner`
- Docker-in-Docker enabled for container builds
- Autoscaling configured (1-5 runners based on demand)

## Usage in GitHub Actions

Update your workflow to use the self-hosted runners:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, arm64, hetzner]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          echo "Running on self-hosted ARM64 runner"
```

## Monitoring

Check runner status:
```bash
# List runner deployments
kubectl get runnerdeployment -n actions-runner-system

# List individual runners
kubectl get runners -n actions-runner-system

# Check autoscaler status
kubectl get hra -n actions-runner-system

# View runner logs
kubectl logs -n actions-runner-system -l app=github-runner
```

## Customization

### Change Repository/Organization

Edit `runner-deployment.yaml`:
```yaml
spec:
  template:
    spec:
      # For organization runners:
      organization: your-org-name
      
      # For repository runners:
      repository: your-org/your-repo
```

### Adjust Resources

Modify resource limits in `runner-deployment.yaml`:
```yaml
resources:
  limits:
    cpu: "3"
    memory: "6Gi"
  requests:
    cpu: "1"
    memory: "2Gi"
```

### Scale Runners

Change replica count:
```bash
kubectl scale runnerdeployment travelspirit-runners \
  -n actions-runner-system \
  --replicas=5
```

## Troubleshooting

### Runners Not Starting
1. Check controller logs:
   ```bash
   kubectl logs -n actions-runner-system deployment/actions-runner-controller
   ```

2. Verify GitHub token:
   ```bash
   kubectl get secret controller-manager -n actions-runner-system -o yaml
   ```

3. Check runner events:
   ```bash
   kubectl describe runners -n actions-runner-system
   ```

### ARM64 Compatibility Issues
- Some GitHub Actions may not support ARM64
- Use container actions when possible
- Consider matrix builds for multi-arch support

### IPv6 Connectivity
- GitHub API works over IPv6
- Docker pulls may be slower on IPv6-only nodes
- Consider using a local registry mirror

## Uninstallation

To remove ARC and all runners:

```bash
# Delete runners first
kubectl delete -f k8s-manifests/actions-runner-controller/runner-deployment.yaml

# Uninstall ARC
helm uninstall actions-runner-controller -n actions-runner-system

# Delete namespace
kubectl delete namespace actions-runner-system
```

## Cost Optimization

- Runners use existing worker nodes (no additional infrastructure)
- Autoscaling reduces idle resource usage
- ARM64 instances provide better price/performance
- Consider spot instances for non-critical workflows

## Security Considerations

- Use fine-grained PATs with minimal scopes
- Consider GitHub App authentication for production
- Runners are ephemeral (destroyed after each job)
- Network policies can restrict runner traffic
- Store secrets in Kubernetes secrets, not in code

## References

- [ARC Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Hetzner Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager)