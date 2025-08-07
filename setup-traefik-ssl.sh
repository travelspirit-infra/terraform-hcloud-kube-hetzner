#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up SSL with Traefik's built-in Let's Encrypt support...${NC}"

# Control plane node
CONTROL_PLANE_IP="2a01:4f8:1c1b:f096::1"

echo -e "${YELLOW}1. Updating Traefik deployment with SSL support...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
# First, let's check current Traefik setup
echo "Current Traefik pods:"
kubectl get pods -n kube-system | grep traefik

# Update Traefik deployment to include Let's Encrypt
kubectl -n kube-system patch daemonset traefik --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--certificatesresolvers.letsencrypt.acme.email=patrick@travelspirit.nl"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory"
  }
]' || echo "Failed to patch, may need manual configuration"

# Add volume for Let's Encrypt certificates
kubectl -n kube-system patch daemonset traefik --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "acme",
      "hostPath": {
        "path": "/var/lib/traefik",
        "type": "DirectoryOrCreate"
      }
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {
      "name": "acme",
      "mountPath": "/data"
    }
  }
]' || echo "Volume may already exist"
EOF

echo -e "${YELLOW}2. Creating HTTPS redirect middleware...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
cat <<MIDDLEWARE | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: default
spec:
  redirectScheme:
    scheme: https
    permanent: true
MIDDLEWARE
EOF

echo -e "${YELLOW}3. Creating ingress for k8s.travelspirit.cloud with SSL...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
# Create ingress with Let's Encrypt annotation
cat <<INGRESS | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k8s-dashboard-ssl
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: letsencrypt
spec:
  ingressClassName: traefik
  rules:
  - host: k8s.travelspirit.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world
            port:
              number: 80
  tls:
  - hosts:
    - k8s.travelspirit.cloud
INGRESS

# Update default ingress with HTTPS redirect
kubectl delete ingress hello-world -n default --ignore-not-found=true

cat <<INGRESS | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.middlewares: default-redirect-https@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world
            port:
              number: 80
INGRESS
EOF

echo -e "${YELLOW}4. Waiting for Traefik to restart...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
kubectl rollout restart daemonset/traefik -n kube-system
sleep 10
kubectl get pods -n kube-system | grep traefik
EOF

echo -e "${GREEN}SSL setup complete!${NC}"
echo ""
echo "Please ensure DNS is configured:"
echo "  k8s.travelspirit.cloud -> 167.235.110.121"
echo ""
echo "You can check ingress status with:"
echo "  ssh -6 root@${CONTROL_PLANE_IP} 'kubectl get ingress -A'"
echo ""
echo "Test HTTPS access:"
echo "  curl -I https://k8s.travelspirit.cloud"
echo ""
echo "Note: Let's Encrypt certificate generation may take a few minutes."