# Database Testing

This directory contains example migration files and test scripts for reference and testing purposes.

## Purpose

Since we are still in the **design stage** and have not yet deployed the database to production, all schema changes are integrated directly into the core database files:

- `database/schema.sql` - Core table definitions
- `database/triggers.sql` - Event sourcing and automation
- `database/tamper_detection.sql` - Cryptographic integrity
- `database/auth_audit.sql` - Authentication logging
- etc.

**No migrations are needed until after first production deployment.**

## What's In This Folder

### `migrations/` - Example Migration Files

These files demonstrate how to structure database migrations for **post-deployment** schema changes:

- **001_initial_schema.sql** - Example: Full schema deployment
- **002_add_audit_metadata.sql** - Example: Adding columns to existing tables
- **003_add_encryption_docs.sql** - Example: Documentation updates
- **007_enable_state_protection.sql** - Example: Environment-aware triggers
- **007_test_verification.sql** - Example: Migration verification tests
- **rollback/** - Example rollback scripts

### When To Use Migrations

**After first production deployment**, use migrations for:
- Adding new columns
- Creating new tables
- Modifying constraints
- Adding indexes
- Performance optimizations
- Compliance enhancements

**Migration Strategy:** See `spec/MIGRATION_STRATEGY.md` for complete procedures.

## Current Development Workflow

1. **Design Stage (Current):**
   - Edit core database files directly
   - Test using `init.sql` to build fresh database
   - No migrations needed

2. **Post-Deployment:**
   - Core schema frozen
   - All changes via numbered migration files
   - Follow migration strategy in spec/

## Testing

To test the complete database initialization:

```bash
# PostgreSQL
psql -U postgres -d dbtest_dev -f database/init.sql

# Supabase SQL Editor
# Paste and run database/init.sql
```

## References

- `spec/MIGRATION_STRATEGY.md` - Migration procedures and best practices
- `spec/DEPLOYMENT_CHECKLIST.md` - Pre-deployment verification
- `database/init.sql` - Complete database initialization script
