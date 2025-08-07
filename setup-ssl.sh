#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up SSL for K3s cluster...${NC}"

# Control plane node
CONTROL_PLANE_IP="2a01:4f8:1c1b:f096::1"

echo -e "${YELLOW}1. Installing cert-manager...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml

# Wait for cert-manager to be ready
echo "Waiting for cert-manager pods to be ready..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s
EOF

echo -e "${YELLOW}2. Creating Let's Encrypt ClusterIssuer...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
cat <<ISSUER | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: patrick@travelspirit.nl
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: patrick@travelspirit.nl
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
ISSUER
EOF

echo -e "${YELLOW}3. Creating ingress for k8s.travelspirit.cloud...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
cat <<INGRESS | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k8s-dashboard
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - k8s.travelspirit.cloud
    secretName: k8s-travelspirit-cloud-tls
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
INGRESS
EOF

echo -e "${YELLOW}4. Updating existing hello-world ingress with SSL...${NC}"
ssh -6 root@${CONTROL_PLANE_IP} << 'EOF'
# First delete the existing ingress
kubectl delete ingress hello-world -n default --ignore-not-found=true

# Create new ingress with SSL
cat <<INGRESS | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.middlewares: default-redirect-https@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - "*"
    secretName: wildcard-tls
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

# Create HTTPS redirect middleware
cat <<MIDDLEWARE | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
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

echo -e "${GREEN}SSL setup complete!${NC}"
echo -e "${YELLOW}Note: It may take a few minutes for Let's Encrypt to issue certificates.${NC}"
echo ""
echo "You can check certificate status with:"
echo "ssh -6 root@${CONTROL_PLANE_IP} 'kubectl get certificate -A'"
echo ""
echo "Check ingress status with:"
echo "ssh -6 root@${CONTROL_PLANE_IP} 'kubectl get ingress -A'"