# TravelSpirit Keycloak Realm Design Recommendations

Based on 2024 best practices and your company structure.

## Current Structure Analysis

**Your Context:**
- **Company**: TravelSpirit (13 employees: 8 NL, 5 India)
- **User Types**: Keycloak admins, developers, support staff, tenant customers
- **Applications**: Grafana, Harbor, future services

## Recommended Architecture: Enhanced Single Realm

### Keep Current Structure + Enhancements

```
master realm (unchanged)
├── Keycloak administrators only
└── System-level access

travelspirit realm (enhanced)
├── Internal Users
│   ├── developers (NL + India teams)  
│   ├── support-staff
│   └── operations
├── Customer Tenants  
│   ├── tenant-1-users
│   ├── tenant-2-users
│   └── tenant-n-users
└── Service Groups
    ├── grafana-admins, grafana-users
    ├── harbor-admins, harbor-users
    └── future-service-groups
```

## Implementation Strategy

### 1. Group Hierarchy in `travelspirit` Realm

**Internal Staff Groups:**
```
/internal
  /internal/developers
  /internal/support  
  /internal/operations
  /internal/admins
```

**Customer Tenant Groups:**
```
/tenants
  /tenants/customer-a
  /tenants/customer-b
  /tenants/customer-c
```

**Service Access Groups:**
```
/services
  /services/harbor-admins
  /services/harbor-users
  /services/grafana-admins
  /services/grafana-users
```

### 2. User Attributes for Multi-Tenancy

Add custom attributes to users:
- **`tenant_id`**: Customer identifier (e.g., "customer-a", "internal")
- **`department`**: "development", "support", "operations"
- **`access_level`**: "admin", "user", "readonly"

### 3. Client Scopes for Applications

Create mappers that include:
- **Groups**: All user groups
- **Tenant ID**: Custom attribute for tenant isolation
- **Department**: For internal role-based access

## Benefits of This Design

### ✅ Advantages
- **Single realm performance** (vs 100+ tenant realms)
- **Unified user management** for internal staff
- **Flexible tenant isolation** via groups/attributes
- **Ready for Keycloak Organizations** (v25+ migration path)
- **Consistent with current Grafana setup**

### 🎯 Harbor Configuration Impact

**Harbor Groups Mapping:**
```yaml
oidc:
  endpoint: "https://auth.travelspirit.app/auth/realms/travelspirit"
  adminGroup: "/services/harbor-admins"  # Full path
  # Maps to: internal/admins + internal/developers (admin level)
```

**User Access Logic:**
- **Internal admins/developers** → `harbor-admins` group → Full access
- **Internal support** → `harbor-users` group → Pull/push access  
- **Customer users** → No Harbor access (unless explicitly granted)

## Migration Path

### Immediate (Current Keycloak)
1. **Keep `master`** for Keycloak administration
2. **Enhance `travelspirit`** with proper group hierarchy
3. **Configure Harbor** to use `travelspirit` realm

### Future (Keycloak v25+)
- **Migrate to Organizations feature** within `travelspirit` realm
- **Each customer** becomes an Organization
- **Better tenant isolation** without performance penalties

## Implementation Steps

1. **Restructure `travelspirit` realm groups** (hierarchical)
2. **Add user attributes** for tenant/department tracking
3. **Create Harbor client** in `travelspirit` realm
4. **Map internal staff** to appropriate Harbor groups
5. **Test authentication flow**

This design scales to hundreds of customer tenants while maintaining performance and follows 2024 best practices.