# Clinical Trial Diary System

[![Pre-release](https://img.shields.io/badge/status-PRE--RELEASE-orange?style=for-the-badge)](https://github.com/Cure-HHT/hht_diary#-pre-release-notice)
[![PR Validation](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/pr-validation.yml/badge.svg)](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/pr-validation.yml)

---

## ⚠️ PRE-RELEASE NOTICE

**This project is in active development and is not yet functional or ready for production use.**

- ⚠️ **Not Production Ready**: Core features are still being implemented
- 🚧 **Active Development**: APIs, data models, and interfaces are subject to change
- 🔬 **Testing Phase**: This software has not undergone clinical validation
- 📋 **FDA Compliance**: Validation protocols are in development but not yet complete

**Do not use this software for actual clinical trial data collection at this time.**

For information about the project roadmap and planned features, see the documentation in the `spec/` directory.

---

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

### Initial Setup

**After cloning the repository**, run the setup script to configure Git hooks and repository settings:

```bash
./scripts/setup-repo.sh
```

This enables:
- Git hooks for commit validation and workflow tracking
- Requirement reference enforcement
- Secret scanning with gitleaks

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

