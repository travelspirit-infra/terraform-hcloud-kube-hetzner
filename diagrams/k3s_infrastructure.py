#!/usr/bin/env python3
from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import User, Client
from diagrams.onprem.network import Internet
from diagrams.generic.network import Router
from diagrams.k8s.clusterconfig import HPA
from diagrams.k8s.compute import Pod
from diagrams.k8s.network import Ingress, Service
from diagrams.k8s.controlplane import APIServer
from diagrams.generic.compute import Rack
from diagrams.generic.storage import Storage
from diagrams.custom import Custom
from diagrams.programming.flowchart import Database
from diagrams.oci.network import LoadBalancer as LoadBalancerIcon

# Graph configuration
graph_attr = {
    "fontsize": "16",
    "bgcolor": "white",
    "layout": "dot",
    "compound": "true",
    "splines": "spline",
    "rankdir": "TB",
    "dpi": "150"
}

# Edge styles
edge_ipv6 = {"style": "dashed", "color": "blue", "fontsize": "10"}
edge_private = {"style": "solid", "color": "darkgreen", "fontsize": "10"}
edge_public = {"style": "solid", "color": "red", "fontsize": "10"}
edge_k8s = {"style": "dotted", "color": "purple", "fontsize": "10"}

with Diagram("K3S Hetzner Infrastructure", 
            filename="diagrams/k3s_infrastructure",
            show=False,
            graph_attr=graph_attr,
            direction="TB"):
    
    # External components
    internet = Internet("Internet")
    user = User("User")
    dns = Client("k8s.travelspirit.cloud")
    
    # Main cluster components
    with Cluster("Hetzner Cloud - Nuremberg (nbg1)", graph_attr={"bgcolor": "#f0f0f0"}):
        
        # Load Balancer
        lb = LoadBalancerIcon("Ingress Load Balancer\n167.235.110.121\n2a01:4f8:1c1f:7a40::1\nPorts: 80, 443")
        
        # Private Network
        with Cluster("Private Network: k3s-cluster (10.0.0.0/8)", graph_attr={"bgcolor": "#e6f3ff"}):
            
            # Control Plane Subnet
            with Cluster("Control Plane Subnet (10.255.0.0/16)", graph_attr={"bgcolor": "#ffe6e6"}):
                control_plane = Rack("control-plane-nbg1-uwu\nCAX21 (ARM64)\n4 vCPU, 8GB RAM\nIPv6: 2a01:4f8:1c1b:f096::1\nPrivate: 10.255.0.101")
                api_server = APIServer("K3S API Server\nPort 6443")
                
            # Worker Subnet  
            with Cluster("Worker Subnet (10.0.0.0/16)", graph_attr={"bgcolor": "#e6ffe6"}):
                worker1 = Rack("agent-nbg1-nld\nCAX21 (ARM64)\n4 vCPU, 8GB RAM\nIPv6: 2a01:4f8:1c1c:86d8::1\nPrivate: 10.0.0.101")
                worker2 = Rack("agent-nbg1-bqb\nCAX21 (ARM64)\n4 vCPU, 8GB RAM\nIPv6: 2a01:4f8:1c1a:47f9::1\nPrivate: 10.0.0.102")
        
        # K8S Services
        with Cluster("Kubernetes Services", graph_attr={"bgcolor": "#fff0e6"}):
            traefik = Ingress("Traefik Ingress\nNodePort: 31903 (HTTP)\nNodePort: 30492 (HTTPS)")
            cert_manager = Pod("cert-manager\nLet's Encrypt")
            hello_app = Pod("Hello World App\n2 replicas")
            coredns = Pod("CoreDNS")
            metrics = Pod("Metrics Server")
            ccm = Pod("Hetzner CCM")
            csi = Pod("Hetzner CSI")
            
        # Storage
        storage = Storage("Hetzner Volumes\n(CSI Driver)")
    
    # Network connections
    # User to Internet
    user >> Edge(label="HTTPS", **edge_public) >> internet
    
    # DNS resolution
    internet >> Edge(label="DNS", **edge_public) >> dns
    
    # Internet to Load Balancer
    dns >> Edge(label="IPv4/IPv6", **edge_public) >> lb
    
    # Load Balancer to nodes (private network)
    lb >> Edge(label="TCP Proxy\n10.255.0.1", **edge_private) >> traefik
    
    # Traefik distribution to nodes
    traefik >> Edge(label="NodePort", **edge_k8s) >> control_plane
    traefik >> Edge(label="NodePort", **edge_k8s) >> worker1
    traefik >> Edge(label="NodePort", **edge_k8s) >> worker2
    
    # K3S internal routing
    control_plane >> Edge(label="10.42.0.0/24", **edge_k8s) >> api_server
    worker1 >> Edge(label="10.42.2.0/24", **edge_k8s) >> hello_app
    
    # Control plane connections
    api_server >> Edge(label="K8S API", **edge_k8s) >> [coredns, metrics, ccm, csi]
    
    # CSI to storage
    csi >> Edge(label="Storage API", **edge_private) >> storage
    
    # Cert-manager
    cert_manager >> Edge(label="ACME", **edge_public) >> internet

# Create a detailed network flow diagram
with Diagram("K3S Network Traffic Flow", 
            filename="diagrams/k3s_network_flow",
            show=False,
            graph_attr=graph_attr):
    
    # External
    client = User("Client")
    
    with Cluster("Traffic Flow", graph_attr={"bgcolor": "#f5f5f5"}):
        # Steps
        step1 = Client("1. DNS Resolution\nk8s.travelspirit.cloud\n→ 167.235.110.121")
        step2 = LoadBalancerIcon("2. Hetzner LB\nProxy Protocol\nRound Robin")
        step3 = Ingress("3. Traefik Ingress\nTLS Termination\nRouting Rules")
        step4 = Service("4. K8S Service\nClusterIP")
        step5 = Pod("5. Application Pod\nHello World")
        
    # Flow
    client >> step1 >> step2 >> step3 >> step4 >> step5

# Create cost breakdown diagram
with Diagram("Infrastructure Cost Breakdown", 
            filename="diagrams/k3s_cost_breakdown",
            show=False,
            graph_attr={**graph_attr, "rankdir": "LR"}):
    
    with Cluster("Monthly Costs (€28.24)", graph_attr={"bgcolor": "#fff5e6"}):
        servers = Rack("3x CAX21 Servers\n€5.99 each\n= €17.97")
        lb_cost = LoadBalancerIcon("Load Balancer\nLB11\n€5.39")
        network = Router("Private Network\n€0.48")
        traffic = Internet("Traffic\n~€4.40\n(estimated)")
        
    total = Database("Total: €28.24/month")
    
    [servers, lb_cost, network, traffic] >> total