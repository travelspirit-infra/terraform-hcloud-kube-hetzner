import * as pulumi from "@pulumi/pulumi";
import * as hcloud from "@pulumi/hcloud";
import * as cloudflare from "@pulumi/cloudflare";
import * as k8s from "@pulumi/kubernetes";
import { K3sCluster } from "./infrastructure/k3s-cluster";
import { NetworkInfrastructure } from "./infrastructure/network";
import { DNSConfiguration } from "./infrastructure/dns";
import { LoadBalancers } from "./infrastructure/load-balancers";
import { SecurityGroups } from "./infrastructure/security";

// Configuration
const config = new pulumi.Config();
const environment = config.require("environment");
const infrastructureVersion = config.require("infrastructureVersion");

// Stack Reference for cross-stack dependencies
const stackRef = new pulumi.StackReference(`organization/infrastructure/${environment}`);

// ===========================================
// Stage 1: Network Infrastructure
// ===========================================
const network = new NetworkInfrastructure("k3s-network", {
    environment,
    ipRange: "10.0.0.0/8",
    subnets: [
        { name: "control-plane", range: "10.255.0.0/16", zone: "nbg1" },
        { name: "workers", range: "10.0.0.0/16", zone: "nbg1" },
        { name: "services", range: "10.1.0.0/16", zone: "nbg1" }
    ],
    enableIPv6: true,
    tags: {
        Environment: environment,
        ManagedBy: "pulumi",
        Version: infrastructureVersion
    }
});

// ===========================================
// Stage 2: Security Configuration
// ===========================================
const security = new SecurityGroups("k3s-security", {
    network: network.network,
    rules: [
        // Kubernetes API
        { direction: "in", protocol: "tcp", port: "6443", sourceIPs: ["0.0.0.0/0", "::/0"] },
        // HTTP/HTTPS Ingress
        { direction: "in", protocol: "tcp", port: "80", sourceIPs: ["0.0.0.0/0", "::/0"] },
        { direction: "in", protocol: "tcp", port: "443", sourceIPs: ["0.0.0.0/0", "::/0"] },
        // NodePort Services Range
        { direction: "in", protocol: "tcp", port: "30000-32767", sourceIPs: ["10.0.0.0/8"] },
        // Internal cluster communication
        { direction: "in", protocol: "tcp", port: "any", sourceIPs: ["10.0.0.0/8"] },
        { direction: "in", protocol: "udp", port: "any", sourceIPs: ["10.0.0.0/8"] },
        // Outbound traffic
        { direction: "out", protocol: "tcp", port: "any", destinationIPs: ["0.0.0.0/0", "::/0"] },
        { direction: "out", protocol: "udp", port: "any", destinationIPs: ["0.0.0.0/0", "::/0"] }
    ]
});

// ===========================================
// Stage 3: K3s Cluster
// ===========================================
const cluster = new K3sCluster("k3s-cluster", {
    environment,
    network: network.network,
    firewalls: security.firewalls,
    controlPlanes: {
        count: environment === "production" ? 3 : 1,
        serverType: "cax21", // ARM64 4vCPU, 8GB RAM
        location: "nbg1",
        labels: {
            "node-role.kubernetes.io/control-plane": "true",
            "kubernetes.io/arch": "arm64"
        }
    },
    workers: {
        count: environment === "production" ? 3 : 2,
        serverType: "cax21",
        location: "nbg1",
        labels: {
            "node-role.kubernetes.io/worker": "true",
            "kubernetes.io/arch": "arm64"
        },
        taints: []
    },
    k3sVersion: "v1.32.6+k3s1",
    features: {
        serviceLB: false, // Use Hetzner Load Balancers instead
        metricsServer: true,
        localStorageProvider: false, // Use Hetzner CSI
        traefik: true
    },
    highAvailability: environment === "production",
    backupSchedule: environment === "production" ? "0 2 * * *" : undefined
});

// ===========================================
// Stage 4: Load Balancers
// ===========================================
const loadBalancers = new LoadBalancers("k3s-lb", {
    network: network.network,
    cluster: cluster,
    environment,
    loadBalancers: [
        {
            name: "control-plane",
            type: "lb11", // Smallest LB type
            algorithm: "round_robin",
            targets: cluster.controlPlaneNodes,
            services: [
                { protocol: "tcp", listen_port: 6443, destination_port: 6443 }
            ],
            healthCheck: {
                protocol: "tcp",
                port: 6443,
                interval: 15,
                timeout: 10,
                retries: 3
            }
        },
        {
            name: "ingress",
            type: "lb11",
            algorithm: "least_connections",
            targets: cluster.workerNodes,
            services: [
                { protocol: "tcp", listen_port: 80, destination_port: 80 },
                { protocol: "tcp", listen_port: 443, destination_port: 443 }
            ],
            healthCheck: {
                protocol: "http",
                port: 80,
                interval: 15,
                timeout: 10,
                retries: 3,
                http: {
                    path: "/healthz",
                    status_codes: ["2??", "3??"]
                }
            }
        }
    ]
});

