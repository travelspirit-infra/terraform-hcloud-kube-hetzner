# Hybrid Architecture: Terraform for Infrastructure, Pulumi for Applications

## Overview

This document describes a hybrid approach where:
- **Terraform** manages core infrastructure (networks, clusters, databases)
- **Pulumi** manages application deployments and configurations
- **GitHub Actions** orchestrates both tools in a unified pipeline

## Why Hybrid Architecture?

### Common Scenarios for Hybrid Approach

1. **Gradual Migration**: Teams transitioning from Terraform to Pulumi
2. **Team Specialization**: Infrastructure team uses Terraform, Dev team uses Pulumi
3. **Tool Strengths**: Leverage best tool for each layer
4. **Existing Investment**: Large Terraform codebase not worth migrating
5. **Compliance**: Infrastructure requires specific tooling/approval process

### Benefits

| Aspect | Benefit |
|--------|---------|
| **Separation of Concerns** | Clear boundary between infrastructure and applications |
| **Team Autonomy** | Different teams can use preferred tools |
| **Risk Reduction** | Changes to apps don't risk infrastructure |
| **Gradual Adoption** | Adopt Pulumi incrementally |
| **Best of Both** | Terraform's maturity + Pulumi's flexibility |

## Architecture Layers

```
┌─────────────────────────────────────────┐
│         Application Layer               │
│         (Pulumi - TypeScript)           │
│  - Deployments                          │
│  - Services                             │
│  - ConfigMaps/Secrets                   │
│  - Ingress Rules                        │
│  - HPA/PDB                              │
└─────────────────────────────────────────┘
                    ↕
        Data Exchange via Outputs
                    ↕
┌─────────────────────────────────────────┐
│       Kubernetes Platform Layer         │
│         (Terraform/Pulumi)              │
│  - Operators                            │
│  - RBAC                                 │
│  - Namespaces                           │
│  - Storage Classes                      │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│      Core Infrastructure Layer          │
│           (Terraform)                   │
│  - K3s/K8s Cluster                      │
│  - Networks                             │
│  - Load Balancers                       │
│  - DNS                                  │
│  - Databases                            │
└─────────────────────────────────────────┘
```

## Implementation Patterns

### Pattern 1: Terraform Infrastructure → Pulumi Applications

#### Terraform Side (Infrastructure)

```hcl
# terraform/main.tf
resource "hcloud_network" "k3s" {
  name     = "k3s-network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_server" "control_plane" {
  count       = 3
  name        = "k3s-control-${count.index}"
  server_type = "cax21"
  image       = "ubuntu-22.04"
  location    = "nbg1"
  
  network {
    network_id = hcloud_network.k3s.id
  }
}

module "k3s" {
  source = "./modules/k3s"
  
  control_plane_ips = hcloud_server.control_plane[*].ipv6_address
  network_id        = hcloud_network.k3s.id
}

# Export outputs for Pulumi consumption
output "cluster_endpoint" {
  value = module.k3s.api_endpoint
}

output "kubeconfig" {
  value     = module.k3s.kubeconfig
  sensitive = true
}

output "ingress_ip" {
  value = hcloud_load_balancer.ingress.ipv4
}

# Store outputs in S3 for Pulumi
resource "aws_s3_object" "terraform_outputs" {
  bucket  = "infrastructure-state"
  key     = "terraform-outputs.json"
  content = jsonencode({
    cluster_endpoint = module.k3s.api_endpoint
    ingress_ip      = hcloud_load_balancer.ingress.ipv4
    network_id      = hcloud_network.k3s.id
  })
}
```

#### Pulumi Side (Applications)

```typescript
// pulumi/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as k8s from "@pulumi/kubernetes";
import * as aws from "@pulumi/aws";

// Method 1: Read from Terraform state directly
const terraformState = new pulumi.StackReference("terraform-state", {
    // Reference Terraform state stored in backend
});

// Method 2: Read from S3 bucket
const terraformOutputs = aws.s3.getObject({
    bucket: "infrastructure-state",
    key: "terraform-outputs.json"
}).then(obj => JSON.parse(obj.body));

// Method 3: Use environment variables from CI/CD
const clusterEndpoint = process.env.CLUSTER_ENDPOINT || 
                       terraformOutputs.then(o => o.cluster_endpoint);

// Configure Kubernetes provider with Terraform outputs
const k8sProvider = new k8s.Provider("k8s", {
    kubeconfig: process.env.KUBECONFIG || terraformState.getOutput("kubeconfig")
});

// Deploy applications using Terraform-managed infrastructure
const appNamespace = new k8s.core.v1.Namespace("apps", {
    metadata: {
        name: "applications"
    }
}, { provider: k8sProvider });

const deployment = new k8s.apps.v1.Deployment("api", {
    metadata: {
        namespace: appNamespace.metadata.name
    },
    spec: {
        replicas: 3,
        selector: { matchLabels: { app: "api" } },
        template: {
            metadata: { labels: { app: "api" } },
            spec: {
                containers: [{
                    name: "api",
                    image: "myapp:latest",
                    env: [{
                        name: "INGRESS_IP",
                        value: terraformOutputs.then(o => o.ingress_ip)
                    }]
                }]
            }
        }
    }
}, { provider: k8sProvider });
```

