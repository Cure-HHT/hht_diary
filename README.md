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

### Development Environment

The Clinical Diary project uses Docker-based containerized development environments to ensure consistency, security, and FDA compliance.

**Quick Start Options**:

**🌐 GitHub Codespaces** (5 minutes, recommended for remote teams):
1. Go to: `https://github.com/yourorg/clinical-diary`
2. Click "Code" → "Codespaces" → "Create codespace"
3. Choose your role → Start coding!

**💻 Local Dev Containers** (1-2 hours):
```bash
cd tools/dev-env
./setup.sh
```

**Features**:
- 🚀 **Role-Based Containers**: Separate environments for dev, qa, ops, and management
- 🔒 **Security**: Isolated workspaces with role-specific permissions
- 📦 **Pre-Configured Tools**: Flutter, Node.js, Python, Playwright, Terraform, and more
- 🔄 **CI/CD Ready**: Same environment locally and in GitHub Actions
- ✅ **FDA Validated**: IQ/OQ/PQ protocols for 21 CFR Part 11 compliance
- 🌍 **Cross-Platform**: Linux, macOS, and Windows (WSL2)

**Documentation**:
- **Setup Guide**: `tools/dev-env/README.md`
- **Architecture**: `docs/dev-environment-architecture.md`
- **Requirements**: `spec/dev-environment.md`
- **Validation**: `docs/validation/dev-environment/`
- **ADR**: `docs/adr/ADR-006-docker-dev-environments.md`

**Supported Roles**:
- **dev**: Full development environment (Flutter, Android SDK, Node.js, Python)
- **qa**: Testing environment (Playwright, Flutter tests, report generation)
- **ops**: DevOps environment (Terraform, Supabase CLI, Cosign, Syft)
- **mgmt**: Read-only management environment (Git viewing, report access)

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

