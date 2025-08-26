# Deployment Instructions for OpenTelemetry Monitoring

Due to IPv6-only cluster nodes and network routing limitations, the monitoring stack needs to be deployed from a machine with direct IPv6 access to the cluster.

## Files Prepared

All monitoring components have been combined into a single file: `all-in-one.yaml`

This file contains:
- Monitoring namespace
- Node Exporter DaemonSet (runs on all nodes)
- OpenTelemetry Collector Deployment
- ConfigMap with collector configuration
- RBAC resources (ServiceAccount, ClusterRole, ClusterRoleBinding)

## Current Status

The deployment file has been copied to the bastion server:
- Location: `/tmp/monitoring.yaml` on `pcmulder@52.58.211.8`

## Deployment Options

### Option 1: Deploy from Control Plane (Recommended)

1. SSH to the bastion server:
```bash
ssh pcmulder@52.58.211.8
```

2. Copy the file to the control plane (if IPv6 connectivity works):
```bash
scp /tmp/monitoring.yaml root@[2a01:4f8:1c1b:f096::1]:/tmp/
```

3. SSH to the control plane:
```bash
ssh -6 root@2a01:4f8:1c1b:f096::1
```

4. Deploy the monitoring stack:
```bash
kubectl apply -f /tmp/monitoring.yaml
```

5. Verify deployment:
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=otel-collector --tail=20
```

### Option 2: Enable Temporary IPv4 Access

If you need to deploy from your local machine:

1. Temporarily enable IPv4 on the control plane node via Hetzner Cloud Console
2. Update the kubeconfig with the new IPv4 address
3. Deploy using kubectl locally
4. Disable IPv4 after deployment to save costs

### Option 3: Use Terraform to Deploy

Add the monitoring manifests to your Terraform configuration using the `kubernetes` provider, which already has access to the cluster.

## Verification Commands

Once deployed, verify the monitoring stack is working:

```bash
# Check all pods are running
kubectl get pods -n monitoring

# Check node exporter is collecting metrics
kubectl logs -n monitoring -l app=node-exporter --tail=10

# Check OTel collector is scraping and forwarding
kubectl logs -n monitoring -l app=otel-collector --tail=50

# Check for any errors
kubectl describe pod -n monitoring -l app=otel-collector
```

## Expected Output

You should see:
- 3 node-exporter pods (one per node) in Running state
- 1 otel-collector pod in Running state
- Logs showing successful scraping and metric export

## Troubleshooting

### If pods are not starting:
```bash
kubectl describe pod -n monitoring <pod-name>
kubectl events -n monitoring
```

### If metrics are not being sent:
1. Check the endpoint URL in the ConfigMap
2. Verify network connectivity to prometheus.travelspirit.cloud
3. Check if authentication is required for the remote write endpoint

### To update configuration:
```bash
kubectl edit configmap -n monitoring otel-collector-config
kubectl rollout restart deployment -n monitoring otel-collector
```

## Architecture Summary

```
Node Exporters (DaemonSet) -> OTel Collector (Central) -> Prometheus Remote Write
     Port 9100                  Scrapes every 30s         https://prometheus.travelspirit.cloud
```

## Resource Usage

- Node Exporter: 100m CPU, 100Mi memory per node
- OTel Collector: 200m CPU, 256Mi memory (can handle up to 512Mi)

## Next Steps

After successful deployment:
1. Configure Grafana dashboards to visualize the metrics
2. Set up alerting rules in Prometheus
3. Consider adding additional exporters (e.g., kube-state-metrics)
4. Monitor resource usage and adjust limits if needed