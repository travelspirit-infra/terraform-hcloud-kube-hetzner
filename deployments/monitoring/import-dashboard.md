# K3s Hetzner Cluster Dashboard

## Import Instructions

1. **Access your Grafana instance** at `https://grafana.travelspirit.cloud`

2. **Import the dashboard:**
   - Click the "+" icon in the left sidebar
   - Select "Import"
   - Click "Upload JSON file" and select `k3s-cluster-dashboard.json`
   - Or copy and paste the JSON content from the file

3. **Configure the dashboard:**
   - The dashboard is pre-configured to use your Prometheus datasource (uid: `dep9qfvgyksn4b`)
   - All queries are filtered for `job="k3s-node-exporter"` to show only k3s cluster metrics

## Dashboard Features

### **Overview Panels:**
- **CPU Usage %** - Current CPU utilization per node (stat panels with thresholds)
- **Memory Usage %** - Current memory utilization per node
- **Swap Usage %** - Current swap utilization per node  
- **Disk Usage %** - Current disk utilization per node (root filesystem)

### **Time Series Graphs:**
- **System Load Average** - 1m, 5m, and 15m load averages for all nodes
- **Memory Usage (GB)** - Used vs total memory over time
- **CPU Usage Over Time** - CPU utilization trends
- **Disk Space (GB)** - Available vs total disk space

### **Summary Table:**
- **Node Summary** - Consolidated view showing CPU%, Memory%, Disk%, and Load for all nodes in a table format

## Metrics Included

All panels use metrics from your k3s cluster with the following identifiers:
- `job="k3s-node-exporter"` 
- `cluster="k3s-hetzner"`
- `region="eu-central"`

### **Nodes Monitored:**
- `k3s-cluster-control-plane-nbg1-kxa` (Control plane)
- `k3s-cluster-agent-nbg1-onh` (Agent)
- `k3s-cluster-agent-nbg1-tbh` (Agent) 
- `k3s-cluster-agent-x64-vitess-fcx` (Agent)

## Settings

- **Refresh Rate:** 30 seconds
- **Time Range:** Last 1 hour (adjustable)
- **Timezone:** Browser timezone
- **Thresholds:**
  - CPU/Memory: Green < 70%, Yellow < 85%, Red ≥ 85%
  - Swap: Green < 50%, Yellow < 80%, Red ≥ 80%
  - Disk: Green < 75%, Yellow < 90%, Red ≥ 90%