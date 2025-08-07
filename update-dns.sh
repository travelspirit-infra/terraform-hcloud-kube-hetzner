#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load Cloudflare credentials
source ~/.claude/env/cloudflare

echo -e "${GREEN}Updating DNS configuration for k8s.travelspirit.cloud...${NC}"

# Get the record ID for k8s.travelspirit.cloud
echo -e "${YELLOW}1. Getting DNS record ID...${NC}"
RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_TRAVELSPIRIT_CLOUD_ZONE_ID}/dns_records?name=k8s.travelspirit.cloud" \
  -H "Authorization: Bearer ${CLOUDFLARE_TUNNEL_API_TOKEN}" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo $RECORD_INFO | jq -r '.result[0].id')
echo "Record ID: $RECORD_ID"

if [ "$RECORD_ID" == "null" ]; then
  echo -e "${YELLOW}2. Creating new DNS record...${NC}"
  # Create new A record pointing to load balancer
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_TRAVELSPIRIT_CLOUD_ZONE_ID}/dns_records" \
    -H "X-Auth-Email: pcmulder89@gmail.com" \
    -H "X-Auth-Key: ${CLOUDFLARE_TRAVELSPIRIT_CLOUD_GLOBAL_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
      "type": "A",
      "name": "k8s",
      "content": "167.235.110.121",
      "ttl": 120,
      "proxied": false
    }' | jq .
else
  echo -e "${YELLOW}2. Updating existing DNS record...${NC}"
  # Update existing record to point directly to load balancer (no proxy)
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_TRAVELSPIRIT_CLOUD_ZONE_ID}/dns_records/${RECORD_ID}" \
    -H "X-Auth-Email: pcmulder89@gmail.com" \
    -H "X-Auth-Key: ${CLOUDFLARE_TRAVELSPIRIT_CLOUD_GLOBAL_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
      "type": "A",
      "name": "k8s",
      "content": "167.235.110.121",
      "ttl": 120,
      "proxied": false
    }' | jq .
fi

echo -e "${GREEN}DNS update complete!${NC}"
echo ""
echo "DNS changes may take a few minutes to propagate."
echo "You can verify with: dig k8s.travelspirit.cloud +short"
echo ""
echo "Once DNS propagates, test with:"
echo "  curl -I https://k8s.travelspirit.cloud"