### Pattern 2: Separate Pipelines with Data Exchange

#### GitHub Actions Workflow

```yaml
name: Hybrid Infrastructure and Application Deployment

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  # ========================================
  # Stage 1: Terraform Infrastructure
  # ========================================
  terraform-infrastructure:
    name: Deploy Core Infrastructure
    runs-on: ubuntu-latest
    outputs:
      cluster_endpoint: ${{ steps.outputs.outputs.cluster_endpoint }}
      kubeconfig_secret: ${{ steps.outputs.outputs.kubeconfig_secret }}
      ingress_ip: ${{ steps.outputs.outputs.ingress_ip }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Init
        working-directory: ./terraform
        run: terraform init
      
      - name: Terraform Apply
        working-directory: ./terraform
        env:
          HCLOUD_TOKEN: ${{ secrets.HCLOUD_TOKEN }}
        run: terraform apply -auto-approve
      
      - name: Extract Outputs
        id: outputs
        working-directory: ./terraform
        run: |
          echo "cluster_endpoint=$(terraform output -raw cluster_endpoint)" >> $GITHUB_OUTPUT
          echo "ingress_ip=$(terraform output -raw ingress_ip)" >> $GITHUB_OUTPUT
          
          # Save kubeconfig to GitHub secret for next stage
          KUBECONFIG=$(terraform output -raw kubeconfig)
          echo "::add-mask::$KUBECONFIG"
          echo "kubeconfig_secret=$KUBECONFIG" >> $GITHUB_OUTPUT
      
      - name: Save Infrastructure State
        run: |
          # Save outputs to artifact for Pulumi
          cat > infrastructure-outputs.json <<EOF
          {
            "cluster_endpoint": "${{ steps.outputs.outputs.cluster_endpoint }}",
            "ingress_ip": "${{ steps.outputs.outputs.ingress_ip }}",
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          }
          EOF
      
      - name: Upload Infrastructure Outputs
        uses: actions/upload-artifact@v4
        with:
          name: infrastructure-outputs
          path: infrastructure-outputs.json

  # ========================================
  # Stage 2: Pulumi Applications
  # ========================================
  pulumi-applications:
    name: Deploy Applications
    runs-on: ubuntu-latest
    needs: terraform-infrastructure
    steps:
      - uses: actions/checkout@v4
      
      - name: Download Infrastructure Outputs
        uses: actions/download-artifact@v4
        with:
          name: infrastructure-outputs
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      
      - name: Setup Pulumi
        uses: pulumi/actions@v5
      
      - name: Configure Kubernetes Access
        run: |
          # Use kubeconfig from Terraform
          echo "${{ needs.terraform-infrastructure.outputs.kubeconfig_secret }}" | base64 -d > kubeconfig.yaml
          export KUBECONFIG=$(pwd)/kubeconfig.yaml
      
      - name: Deploy Applications with Pulumi
        working-directory: ./pulumi
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
          CLUSTER_ENDPOINT: ${{ needs.terraform-infrastructure.outputs.cluster_endpoint }}
          INGRESS_IP: ${{ needs.terraform-infrastructure.outputs.ingress_ip }}
        run: |
          npm ci
          pulumi stack select production
          pulumi config set clusterEndpoint $CLUSTER_ENDPOINT
          pulumi config set ingressIP $INGRESS_IP
          pulumi up --yes
```

### Pattern 3: Remote State Data Source

#### Terraform Remote State Configuration

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "eu-central-1"
  }
}

# Expose state for external consumption
output "state_bucket" {
  value = "terraform-state"
}

output "state_key" {
  value = "infrastructure/terraform.tfstate"
}
```

#### Pulumi Reading Terraform State

```typescript
// pulumi/infrastructure-import.ts
import * as aws from "@pulumi/aws";
import { S3 } from "aws-sdk";

async function getTerraformOutputs() {
    const s3 = new S3({ region: "eu-central-1" });
    
    // Read Terraform state file
    const stateFile = await s3.getObject({
        Bucket: "terraform-state",
        Key: "infrastructure/terraform.tfstate"
    }).promise();
    
    const state = JSON.parse(stateFile.Body.toString());
    
    // Extract outputs
    return state.outputs.reduce((acc: any, output: any) => {
        acc[output.name] = output.value;
        return acc;
    }, {});
}

