# Database Schema Files

This directory contains the complete database schema for the Clinical Trial Diary Database.

## Quick Start

To initialize the complete database, run:

```bash
# PostgreSQL
psql -U postgres -d your_database -f init.sql

# Supabase SQL Editor
# Paste and execute the contents of init.sql
```

## File Structure

### Core Schema Files

These files define the complete database structure:

```
database/
├── init.sql                 ← Master initialization script (run this)
├── schema.sql               ← Core tables and base functions
├── triggers.sql             ← Event sourcing and audit automation
├── roles.sql                ← User profiles and role management
├── rls_policies.sql         ← Row-level security policies
├── indexes.sql              ← Performance optimization indexes
├── tamper_detection.sql     ← Cryptographic audit integrity
├── auth_audit.sql           ← Authentication event logging
└── seed_data.sql            ← Sample data for development/testing
```

### Testing & Examples

```
database/testing/
└── migrations/              ← Example migration files for post-deployment
    ├── 001_initial_schema.sql
    ├── 002_add_audit_metadata.sql
    ├── 007_enable_state_protection.sql
    └── rollback/            ← Example rollback scripts
```

## File Descriptions

### `init.sql` - Master Initialization Script
Loads all schema files in correct dependency order. This is the only file you need to run to create the complete database.

**Usage:**
```bash
psql -U postgres -d dbtest -f init.sql
```

### `schema.sql` - Core Table Definitions
Defines all database tables, extensions, and base helper functions:
- Clinical trial sites
- Event store (record_audit) - Immutable event log
- Read model (record_state) - Current state view
- Investigator annotations
- Site assignments
- Conflict tracking
- Admin action log

**Tables created:** 9 core tables
**Extensions:** uuid-ossp, pgcrypto

### `triggers.sql` - Audit Automation
Implements event sourcing pattern with automatic state synchronization:
- Audit-to-state sync trigger
- Validation triggers
- Conflict detection
- Environment-aware state protection
- Annotation auto-resolution

**Triggers created:** 15+ triggers
**Pattern:** Event Sourcing with CQRS - All changes written to event store → read model updated automatically via triggers

### `roles.sql` - User Management
Defines user profiles, role management, and permission functions:
- User profiles (linked to Supabase auth)
- Role change audit log
- Session management
- Permission helper functions

**Tables created:** user_profiles, role_change_log, user_sessions
**Functions:** can_access_site(), can_modify_record(), etc.

### `rls_policies.sql` - Row-Level Security
Implements fine-grained access control based on roles and site assignments:
- USER: Own data only
- INVESTIGATOR: Assigned sites
- ANALYST: Read-only access to assigned sites
- ADMIN: Global access

**Policies created:** 40+ RLS policies
**Pattern:** Role-based + site-based access control

### `indexes.sql` - Performance Optimization
Creates indexes for common query patterns:
- Primary key lookups
- Foreign key joins
- Time-based queries
- JSONB field searches (GIN indexes)
- Partial indexes for filtered queries

**Indexes created:** 50+ indexes

### `tamper_detection.sql` - Cryptographic Integrity
Implements FDA 21 CFR Part 11 tamper-evident audit trail:
- Automatic SHA-256 hash computation
- Hash verification functions
- Audit chain validation

**Functions:** compute_audit_hash(), verify_audit_hash(), validate_audit_chain()
**Compliance:** FDA 21 CFR Part 11, ALCOA+ principles

### `auth_audit.sql` - Authentication Logging
Tracks all authentication events for HIPAA and security compliance:
- Login/logout events
- Password changes
- 2FA events
- Failed login attempts
- Session tracking

**Table created:** auth_audit_log
**Compliance:** HIPAA access logging requirements

### `seed_data.sql` - Sample Data
Provides test data for development and testing environments:
- Sample sites
- Test users
- Example diary entries

**Warning:** Do not load in production!

## Development Workflow

### Current Stage: Pre-Deployment Design

Since we have not yet deployed to production, **all schema changes are made directly to the core files above**.

**Do not create migrations until after first production deployment.**

