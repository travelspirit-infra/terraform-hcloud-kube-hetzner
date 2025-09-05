#!/bin/bash
# Script to create Keycloak service account client for API automation

source keycloak-api-config.sh

# Get admin token
TOKEN=$(get_admin_token)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Failed to get admin token. Check your credentials."
    exit 1
fi

# Create service account client
CLIENT_JSON='{
  "clientId": "keycloak-admin-api",
  "name": "Keycloak Admin API Client",
  "description": "Service account for automated Keycloak administration",
  "protocol": "openid-connect",
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": false,
  "standardFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "implicitFlowEnabled": false,
  "attributes": {
    "access.token.lifespan": "3600"
  }
}'

# Create the client
CLIENT_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${CLIENT_JSON}")

if [ $? -eq 0 ]; then
    echo "✅ Service account client created successfully"
    
    # Get client ID (internal ID, not clientId)
    INTERNAL_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=keycloak-admin-api" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')
    
    # Get client secret
    CLIENT_SECRET=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${INTERNAL_ID}/client-secret" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.value')
    
    echo "Client ID: keycloak-admin-api"
    echo "Client Secret: ${CLIENT_SECRET}"
    echo ""
    echo "Add this to your environment:"
    echo "export KEYCLOAK_CLIENT_SECRET=\"${CLIENT_SECRET}\""
    
    # Assign service account roles
    echo ""
    echo "🔧 Assigning service account roles..."
    
    # Get service account user ID
    SERVICE_ACCOUNT_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${INTERNAL_ID}/service-account-user" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.id')
    
    # Get realm management client ID
    REALM_MGMT_CLIENT_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=realm-management" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')
    
    # Get available roles
    AVAILABLE_ROLES=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${REALM_MGMT_CLIENT_ID}/roles" \
        -H "Authorization: Bearer ${TOKEN}")
    
    # Extract specific role IDs we want to assign
    MANAGE_CLIENTS_ROLE=$(echo "$AVAILABLE_ROLES" | jq -r '.[] | select(.name=="manage-clients")')
    MANAGE_USERS_ROLE=$(echo "$AVAILABLE_ROLES" | jq -r '.[] | select(.name=="manage-users")')
    MANAGE_REALM_ROLE=$(echo "$AVAILABLE_ROLES" | jq -r '.[] | select(.name=="manage-realm")')
    VIEW_CLIENTS_ROLE=$(echo "$AVAILABLE_ROLES" | jq -r '.[] | select(.name=="view-clients")')
    VIEW_USERS_ROLE=$(echo "$AVAILABLE_ROLES" | jq -r '.[] | select(.name=="view-users")')
    
    # Assign roles
    ROLES_TO_ASSIGN="[${MANAGE_CLIENTS_ROLE},${MANAGE_USERS_ROLE},${VIEW_CLIENTS_ROLE},${VIEW_USERS_ROLE}]"
    
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/users/${SERVICE_ACCOUNT_ID}/role-mappings/clients/${REALM_MGMT_CLIENT_ID}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${ROLES_TO_ASSIGN}"
    
    echo "✅ Service account roles assigned"
    
else
    echo "❌ Failed to create service account client"
    echo "$CLIENT_RESPONSE"
fi