// Use in Pulumi program
export async function createApplicationStack() {
    const tfOutputs = await getTerraformOutputs();
    
    const k8sProvider = new k8s.Provider("k8s", {
        kubeconfig: tfOutputs.kubeconfig
    });
    
    // Deploy using Terraform-managed resources
    return deployApplications(k8sProvider, tfOutputs);
}
```

## Data Exchange Methods

### 1. Environment Variables

```yaml
# CI/CD passes Terraform outputs as env vars to Pulumi
env:
  CLUSTER_ENDPOINT: ${{ steps.terraform.outputs.cluster_endpoint }}
  INGRESS_IP: ${{ steps.terraform.outputs.ingress_ip }}
```

### 2. File-Based Exchange

```bash
# Terraform writes outputs
terraform output -json > outputs.json

# Pulumi reads outputs
const outputs = JSON.parse(fs.readFileSync('outputs.json'));
```

### 3. API/Service Based

```typescript
// Terraform publishes to API
resource "null_resource" "publish_outputs" {
  provisioner "local-exec" {
    command = <<EOF
      curl -X POST https://api.internal/infrastructure \
        -H "Content-Type: application/json" \
        -d '{"endpoint": "${module.k3s.endpoint}"}'
    EOF
  }
}

// Pulumi fetches from API
const infra = await fetch('https://api.internal/infrastructure');
const { endpoint } = await infra.json();
```

### 4. Shared State Store

```typescript
// Using AWS Parameter Store
import * as aws from "@pulumi/aws";

// Terraform writes
resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "/infrastructure/cluster/endpoint"
  type  = "String"
  value = module.k3s.api_endpoint
}

// Pulumi reads
const endpoint = aws.ssm.getParameter({
    name: "/infrastructure/cluster/endpoint"
}).then(p => p.value);
```

## Best Practices for Hybrid Architecture

### 1. Clear Boundaries

```yaml
Terraform Manages:
  - Cloud provider resources (servers, networks, load balancers)
  - Kubernetes cluster provisioning
  - Core platform services (DNS, certificates)
  - Persistent storage
  - Databases

Pulumi Manages:
  - Application deployments
  - Kubernetes configurations
  - Service mesh
  - Application secrets
  - Feature flags
```

### 2. Consistent Naming

```typescript
// Agree on naming conventions across tools
const naming = {
    terraform: "tf-{env}-{resource}",
    pulumi: "pl-{env}-{app}-{resource}",
    shared: "{company}-{env}-{resource}"
};
```

### 3. Version Locking

```hcl
# Terraform version constraint
terraform {
  required_version = "~> 1.5.0"
}
```

```json
// Pulumi package.json
{
  "dependencies": {
    "@pulumi/pulumi": "3.100.0"
  }
}
```

### 4. State Isolation

```bash
# Separate state backends
terraform/
  ├── .terraform/      # Terraform state
  └── backend.tf       # S3 backend

pulumi/
  ├── Pulumi.yaml     # Pulumi project
  └── Pulumi.prod.yaml # Pulumi state
```

### 5. Dependency Management

```typescript
// Document dependencies clearly
interface InfrastructureDependencies {
    clusterEndpoint: string;  // From Terraform output "cluster_endpoint"
    ingressIP: string;        // From Terraform output "ingress_ip"
    networkId: string;        // From Terraform output "network_id"
}

// Validate dependencies
function validateDependencies(deps: Partial<InfrastructureDependencies>) {
    const required = ['clusterEndpoint', 'ingressIP'];
    for (const key of required) {
        if (!deps[key]) {
            throw new Error(`Missing required dependency: ${key}`);
        }
    }
}
```

## Migration Strategies

### Strategy 1: Bottom-Up (Applications First)

```
Week 1-2: Move application deployments to Pulumi
Week 3-4: Move Kubernetes configurations to Pulumi
Week 5-6: Move platform services to Pulumi
Week 7-8: Evaluate infrastructure layer migration
```

### Strategy 2: New Services Only

```typescript
// Policy: New services use Pulumi, existing stay in Terraform
if (service.createdAfter('2024-01-01')) {
    deployWithPulumi(service);
} else {
    maintainWithTerraform(service);
}
```

### Strategy 3: Gradual Layer Migration

```
Phase 1: Applications (Pulumi)
Phase 2: Kubernetes resources (Pulumi)
Phase 3: Cloud resources (Evaluate)
Phase 4: Networking (Stay in Terraform)
```

## Example: Complete Hybrid Setup

### Directory Structure

```
project/
├── .github/
│   └── workflows/
│       ├── terraform-infra.yml
│       ├── pulumi-apps.yml
│       └── hybrid-deploy.yml
├── terraform/
│   ├── main.tf
│   ├── k3s.tf
│   ├── network.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── pulumi/
│   ├── apps/
│   │   ├── index.ts
│   │   ├── api.ts
│   │   └── frontend.ts
│   ├── package.json
│   └── Pulumi.yaml
└── shared/
    ├── outputs/
    └── configs/