### Workflow:

1. **Make changes** to core schema files (schema.sql, triggers.sql, etc.)
2. **Test locally** by running `init.sql` on a fresh database
3. **Verify** using validation checks in init.sql
4. **Commit** changes to version control

### After Production Deployment:

Once deployed to production, use the migration strategy:
- Create numbered migration files
- Include rollback scripts
- Test on staging before production
- Follow `spec/MIGRATION_STRATEGY.md`

See `database/testing/migrations/` for examples.

## Load Order & Dependencies

The `init.sql` script loads files in this order:

1. **schema.sql** - Base tables and functions
2. **triggers.sql** - Requires schema functions
3. **roles.sql** - Requires schema tables
4. **rls_policies.sql** - Requires roles functions
5. **indexes.sql** - Requires all tables
6. **tamper_detection.sql** - Requires schema tables
7. **auth_audit.sql** - Requires sites table

**Important:** Do not change this order without verifying dependencies.

## Validation Checks

After running `init.sql`, the script validates:
- ✅ All expected tables created (13 tables)
- ✅ RLS enabled on all tables
- ✅ Minimum trigger count (6+)

## Architecture Patterns

### Event Sourcing
- All changes recorded as immutable events in event store (record_audit)
- Current state derived from event store via triggers (read model: record_state)
- No direct read model modifications allowed - write to event store only

### Row-Level Security
- Every table has RLS enabled
- Policies enforce role-based access
- Site-level data isolation

### Audit Trail
- Complete WHO, WHAT, WHEN, WHY for all changes
- Cryptographic tamper detection
- FDA 21 CFR Part 11 compliant

### Multi-Tenant
- Site-based data partitioning
- Cross-site access prohibited (except ADMIN)
- Investigators see only assigned sites

## Compliance Features

### FDA 21 CFR Part 11
- ✅ Immutable audit log
- ✅ Electronic signatures support
- ✅ Tamper-evident records
- ✅ Complete audit trail

### HIPAA
- ✅ Authentication logging
- ✅ Access controls (RLS)
- ✅ De-identified data architecture
- ✅ No PHI/PII stored

### ALCOA+ Principles
- ✅ Attributable (created_by, role)
- ✅ Legible (structured JSONB)
- ✅ Contemporaneous (timestamps)
- ✅ Original (immutable audit)
- ✅ Accurate (validation triggers)
- ✅ Complete (all metadata captured)
- ✅ Consistent (derived state)
- ✅ Enduring (permanent records)
- ✅ Available (indexed retrieval)

## Environment Configuration

### Production vs Development

**Production:** Set environment variable to enable state protection:
```sql
ALTER DATABASE your_database SET app.environment = 'production';
```

**Development:** Leave unset or set to 'development' for flexibility.

See TICKET-007 (database/testing/migrations/007_enable_state_protection.sql) for details.

## References

- **Architecture:** `spec/db-spec.md`
- **Deployment:** `spec/DEPLOYMENT_CHECKLIST.md`
- **Migration Strategy:** `spec/MIGRATION_STRATEGY.md`
- **Compliance:** `spec/compliance-practices.md`
- **Security:** `spec/SECURITY.md`
- **Quick Reference:** `spec/QUICK_REFERENCE.md`

## Troubleshooting

### Common Issues

**"Missing tables" error:**
- Ensure you ran `init.sql` not individual files
- Check for errors in previous steps

**"RLS not enabled" warning:**
- Normal if seed_data tables exist
- Core tables should all have RLS

**"Trigger not found" error:**
- Verify schema.sql loaded first
- Check for syntax errors in triggers.sql

**Read model modification blocked:**
- Expected in production mode (Event Sourcing enforcement)
- Write events to event store (record_audit) for all data changes

## Support

For issues or questions:
1. Check `spec/` documentation
2. Review `spec/TROUBLESHOOTING.md` (if exists)
3. Contact database architect

---

**Version:** 1.0 (Pre-deployment)
**Last Updated:** 2025-10-15
**Status:** Design Stage - No production deployment yet
