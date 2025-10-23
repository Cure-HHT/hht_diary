# Clinical Trial Patient Diary System

**Version**: 1.0
**Status**: Active Development
**Platform**: Supabase (PostgreSQL 15+)
**Compliance**: FDA 21 CFR Part 11

---

## Overview

A PostgreSQL-based database system for clinical trial patient diary data with offline-first mobile app support, complete audit trail for FDA compliance, and multi-site access control.

### Architecture Pattern

**Event Sourcing with CQRS** (Command Query Responsibility Segregation)

All changes are stored as immutable events in an event store, with current state derived from replaying those events. This provides complete audit trails, point-in-time reconstruction, and data integrity guarantees required for FDA compliance.

---

## Key Features

- **Immutable Event Store** - Complete audit trail for regulatory compliance
- **Materialized Read Model** - Optimized for fast queries
- **Row-Level Security** - PostgreSQL RLS policies enforce access control
- **Offline-First Sync** - Mobile app with conflict resolution
- **Multi-Site Support** - Site isolation and role-based access
- **Cryptographic Tamper Detection** - Data integrity verification
- **FDA 21 CFR Part 11 Compliant** - Electronic records and signatures

---

## Architecture

### Core Components

#### Event Store (`record_audit` table)
- Source of truth for all diary data changes
- Immutable append-only event log (INSERT only)
- Every change captured as an event
- Provides audit trail for FDA compliance
- Enables point-in-time reconstruction and event replay

#### Read Model (`record_state` table)
- Current state view derived from event store
- Automatically updated via database triggers
- Optimized for queries with appropriate indexes
- Cannot be directly modified (enforced by permissions)

#### Data Flow Pattern

**Write Path**: Events to event store (`record_audit`) → Triggers update read model (`record_state`)
**Read Path**: Query read model (`record_state`) for current data
**Audit Path**: Query event store (`record_audit`) for complete history

---

## Database Tables

### Core Tables
- `record_audit` - Event store (immutable event log)
- `record_state` - Read model (current state view)
- `investigator_annotations` - Notes and corrections layer
- `sites` - Clinical trial site information
- `sync_conflicts` - Multi-device conflict tracking

### Access Control Tables
- `user_site_assignments` - Patient enrollment per site
- `investigator_site_assignments` - Investigator access per site
- `analyst_site_assignments` - Analyst access per site
- `user_profiles` - User metadata and roles

### Audit Tables
- `admin_action_log` - Administrative action audit
- `role_change_log` - Role modification audit
- `user_sessions` - Active session tracking
- `auth_audit_log` - Authentication event logging (HIPAA)

---

## Access Control

### Roles and Permissions

| Role | Access Scope | Permissions | Special Access |
|------|--------------|-------------|----------------|
| **USER (Patient)** | Own data only | Read/write own diary entries | None |
| **INVESTIGATOR** | Assigned sites | Read all patient data at sites, write annotations | Query across patients |
| **ANALYST** | Assigned sites | Read-only de-identified data | Export data |
| **ADMIN** | Global | All operations | Manage assignments, all logged |

### Enforcement

- **Row-Level Security (RLS)** - PostgreSQL policies enforce access at database level
- **JWT Authentication** - Token-based authentication with role claims
- **Two-Factor Authentication** - Required for admin and investigator roles
- **Session Management** - Active session tracking and timeout

---

## Offline-First Architecture

### Mobile App Capabilities
- Local data storage (IndexedDB/SQLite)
- Changes queued for sync when online
- Background sync every 15 minutes when connected
- Delta sync - only changed records transmitted

### UUID Generation
- UUIDs generated client-side (mobile app)
- Ensures offline-first functionality
- Prevents duplicate key conflicts during sync
- Same UUID across multiple database instances

### Conflict Resolution
- Detected when `parent_audit_id` doesn't match current state
- Resolution strategies:
  - User chooses version (client or server)
  - Field-level merge for non-conflicting fields
  - Manual review UI for true conflicts
- Resolution creates new event with conflict metadata

---

## Data Model

### Event Structure (record_audit)
```
├─ audit_id (PK, auto-increment) - Chronological order
├─ event_uuid (from app) - Global unique identifier
├─ patient_id - Data owner
├─ site_id - Clinical trial site
├─ operation - Type of change (CREATE, UPDATE, DELETE)
├─ data (JSONB) - Full data snapshot
├─ created_by - Actor who made change
├─ role - Role under which actor was operating
├─ client_timestamp - Client-side timestamp
├─ server_timestamp - Server-side timestamp
├─ parent_audit_id (FK) - Event lineage for versioning
└─ change_reason - Required for audit trail
```

### Current State Structure (record_state)
```
├─ event_uuid (PK, from app)
├─ patient_id - Data owner
├─ site_id - Clinical trial site
├─ current_data (JSONB) - Latest state
├─ version - Count of events for this record
├─ last_audit_id (FK) - Reference to last event
├─ sync_metadata - For offline-first app
└─ is_deleted - Soft delete flag
```

### JSONB Schema
Flexible schema for diary events stored in JSONB columns. See `spec/dev-data-models-jsonb.md` for complete schema definitions including event types (epistaxis, surveys, etc.).

---

## Performance

### Indexing Strategy
- Primary keys on all tables
- Composite indexes on: patient_id, site_id, UUID, timestamps
- GIN indexes on JSONB columns for fast queries
- Partial indexes for common filters