// ===========================================
// Stage 5: DNS Configuration
// ===========================================
const dns = new DNSConfiguration("k3s-dns", {
    domain: "k8s.travelspirit.cloud",
    zoneId: config.require("cloudflareZoneId"),
    records: [
        {
            name: "@",
            type: "A",
            value: loadBalancers.ingressIP,
            proxied: true
        },
        {
            name: "*",
            type: "A",
            value: loadBalancers.ingressIP,
            proxied: true
        },
        {
            name: "api",
            type: "A",
            value: loadBalancers.controlPlaneIP,
            proxied: false // Don't proxy K8s API
        }
    ],
    sslSettings: {
        mode: "flexible", // Cloudflare → Origin: HTTP, Client → Cloudflare: HTTPS
        minTlsVersion: "1.2",
        ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384"
    }
});

// ===========================================
// Stage 6: Kubernetes Provider Configuration
// ===========================================
const k8sProvider = new k8s.Provider("k8s-provider", {
    kubeconfig: cluster.kubeconfig,
    enableServerSideApply: true
});

// ===========================================
// Stage 7: Core Kubernetes Resources
// ===========================================

// Namespaces
const namespaces = {
    certManager: new k8s.core.v1.Namespace("cert-manager", {
        metadata: { name: "cert-manager" }
    }, { provider: k8sProvider }),
    
    monitoring: new k8s.core.v1.Namespace("monitoring", {
        metadata: { name: "monitoring" }
    }, { provider: k8sProvider }),
    
    applications: new k8s.core.v1.Namespace("applications", {
        metadata: { 
            name: "applications",
            labels: {
                environment,
                "istio-injection": "enabled" // If using Istio
            }
        }
    }, { provider: k8sProvider })
};

// Hetzner Cloud Controller Manager Secret
const hcloudSecret = new k8s.core.v1.Secret("hcloud-secret", {
    metadata: {
        name: "hcloud",
        namespace: "kube-system"
    },
    stringData: {
        token: config.requireSecret("hcloudToken"),
        network: network.network.id.apply(id => id.toString())
    }
}, { provider: k8sProvider });

// Storage Class for Hetzner Volumes
const storageClass = new k8s.storage.v1.StorageClass("hcloud-volumes", {
    metadata: {
        name: "hcloud-volumes",
        annotations: {
            "storageclass.kubernetes.io/is-default-class": "true"
        }
    },
    provisioner: "csi.hetzner.cloud",
    volumeBindingMode: "WaitForFirstConsumer",
    allowVolumeExpansion: true,
    parameters: {
        type: "ssd"
    }
}, { provider: k8sProvider });

// ===========================================
// Stage 8: Cluster Autoscaler (Optional)
// ===========================================
if (environment === "production") {
    const autoscaler = new k8s.apps.v1.Deployment("cluster-autoscaler", {
        metadata: {
            name: "cluster-autoscaler",
            namespace: "kube-system"
        },
        spec: {
            replicas: 1,
            selector: {
                matchLabels: {
                    app: "cluster-autoscaler"
                }
            },
            template: {
                metadata: {
                    labels: {
                        app: "cluster-autoscaler"
                    }
                },
                spec: {
                    serviceAccountName: "cluster-autoscaler",
                    containers: [{
                        name: "cluster-autoscaler",
                        image: "k8s.gcr.io/autoscaling/cluster-autoscaler:v1.32.0",
                        command: [
                            "./cluster-autoscaler",
                            "--v=4",
                            "--stderrthreshold=info",
                            "--cloud-provider=hetzner",
                            "--nodes=2:10:workers",
                            "--skip-nodes-with-local-storage=false"
                        ],
                        env: [
                            {
                                name: "HCLOUD_TOKEN",
                                valueFrom: {
                                    secretKeyRef: {
                                        name: "hcloud",
                                        key: "token"
                                    }
                                }
                            }
                        ]
                    }]
                }
            }
        }
    }, { provider: k8sProvider });
}

// ===========================================
// Exports
// ===========================================
export const clusterName = cluster.name;
export const clusterEndpoint = cluster.apiEndpoint;
export const kubeconfig = pulumi.secret(cluster.kubeconfig);
export const ingressLoadBalancerIP = loadBalancers.ingressIP;
export const controlPlaneLoadBalancerIP = loadBalancers.controlPlaneIP;
export const networkId = network.network.id;
export const namespaceNames = {
    certManager: namespaces.certManager.metadata.name,
    monitoring: namespaces.monitoring.metadata.name,
    applications: namespaces.applications.metadata.name
};
export const storageClassName = storageClass.metadata.name;
export const dnsRecords = dns.records.map(r => `${r.name}.${r.zone}`);

// Stack outputs for cross-stack references
export const stackOutputs = {
    kubeconfig: pulumi.secret(cluster.kubeconfig),
    apiEndpoint: cluster.apiEndpoint,
    ingressIP: loadBalancers.ingressIP,
    environment,
    version: infrastructureVersion
};