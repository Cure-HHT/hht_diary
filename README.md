## Documentation Structure

Project documentation is split into two directories:

### spec/ - Formal Requirements

Contains formal requirements documents defining WHAT the system does, WHY it exists, and HOW to build/deploy it.

**Format**: `{audience}-{topic}(-{subtopic}).md`

**Audiences**:
- **prd**: Product Requirements - High-level, evaluation for suitability
- **ops**: DevOps - Deployment, maintenance, operations, monitoring
- **dev**: Developers - Code practices, libraries, implementation

**Key Topics**: app, database, security, clinical-trials

**See**: `spec/README.md` for complete hierarchical documentation map and topic scope definitions.

### docs/ - Implementation Documentation

Contains Architecture Decision Records (ADRs), implementation guides, and technical explanations of HOW decisions were made.

**Includes**:
- `adr/` - Architecture Decision Records documenting major technical decisions
- Implementation tutorials and guides
- Investigation reports and research findings

**See**: `docs/README.md` for complete documentation about when to use docs/ vs spec/.

**Key Documents**:
- `spec/prd-app.md` - High level system functional requirements
- `spec/prd-database.md` - Database architecture requirements
- `spec/prd-database-event-sourcing.md` - Event Sourcing pattern
- `spec/prd-security-RBAC.md` - Role-based access control
- `spec/prd-clinical-trials.md` - FDA compliance requirements
- `spec/dev-database.md` - Implementation guide
- `spec/dev-data-models-jsonb.md` - JSONB schema definitions
- `spec/ops-database-setup.md` - Supabase deployment guide

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

---

## Support

### Getting Help
- **Executive overview and requirements**: See `spec/prd-*.md` files
- **Implementation Questions**: See `spec/dev-*.md` files
- **Deployment Issues**: See `spec/ops-*.md` files
- **Compliance Questions**: See `spec/prd-clinical-trials.md`

### External Resources
- Supabase Docs: https://supabase.com/docs
- PostgreSQL Docs: https://www.postgresql.org/docs/
- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information

