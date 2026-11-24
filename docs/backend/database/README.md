# Database Migrations

This directory contains database migration scripts for the Admin Center feature.

> **Verified against code:** there is no `run-migration.js` in `services/api-backend/database/`. The runner is `services/api-backend/database/migrate-pg.js` (`DatabaseMigratorPG`), applied at backend startup (`services/api-backend/server.js:563-578` → `migrate-pg.js:328-355`); it has no `up`/`down`/`status` CLI. Forward SQL lives in `services/api-backend/database/migrations/`, while rollback SQL lives in `services/api-backend/database/rollbacks/` (both `001_admin_center_schema_rollback.sql` and `003_email_relay_dns_setup_rollback.sql` are there). No standalone migrate-pg guide exists — `migrate-pg.js` is the source of truth.

## Overview

Migrations are versioned SQL scripts that modify the database schema. Each migration has:

- A forward migration file (e.g., `001_admin_center_schema.sql`, in `services/api-backend/database/migrations/`)
- A rollback file (e.g., `001_admin_center_schema_rollback.sql`, in `services/api-backend/database/rollbacks/`)
- A tracking entry in the `schema_migrations` table

## Migration Files

### 001_admin_center_schema.sql

Creates the core admin center tables:

- `subscriptions` - User subscription information
- `payment_transactions` - Payment transaction records
- `payment_methods` - User payment method details
- `refunds` - Refund records
- `admin_roles` - Administrator role assignments
- `admin_audit_logs` - Audit trail of admin actions

## Usage

### Prerequisites

1. Ensure PostgreSQL is running and accessible
2. Set environment variables for database connection:

   ```bash
   export DATABASE_URL="postgresql://user:password@host:port/database"
   # OR
   export PGHOST=localhost
   export PGPORT=5432
   export PGDATABASE=Pistisai
   export PGUSER=postgres
   export PGPASSWORD=yourpassword
   ```

3. Install dependencies (if not already installed):

   ```bash
   cd services/api-backend
   npm install
   ```

### Running Migrations

Migrations are applied automatically at backend startup by `DatabaseMigratorPG.migrate()` (`services/api-backend/server.js:563-578`, `database/migrate-pg.js:328-355`). There is no `run-migration.js` CLI; use the direct `psql` commands below.

#### Apply a Migration

```bash
psql -h localhost -U postgres -d Pistisai -f services/api-backend/database/migrations/001_admin_center_schema.sql
```

#### Rollback a Migration

Rollback files are in `services/api-backend/database/rollbacks/`:

```bash
psql -h localhost -U postgres -d Pistisai -f services/api-backend/database/rollbacks/001_admin_center_schema_rollback.sql
```

#### Check Migration Status

`DatabaseMigratorPG.getAppliedMigrations()` (`services/api-backend/database/migrate-pg.js:169-174`) queries the tracking table internally; there is no `status` CLI:

```sql
SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;
```

### Manual Execution

You can also run migrations manually using `psql`:

#### Apply Migration

```bash
psql -h localhost -U postgres -d Pistisai -f services/api-backend/database/migrations/001_admin_center_schema.sql
```

#### Rollback Migration

Rollback SQL is in `services/api-backend/database/rollbacks/`, not `migrations/`:

```bash
psql -h localhost -U postgres -d Pistisai -f services/api-backend/database/rollbacks/001_admin_center_schema_rollback.sql
```

## Migration Tracking

The `schema_migrations` table tracks which migrations have been applied:

```sql
SELECT * FROM schema_migrations ORDER BY applied_at DESC;
```

Columns:

- `version` - Migration version (e.g., '001')
- `name` - Migration name
- `applied_at` - When the migration was applied
- `rolled_back_at` - When the migration was rolled back (NULL if still applied)

## Creating New Migrations

1. Create a new migration file with the next version number:

   ```
   002_feature_name.sql
   ```

2. Create a corresponding rollback file in `services/api-backend/database/rollbacks/` (not in `migrations/`):

   ```
   002_feature_name_rollback.sql
   ```

3. Follow the existing migration structure:
   - Add comments explaining the changes
   - Use `IF NOT EXISTS` for idempotency
   - Create indexes for performance
   - Add triggers for `updated_at` columns
   - Include rollback logic in the rollback file

4. Test the migration (no `run-migration.js` CLI — verified above):

   ```bash
   # Apply
   psql -h localhost -U postgres -d Pistisai -f services/api-backend/database/migrations/002_feature_name.sql

   # Verify
   psql -h localhost -U postgres -d Pistisai -c "SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;"

   # Rollback (if needed) — from database/rollbacks/
   psql -h localhost -U postgres -d Pistisai -f services/api-backend/database/rollbacks/002_feature_name_rollback.sql
   ```

## Best Practices

1. **Always use transactions** - The migration runner wraps each migration in a transaction
2. **Test rollbacks** - Always test that rollbacks work correctly
3. **Backup before production** - Always backup the database before running migrations in production
4. **Idempotent migrations** - Use `IF NOT EXISTS` and `IF EXISTS` to make migrations idempotent
5. **Document changes** - Add comments explaining what each migration does
6. **Version control** - Commit migration files to version control

## Troubleshooting

### Migration fails with "relation already exists"

The migration may have been partially applied. Check the database state and either:

- Manually clean up the partial migration
- Use the rollback script
- Make the migration idempotent with `IF NOT EXISTS`

### Cannot connect to database

Check your environment variables and ensure PostgreSQL is running:

```bash
psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version();"
```

### Migration tracking table not found

The tracking table is created by the startup migrator (`DatabaseMigratorPG.createMigrationsTable()`, `services/api-backend/database/migrate-pg.js:59`, called at `services/api-backend/server.js:574`). There is no `run-migration.js status` command; to inspect it:

```bash
psql -h localhost -U postgres -d Pistisai -c "SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;"
```

## Production Deployment

For production deployments:

1. **Backup the database first**:

   ```bash
   pg_dump -h $PGHOST -U $PGUSER -d $PGDATABASE > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

2. **Test in staging environment** before production

3. **Run migrations during maintenance window** if possible

4. **Apply the migration** (no `run-migration.js` CLI — migrations also apply at startup; verified above):

   ```bash
   psql -h $PGHOST -U $PGUSER -d $PGDATABASE -f services/api-backend/database/migrations/001_admin_center_schema.sql 2>&1 | tee migration.log
   ```

5. **Verify the migration**:

   ```bash
   psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "SELECT version, name, applied_at FROM schema_migrations WHERE success = TRUE ORDER BY applied_at;"
   psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c "\dt"
   ```

6. **Have rollback plan ready** in case of issues

## Support

For issues or questions about migrations, refer to:

- Admin Center Design Document: `.kiro/specs/admin-center/design.md`
- Admin Center Requirements: `.kiro/specs/admin-center/requirements.md`
- Database Schema: `services/api-backend/database/schema.pg.sql`
