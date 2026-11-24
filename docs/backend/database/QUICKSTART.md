# Database Setup Quickstart

Quick reference for setting up the Admin Center database schema and test data.

## Prerequisites

1. PostgreSQL 12+ installed and running
2. Node.js 26 installed — the backend declares `"node": ">=26.0.0 <28.0.0"` (`services/api-backend/package.json:67-69`); the old "18+" guidance was stale
3. Database created: `Pistisai`
4. Environment variables configured

> **Verified against code:** there is no `run-migration.js` in `services/api-backend/database/`. The runner is `database/migrate-pg.js`, and migrations are applied at backend startup (`services/api-backend/server.js:563-578` → `migrate-pg.js:328-355`); it has no `up`/`down`/`status` CLI. Rollbacks live in `services/api-backend/database/rollbacks/`, not `migrations/`. The `run-migration.js` commands shown in older docs are historical and would fail; the equivalent direct `psql` commands are shown below. `database/seeds/run-seed.js` does exist, so the seed commands are valid.

## Environment Setup

```bash
# Option 1: Using DATABASE_URL
export DATABASE_URL="postgresql://postgres:password@localhost:5432/Pistisai"

# Option 2: Using individual variables
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=Pistisai
export PGUSER=postgres
export PGPASSWORD=yourpassword

# For development
export NODE_ENV=development
```

## Quick Setup (Development)

```bash
# 1. Navigate to the project root
cd /path/to/Pistisai

# 2. Install dependencies (if not already done)
cd services/api-backend
npm install

# 3. Apply base schema (if not already applied)
psql -h localhost -U postgres -d Pistisai -f database/schema.pg.sql

# 4. Apply admin center migration
psql -h localhost -U postgres -d Pistisai -f database/migrations/001_admin_center_schema.sql

# 5. Apply seed data (development only)
node database/seeds/run-seed.js apply 001

# 6. Verify setup
node database/seeds/run-seed.js apply 001 | tail -10
```

## Common Commands

### Migrations

```bash
# Check migration status
psql -h localhost -U postgres -d Pistisai -c "SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;"

# Apply migration
psql -h localhost -U postgres -d Pistisai -f database/migrations/001_admin_center_schema.sql

# Rollback migration
psql -h localhost -U postgres -d Pistisai -f database/rollbacks/001_admin_center_schema_rollback.sql
```

### Seed Data (Development Only)

```bash
# Apply seed data
node database/seeds/run-seed.js apply 001

# Clean seed data
node database/seeds/run-seed.js clean
```

### Manual SQL Execution

```bash
# Apply migration manually
psql -h localhost -U postgres -d Pistisai -f database/migrations/001_admin_center_schema.sql

# Apply seed data manually
psql -h localhost -U postgres -d Pistisai -f database/seeds/001_admin_center_dev_data.sql

# Rollback migration manually (rollback files are in database/rollbacks/)
psql -h localhost -U postgres -d Pistisai -f database/rollbacks/001_admin_center_schema_rollback.sql
```

## Verification Queries

```bash
# Check tables exist
psql -h localhost -U postgres -d Pistisai -c "\dt"

# Check admin center tables
psql -h localhost -U postgres -d Pistisai -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('subscriptions', 'payment_transactions', 'payment_methods', 'refunds', 'admin_roles', 'admin_audit_logs');"

# Check test data
psql -h localhost -U postgres -d Pistisai -c "SELECT COUNT(*) as test_users FROM users WHERE email LIKE 'test.%@example.com';"

# Check admin roles
psql -h localhost -U postgres -d Pistisai -c "SELECT u.email, ar.role, ar.is_active FROM admin_roles ar JOIN users u ON ar.user_id = u.id;"
```

## Reset Database (Development)

```bash
# Complete reset
node database/seeds/run-seed.js clean
psql -h localhost -U postgres -d Pistisai -f database/rollbacks/001_admin_center_schema_rollback.sql
psql -h localhost -U postgres -d Pistisai -f database/migrations/001_admin_center_schema.sql
node database/seeds/run-seed.js apply 001
```

## Production Deployment

```bash
# 1. Backup database first!
pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Apply migration only (NO seed data in production!)
# No run-migration.js CLI exists: migrations apply at startup via migrate-pg.js,
# or apply the SQL directly:
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -f database/migrations/001_admin_center_schema.sql

# 3. Verify migration (no status CLI; query the tracking table)
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;"

# 4. Verify tables
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "\dt"
```

## Troubleshooting

### Connection Issues

```bash
# Test connection
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version();"

# Check environment variables
echo $DATABASE_URL
echo $PGHOST $PGPORT $PGDATABASE $PGUSER
```

### Migration Already Applied

```bash
# Check status
psql -h localhost -U postgres -d Pistisai -c "SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;"

# If needed, rollback and reapply
psql -h localhost -U postgres -d Pistisai -f database/rollbacks/001_admin_center_schema_rollback.sql
psql -h localhost -U postgres -d Pistisai -f database/migrations/001_admin_center_schema.sql
```

### Seed Data Already Exists

```bash
# Clean and reapply
node database/seeds/run-seed.js clean
node database/seeds/run-seed.js apply 001
```

## File Structure

```
services/api-backend/database/
├── schema.pg.sql                            # Base schema
├── migrate-pg.js                            # Migration runner (DatabaseMigratorPG)
├── migrate-auth-pg.js                       # Auth database migration runner
├── db-pool.js                               # Connection pool (getPool)
├── migrations/
│   ├── 001_admin_center_schema.sql          # Admin center migration
│   └── 003_email_relay_dns_setup.sql        # Email relay / DNS migration
├── rollbacks/
│   ├── 001_admin_center_schema_rollback.sql
│   └── 003_email_relay_dns_setup_rollback.sql
└── seeds/
    ├── run-seed.js                          # Seed runner (exists)
    └── 001_admin_center_dev_data.sql        # Test data
```

Verified from `services/api-backend/database/`: there is no `run-migration.js`, no `migrations/README.md` and no `seeds/README.md`.

## Next Steps

After setting up the database:

1. **Backend API**: Implement admin authentication middleware (Task 2.1)
2. **Frontend Models**: Create Dart models for subscriptions, payments, etc. (Task 11)
3. **Payment Gateway**: Set up Stripe SDK integration (Task 4.1)

## Documentation

- Migrations: this guide, `services/api-backend/database/migrate-pg.js` (the runner; no `migrations/README.md` exists), SQL in `services/api-backend/database/migrations/` and rollbacks in `services/api-backend/database/rollbacks/`
- Seed Data: `services/api-backend/database/seeds/run-seed.js` (no `seeds/README.md` exists)
- Admin Center Design: `.kiro/specs/admin-center/design.md`
- Admin Center Requirements: `.kiro/specs/admin-center/requirements.md`
- Admin Center Tasks: `.kiro/specs/admin-center/tasks.md`
