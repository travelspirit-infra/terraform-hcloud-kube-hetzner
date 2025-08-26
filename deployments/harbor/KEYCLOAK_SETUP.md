# Harbor Keycloak Integration Setup

Harbor is now configured to use Keycloak for authentication, but you need to complete the Keycloak client setup.

## Keycloak Client Configuration

### 1. Create Harbor Client in Keycloak

For **both realms** (`master` and `travelspirit`):

1. **Access Keycloak Admin**: https://auth.travelspirit.app/admin/
2. **Select Realm**: Switch between `master` and `travelspirit` 
3. **Create Client**:
   - **Client ID**: `harbor`
   - **Protocol**: `openid-connect`
   - **Access Type**: `confidential`
   - **Standard Flow Enabled**: `ON`
   - **Direct Access Grants**: `ON`

### 2. Configure Client Settings

**Valid Redirect URIs**:
```
https://harbor.travelspirit.cloud/c/oidc/callback
https://harbor.travelspirit.cloud/c/oidc/login
```

**Web Origins**: 
```
https://harbor.travelspirit.cloud
```

### 3. Create Groups and Roles

Create these groups in Keycloak:
- **harbor-admins**: Full Harbor admin access
- **harbor-users**: Regular Harbor user access

### 4. Configure Group Mappings

1. **Client Scopes** → **groups** → **Mappers**
2. **Create Mapper**:
   - **Name**: `groups`
   - **Mapper Type**: `Group Membership`
   - **Token Claim Name**: `groups`
   - **Add to ID Token**: `ON`
   - **Add to Access Token**: `ON`
   - **Add to User Info**: `ON`

### 5. Get Client Secret

1. Go to **Clients** → **harbor** → **Credentials**
2. Copy the **Secret** value
3. Update Harbor configuration with this secret

## Update Harbor Configuration

Once you have the client secret, update the Harbor deployment:

```bash
# Edit the client secret in deployments/harbor/simple-deploy.yaml
# Replace: clientSecret: "KEYCLOAK_CLIENT_SECRET_TO_BE_SET"
# With:    clientSecret: "your-actual-client-secret"

# Then apply the updated configuration:
kubectl apply -f deployments/harbor/simple-deploy.yaml
```

## Supporting Multiple Realms

Harbor supports only one OIDC provider at a time. For access from both realms:

**Option 1: Use `travelspirit` realm** (recommended)
- Configure Harbor to use `travelspirit` realm
- Create Harbor groups/users in `travelspirit` realm

**Option 2: Create cross-realm trust**
- Configure identity broker in `travelspirit` realm
- Import `master` realm users via identity federation

## Test Authentication

After configuration:
1. Navigate to https://harbor.travelspirit.cloud
2. Click "LOGIN VIA OIDC PROVIDER" 
3. Should redirect to Keycloak login
4. After login, should return to Harbor with user authenticated

## User Management

- **Admin users**: Add to `harbor-admins` group in Keycloak
- **Regular users**: Add to `harbor-users` group in Keycloak  
- **Auto-onboarding**: Enabled - new users created automatically on first login