### Scaling Strategy
- Event store partitioned by month (performance)
- Old partitions archived to cold storage after 2 years
- Read replicas for reporting queries
- Connection pooling (PgBouncer)
- Materialized views for aggregate queries
- Automatic vacuum and analyze scheduled

### Performance Targets
- <3 seconds average sync time
- <100ms database query latency (95th percentile)
- Support 10,000 concurrent users
- 99.9% API uptime

---

## Security

### Encryption
- Database encrypted at rest (AES-256)
- All connections use TLS 1.3
- JWT tokens for authentication
- Passwords hashed with bcrypt

### Access Logging
- All database connections logged
- Failed authentication attempts logged
- Admin actions logged with justification
- Suspicious patterns trigger alerts

### Backup and Recovery
- Automated backups every 6 hours
- 30-day point-in-time recovery
- Cross-region replication for disaster recovery
- Backup encryption with separate keys

---

## Compliance

### FDA 21 CFR Part 11

**Electronic Records (§11.10)**
- Validation: Database triggers enforce data integrity
- Audit trail: Immutable event store
- Timestamps: Server and client timestamps with timezone
- Access controls: Row-level security policies

**Electronic Signatures (§11.50)**
- Two-factor authentication support
- Signature metadata: user ID, timestamp, reason
- Cryptographic linking via signature_hash field
- Non-repudiation: Immutable audit log

**Audit Trail Requirements**
- **Who**: created_by, role
- **What**: operation, data snapshot
- **When**: server_timestamp, client_timestamp
- **Why**: change_reason (required field)
- Complete chain of custody via parent_audit_id

### HIPAA & GDPR
Authentication audit logging (HIPAA) separate from diary event sourcing. See `spec/ops-security-authentication.md` for authentication audit details.

---

## Documentation Structure

Documentation is organized in the `spec/` directory using a hierarchical naming convention:

**Format**: `{audience}-{topic}(-{subtopic}).md`

### Audiences
- **prd**: Product Requirements - High-level, evaluation for suitability
- **ops**: DevOps - Deployment, maintenance, operations, monitoring
- **dev**: Developers - Code practices, libraries, implementation

### Key Topics
- **app**: Patient-facing application
- **database**: Data storage and audit logs
- **security**: Authorization and access control (RBAC, RLS)
- **clinical-trials**: Regulations and compliance requirements

### Documentation Index

See `spec/README.md` for complete hierarchical documentation map.

**Key Documents**:
- `spec/prd-database.md` - Database architecture requirements
- `spec/prd-database-event-sourcing.md` - Event Sourcing pattern
- `spec/prd-security-RBAC.md` - Role-based access control
- `spec/prd-clinical-trials.md` - FDA compliance requirements
- `spec/dev-database.md` - Implementation guide
- `spec/dev-data-models-jsonb.md` - JSONB schema definitions
- `spec/ops-database-setup.md` - Supabase deployment guide

---

## Terminology

### Standard Terms

| Term | Definition | Context |
|------|------------|---------|
| **Event Store** | `record_audit` table | Immutable append-only event log |
| **Read Model** | `record_state` table | Current state view (CQRS pattern) |
| **Event Sourcing** | Architecture pattern | All changes stored as events |
| **CQRS** | Command Query Responsibility Segregation | Write to event store, read from read model |
| **Audit Trail** | Complete change history | FDA compliance context |
| **ALCOA+** | Data integrity principles | Attributable, Legible, Contemporaneous, Original, Accurate + complete, consistent, enduring, available |

### Important Distinctions

**Event Store vs Operational Logging**
- Event store (`record_audit`) = Patient diary data changes for audit trail
- Operational logs = Application performance, debugging, monitoring
- Never mix these systems

**Audit Trail vs Authentication Audit Log**
- Event store provides audit trail for diary data (FDA 21 CFR Part 11)
- `auth_audit_log` table provides authentication logging (HIPAA)
- Separate systems with different purposes

---

## Development

### Database Files

Located in `database/` directory:
- `schema.sql` - Core table definitions and extensions
- `triggers.sql` - Event store triggers and validation
- `roles.sql` - User roles and permissions
- `rls_policies.sql` - Row-level security policies
- `indexes.sql` - Performance indexes
- `init.sql` - Master initialization script
- `seed_data.sql` - Sample data for testing

### Testing

See `database/tests/` for SQL test scripts:
- `test_audit_trail.sql` - Audit trail validation
- `test_compliance_functions.sql` - Compliance verification

---

## Deployment

### Target Platform
Supabase (PostgreSQL 15+)

### Deployment Guide
See `spec/ops-database-setup.md` for complete deployment instructions.

### Verification
After deployment, verify:
- All 12 core tables created
- RLS enabled on all tables
- 15+ triggers active
- 40+ indexes created
- Test user can create diary entry
- Audit trail captures all changes
- Read model auto-updates via triggers

---

## Support

### Getting Help
- **Architecture Questions**: See `spec/prd-*.md` files
- **Implementation Questions**: See `spec/dev-*.md` files
- **Deployment Issues**: See `spec/ops-*.md` files
- **Compliance Questions**: See `spec/prd-clinical-trials.md`

### External Resources
- Supabase Docs: https://supabase.com/docs
- PostgreSQL Docs: https://www.postgresql.org/docs/
- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information

---

## License

Proprietary - Clinical Trial Use Only

---

**Last Updated**: 2025-10-23
