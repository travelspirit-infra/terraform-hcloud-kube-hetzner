# Test User Database Access

## Test User Credentials

- **Database**: `testing`
- **Username**: `testuser`
- **Password**: `test123`

## Connection Endpoints

- **Read-Write**: `postgres-rw.postgres.svc.cluster.local:5432`
- **Read-Only**: `postgres-ro.postgres.svc.cluster.local:5432`

## Quick Test Commands

### Test Connection with Temporary Pod
```bash
# Read-write connection
kubectl --kubeconfig barry-kubeconfig.yaml run postgres-test --image=postgres:16-alpine --rm -it --restart=Never --env="PGPASSWORD=test123" -- psql -h postgres-rw.postgres.svc.cluster.local -U testuser -d testing

# Read-only connection
kubectl --kubeconfig barry-kubeconfig.yaml run postgres-test --image=postgres:16-alpine --rm -it --restart=Never --env="PGPASSWORD=test123" -- psql -h postgres-ro.postgres.svc.cluster.local -U testuser -d testing
```

### Port Forward for Local Access
```bash
# Set up port forward (run in one terminal)
kubectl --kubeconfig barry-kubeconfig.yaml port-forward -n postgres service/postgres-rw 5432:5432

# Connect from local machine (run in another terminal)
psql -h localhost -p 5432 -U testuser -d testing
# Password: test123
```

## Connection String Format

```bash
# For applications
postgresql://testuser:test123@postgres-rw.postgres.svc.cluster.local:5432/testing

# For local development (after port-forward)
postgresql://testuser:test123@localhost:5432/testing
```

## Test Table

The `testing` database contains a simple test table:
```sql
CREATE TABLE test_table (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

You can verify everything works by running:
```sql
SELECT * FROM test_table;
```

## Permissions

The testuser has:
- `CONNECT` privilege on the `testing` database
- `ALL` privileges on the `testing` database
- `ALL` privileges on the `public` schema
- `CREATE` privilege on the `public` schema