```

### Terraform Infrastructure Code

```hcl
# terraform/main.tf
module "k3s_cluster" {
  source = "./modules/k3s"
  
  cluster_name = "production"
  node_count   = 5
}

module "database" {
  source = "./modules/rds"
  
  engine  = "postgres"
  version = "14"
}

# Output for Pulumi consumption
output "infrastructure" {
  value = {
    cluster = {
      endpoint   = module.k3s_cluster.endpoint
      kubeconfig = module.k3s_cluster.kubeconfig
    }
    database = {
      endpoint = module.database.endpoint
      port     = module.database.port
    }
  }
  sensitive = true
}
```

### Pulumi Application Code

```typescript
// pulumi/apps/index.ts
import * as pulumi from "@pulumi/pulumi";
import * as k8s from "@pulumi/kubernetes";
import { getInfrastructure } from "../lib/terraform-bridge";

async function deployApplications() {
    // Get Terraform outputs
    const infra = await getInfrastructure();
    
    // Configure K8s provider
    const k8sProvider = new k8s.Provider("k8s", {
        kubeconfig: infra.cluster.kubeconfig
    });
    
    // Deploy application with database connection
    const api = new k8s.apps.v1.Deployment("api", {
        spec: {
            template: {
                spec: {
                    containers: [{
                        name: "api",
                        image: "myapp:latest",
                        env: [
                            {
                                name: "DB_HOST",
                                value: infra.database.endpoint
                            },
                            {
                                name: "DB_PORT",
                                value: infra.database.port.toString()
                            }
                        ]
                    }]
                }
            }
        }
    }, { provider: k8sProvider });
    
    return { apiEndpoint: api.status.loadBalancer.ingress[0].ip };
}

export = deployApplications();
```

### Orchestration Workflow

```yaml
# .github/workflows/hybrid-deploy.yml
name: Hybrid Deployment

on:
  push:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      infra_changed: ${{ steps.changes.outputs.infra }}
      apps_changed: ${{ steps.changes.outputs.apps }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            infra:
              - 'terraform/**'
            apps:
              - 'pulumi/**'
              - 'src/**'

  deploy-infrastructure:
    needs: detect-changes
    if: needs.detect-changes.outputs.infra_changed == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy with Terraform
        run: |
          cd terraform
          terraform init
          terraform apply -auto-approve
          terraform output -json > ../infrastructure-outputs.json
      
      - name: Store Outputs
        uses: actions/upload-artifact@v4
        with:
          name: infra-outputs
          path: infrastructure-outputs.json

  deploy-applications:
    needs: [detect-changes, deploy-infrastructure]
    if: |
      always() && 
      (needs.detect-changes.outputs.apps_changed == 'true' ||
       needs.detect-changes.outputs.infra_changed == 'true')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Get Infrastructure Outputs
        uses: actions/download-artifact@v4
        with:
          name: infra-outputs
        continue-on-error: true
      
      - name: Deploy with Pulumi
        env:
          INFRA_OUTPUTS: ${{ steps.infra.outputs.data }}
        run: |
          cd pulumi
          npm ci
          pulumi up --yes
```

## Monitoring & Observability

### Unified Monitoring

```typescript
// Monitor both Terraform and Pulumi deployments
const monitoring = new k8s.apps.v1.Deployment("monitoring", {
    spec: {
        template: {
            spec: {
                containers: [{
                    name: "grafana",
                    env: [
                        {
                            name: "TERRAFORM_STATE_BUCKET",
                            value: "terraform-state"
                        },
                        {
                            name: "PULUMI_API_ENDPOINT",
                            value: "https://api.pulumi.com"
                        }
                    ]
                }]
            }
        }
    }
});
```

## Conclusion

The hybrid Terraform-Pulumi approach offers:

1. **Flexibility**: Use the right tool for each layer
2. **Risk Management**: Isolate infrastructure from application changes
3. **Team Efficiency**: Teams use familiar tools
4. **Gradual Migration**: Move to Pulumi at your own pace
5. **Best Practices**: Leverage strengths of both tools

This architecture is particularly suitable for:
- Large organizations with existing Terraform investments
- Teams with different skill sets
- Complex environments requiring specialized tools
- Gradual cloud-native transformation projects