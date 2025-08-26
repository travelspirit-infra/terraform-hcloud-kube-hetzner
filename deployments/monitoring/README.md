# OpenTelemetry Monitoring Stack for K3s Cluster

This directory contains the configuration for deploying a centralized OpenTelemetry (OTel) collector with Prometheus node exporters on the K3s cluster.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Control Node   │     │   Worker 1      │     │   Worker 2      │
│ Node Exporter   │     │ Node Exporter   │     │ Node Exporter   │
│    :9100        │     │    :9100        │     │    :9100        │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   OTel Collector       │
                    │  (Central Instance)    │
                    │  - Scrapes all nodes   │
                    │  - Processes metrics   │
                    │  - Remote write        │
                    └───────────┬────────────┘
                                │
                                ▼
                    ┌────────────────────────┐
                    │ prometheus.travelspirit│
                    │        .cloud          │
                    │  (Remote Prometheus)   │
                    └────────────────────────┘
```

## Components

### 1. Node Exporter (DaemonSet)
- Runs on every node in the cluster (including control plane)
- Exposes host metrics on port 9100
- Collects CPU, memory, disk, network, and other system metrics
- Uses host network and PID namespace for accurate metrics
- Resource limits: 200Mi memory

### 2. OpenTelemetry Collector (Deployment)
- Single instance deployment for centralized collection
- Scrapes all node exporters via Kubernetes service discovery
- Processes and batches metrics efficiently
- Sends metrics to remote Prometheus via remote write API
- Resource limits: 512Mi memory, 1 CPU

### 3. Configuration Features
- **Service Discovery**: Automatic discovery of node exporters
- **Batching**: Groups up to 10,000 metrics per batch
- **Memory Limiting**: Prevents OOM with 512Mi limit
- **Retry Logic**: Automatic retry with exponential backoff
- **Health Checks**: Liveness and readiness probes
- **Debug Logging**: Samples metrics for troubleshooting
- **IPv6 Support**: Works with IPv6-only nodes

## Deployment

### Quick Deploy
```bash
./deploy.sh
```

### Manual Deploy with Kustomize
```bash
kubectl apply -k .
```

### Manual Deploy (Individual Files)
```bash
kubectl apply -f namespace.yaml
kubectl apply -f node-exporter-daemonset.yaml
kubectl apply -f otel-collector-rbac.yaml
kubectl apply -f otel-collector-configmap.yaml
kubectl apply -f otel-collector-deployment.yaml
```

## Verification

### Check Pod Status
```bash
kubectl get pods -n monitoring
```

### Check Node Exporter Metrics
```bash
# Port forward to a node exporter
kubectl port-forward -n monitoring daemonset/node-exporter 9100:9100

# View metrics
curl http://localhost:9100/metrics
```

### Check OTel Collector Logs
```bash
kubectl logs -n monitoring -l app=otel-collector --tail=50
```

### Check OTel Collector Metrics
```bash
# Port forward to OTel collector
kubectl port-forward -n monitoring deployment/otel-collector 8888:8888

# View internal metrics
curl http://localhost:8888/metrics
```

## Configuration

### Modify Scrape Interval
Edit `otel-collector-configmap.yaml`:
```yaml
scrape_interval: 30s  # Change to desired interval
```

### Add Custom Labels
Edit the `resource` processor in `otel-collector-configmap.yaml`:
```yaml
processors:
  resource:
    attributes:
    - key: your_label
      value: your_value
      action: insert
```

### Configure Prometheus Endpoint
Edit the `prometheusremotewrite` exporter in `otel-collector-configmap.yaml`:
```yaml
exporters:
  prometheusremotewrite:
    endpoint: "https://your-prometheus-endpoint/api/v1/write"
```

## Troubleshooting

### Node Exporter Not Running
```bash
# Check DaemonSet status
kubectl describe daemonset -n monitoring node-exporter

# Check pod logs
kubectl logs -n monitoring -l app=node-exporter
```

### OTel Collector Connection Issues
```bash
# Check collector logs for errors
kubectl logs -n monitoring -l app=otel-collector | grep -i error

# Check service discovery
kubectl logs -n monitoring -l app=otel-collector | grep -i "discovered"

# Verify RBAC permissions
kubectl auth can-i get pods --as=system:serviceaccount:monitoring:otel-collector
```

### Metrics Not Appearing in Prometheus
1. Check OTel collector logs for remote write errors
2. Verify the endpoint URL is correct
3. Check if authentication headers are needed
4. Verify network connectivity to prometheus.travelspirit.cloud

## Resource Usage

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|------------|-----------|----------------|--------------|
| Node Exporter | 100m | - | 100Mi | 200Mi |
| OTel Collector | 200m | 1000m | 256Mi | 512Mi |

## Security Considerations

- Node Exporter runs with minimal privileges (non-root, read-only filesystem)
- OTel Collector uses a dedicated ServiceAccount with limited RBAC permissions
- TLS verification is currently disabled for remote write (can be enabled in production)
- All containers drop all capabilities except those required

## Uninstall

```bash
kubectl delete -k .
# or
kubectl delete namespace monitoring
```