# Multi-Sponsor Clinical Diary Architecture

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: prd-database.md for database architecture
> **See**: prd-database-event-sourcing.md for Event Sourcing pattern
> **See**: prd-clinical-trials.md for FDA compliance requirements

---

## Executive Summary

A scalable architecture for deploying a diary system across multiple sponsors using a single public codebase with private sponsor-specific extensions.

**Key Requirements**:
- Single mobile app containing ALL sponsor configurations
- Separate portal deployment per sponsor
- Public core platform with private sponsor customizations
- Supabase-based infrastructure (PostgreSQL + Auth + Realtime + Edge Functions)
- Type-safe extension via abstract base classes
- Automated build system composing core + sponsor code
- FDA 21 CFR Part 11 compliant audit trail

**Technology Stack**:
- **Mobile**: Flutter (iOS + Android from single codebase)
- **Portal**: Flutter Web (hosted on Netlify/Vercel/Cloudflare)
- **Backend**: Supabase (managed PostgreSQL, Auth, Edge Functions)
- **Database**: PostgreSQL with Event Sourcing pattern
- **Language**: Dart for all application code, TypeScript/Deno for Edge Functions
- **Distribution**: GitHub Package Registry
- **Build System**: Dart-based tooling with CI/CD automation

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                   SPONSOR DEPLOYMENT                            │
│                  (e.g., Orion Production)                      │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Supabase Project: clinical-diary-orion                    │ │
│  │                                                            │ │
│  │  ├─ PostgreSQL (Event Sourcing schema + RLS)               │ │
│  │  ├─ Supabase Auth (OAuth/SAML with sponsor SSO)            │ │
│  │  ├─ Edge Functions (EDC proxy sync - proprietary)          │ │
│  │  └─ Realtime (WebSocket for live updates)                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  Accessed by:                                                   │
│  ├─ Mobile App (iOS/Android) → Orion configuration selected    │
│  ├─ Portal (Flutter Web) → https://orion-portal.example.com    │
│  └─ EDC System (Medidata Rave) ← Edge Function pushes events    │
└─────────────────────────────────────────────────────────────────┘
```

### Deployment Modes

**Endpoint Mode**: Standard deployment with no EDC integration
**Proxy Mode**: Deployment with Edge Function syncing events to sponsor's EDC system

---

## Repository Structure

### Monorepo Architecture

**Repository**: `clinical-diary` (single monorepo)

The repository uses a **monorepo** structure with a `sponsor/` directory that mirrors the root directory structure but contains only sponsor-specific code.

```
clinical-diary/                  (Root - Core platform)
├── packages/
│   ├── core/                    (Abstract interfaces + core logic)
│   └── edge_functions_shared/   (Shared utilities for Edge Functions)
│
├── apps/
│   ├── mobile/                  (Flutter app template)
│   └── portal/                  (Flutter Web template)
│
├── database/                    (Shared SQL schema for ALL sponsors)
│   ├── schema.sql               (Event Sourcing pattern + RLS)
│   ├── migrations/              (Schema changes over time)
│   ├── rls_policies.sql         (Row-Level Security)
│   └── functions.sql            (PostgreSQL functions)
│
├── tools/
│   ├── build_system/            (Build scripts)
│   ├── requirements/            (Requirement validation)
│   └── linear-cli/              (Linear ticket tools)
│
├── spec/                        (Core specifications)
│   ├── prd-*.md                 (Product requirements)
│   ├── ops-*.md                 (Operations requirements)
│   └── dev-*.md                 (Development requirements)
│
├── docs/                        (Architecture Decision Records)
│   └── adr/                     (ADRs)
│
└── sponsor/                     ⭐ Sponsor-specific code
    ├── lib/                     (Sponsor implementations)
    │   ├── orion/
    │   │   ├── orion_config.dart      (extends SponsorConfig)
    │   │   ├── orion_edc_sync.dart    (extends EdcSync)
    │   │   ├── orion_theme.dart       (branding)
    │   │   └── widgets/               (custom UI components)
    │   └── andromeda/
    │       ├── andromeda_config.dart
    │       ├── andromeda_edc_sync.dart
    │       └── andromeda_theme.dart
    │
    ├── edge_functions/          (Sponsor Edge Functions)
    │   ├── orion/
    │   │   └── edc_sync/        (EDC integration for Orion)
    │   └── andromeda/
    │       └── edc_sync/        (EDC integration for Andromeda)
    │
    ├── config/                  (Sponsor configurations)
    │   ├── orion/
    │   │   ├── mobile.yaml
    │   │   ├── portal.yaml
    │   │   └── supabase.env     (credentials - gitignored)
    │   └── andromeda/
    │       ├── mobile.yaml
    │       ├── portal.yaml
    │       └── supabase.env
    │
    ├── assets/                  (Sponsor branding)
    │   ├── orion/
    │   │   ├── logo.png
    │   │   ├── icon.png
    │   │   └── fonts/
    │   └── andromeda/
    │       ├── logo.png
    │       └── icon.png
    │
    └── spec/                    (Sponsor requirements - from Google Docs)
        ├── orion/
        │   └── (sponsor-specific REQs - imported later)
        └── andromeda/
            └── (sponsor-specific REQs - imported later)
```

**What's in root (core platform)**:
- Database schema (shared by ALL sponsors)
- Abstract base classes defining extension points
- Mobile app UI framework
- Portal UI framework
- Build tooling
- Core specifications (prd/ops/dev)

**What's in sponsor/ (sponsor-specific)**:
- Sponsor implementations (extends core interfaces)
- EDC integration code (proprietary)
- Authentication configurations
- Branding assets (logos, fonts, colors)
- Sponsor-specific requirements (imported from Google Docs)

**Database Deployment**:
- Schema is **shared** (same schema.sql for all sponsors)
- Each sponsor gets **separate Supabase project** (deployed instance)
- Sponsor-specific: Authorized users, deployment configuration
- No sponsor-specific schema extensions (database is generic)

**Dependency management**:


---

## Abstract Base Class Architecture

### Extension Points

The public core defines abstract interfaces that sponsors extend:

**Core Interfaces** (in `packages/core/lib/interfaces/`):

1. **SponsorConfig** - Main configuration interface
   - Properties: sponsorId, displayName, supabaseUrl, branding, features
   - Methods: Getters for theme, logo, custom widgets, deployment mode

2. **EdcSync** - EDC integration interface (for proxy mode)
   - Methods: initialize(), sync(), checkConnection(), transformEvent()
   - Implementations: Sponsor-specific (Medidata Rave, Oracle InForm, Veeva Vault, etc.)

3. **PortalCustomization** - Portal extensions interface
   - Methods: Custom dashboard widgets, reports, data exporters

### Type Safety

All sponsor implementations must:
- Extend abstract base classes
- Implement all required methods/properties
- Pass contract tests defined in core
- Be validated by build system before deployment

This ensures:
- Compile-time type checking
- API compatibility
- Predictable behavior
- Easy testing

---

## Build System

### Composition at Build Time

The build system composes core platform code with sponsor-specific code from the `sponsor/` directory to produce deployable artifacts.

**Build Process**:

1. **Validate** sponsor implementation (in `sponsor/{sponsor-name}/`)
2. **Load** sponsor configuration from `sponsor/config/{sponsor-name}/`
3. **Compose** core + sponsor into unified codebase
4. **Generate** integration glue code
5. **Build** Flutter app (mobile) or Flutter Web (portal)
6. **Package** for deployment (IPA/APK for mobile, static site for portal)

**Build Scripts** (in `tools/build_system/`):
- `build_mobile.dart` - Builds mobile app with sponsor configuration
  ```bash
  dart tools/build_system/build_mobile.dart --sponsor orion --platform ios
  ```
- `build_portal.dart` - Builds portal with sponsor customization
  ```bash
  dart tools/build_system/build_portal.dart --sponsor orion --environment production
  ```
- `validate_sponsor.dart` - Validates sponsor implementation
  ```bash
  dart tools/build_system/validate_sponsor.dart --sponsor orion
  ```
- `deploy.dart` - Orchestrates deployment to Supabase + hosting
  ```bash
  dart tools/build_system/deploy.dart --sponsor orion --environment production
  ```

**Usage**:

```bash
# Validate Orion sponsor implementation
dart tools/build_system/validate_sponsor.dart --sponsor orion

# Build Orion mobile app for iOS
dart tools/build_system/build_mobile.dart --sponsor orion --platform ios

# Build Orion portal
dart tools/build_system/build_portal.dart --sponsor orion --environment production

# Deploy Orion to production
dart tools/build_system/deploy.dart --sponsor orion --environment production
```

### CI/CD Integration

The monorepo uses GitHub Actions workflows that:
- Trigger on changes to `sponsor/{sponsor-name}/` directory
- Run sponsor-specific validation and tests
- Build artifacts for affected sponsor only
- Deploy to sponsor's Supabase project
- Support manual triggers for full rebuilds

**Workflow Example** (`.github/workflows/deploy-sponsor.yml`):
```yaml
name: Deploy Sponsor

on:
  push:
    paths:
      - 'sponsor/**'
      - 'database/**'
      - 'packages/**'
      - 'apps/**'
  workflow_dispatch:
    inputs:
      sponsor:
        description: 'Sponsor to deploy (orion, andromeda, etc.)'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect changed sponsor
        id: detect
        run: |
          # Auto-detect which sponsor changed
          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            echo "sponsor=${{ github.event.inputs.sponsor }}" >> $GITHUB_OUTPUT
          else
            # Extract sponsor from changed paths
            sponsor=$(git diff --name-only HEAD~1 | grep '^sponsor/' | cut -d/ -f2 | sort -u)
            echo "sponsor=$sponsor" >> $GITHUB_OUTPUT
          fi

      - name: Build and deploy
        run: |
          dart tools/build_system/deploy.dart \
            --sponsor ${{ steps.detect.outputs.sponsor }} \
            --environment production
```

---

## Mobile App Architecture

### Single App with Multi-Sponsor Support

**Key Design**: One mobile app contains ALL sponsor configurations.

**User Experience**:
1. User receives enrollment token (encoded sponsor ID + patient-link ID)
2. App detects sponsor from token value
3. Connects to sponsor's Supabase instance
4. Supabase validates token (unique and matching Auth ID or App instance UUID)
4. Applies sponsor's branding and theme
5. User completes enrollment and uses app


### Distribution

**App Store**: Single listing ("Clinical Diary") with multi-sponsor support

---

## Portal Architecture

### Separate Deployment per Sponsor

Each sponsor gets independent portal deployment:
- Unique domain: `orion-portal.clinicaldiary.com`
- Sponsor-specific theme and branding
- Custom pages and reports
- Connects to sponsor's Supabase instance

### Hosting

Netlify (easy deployment, CDN, SSL)


**Deployment**: Static site (Flutter Web compiled to HTML/JS/CSS)

### Portal Customization

Sponsors can add:
- Custom dashboard widgets
- Specialized reports
- Data export formats
- Compliance documentation generators
- Custom data visualizations

---

## Database Architecture

### Supabase-Based Infrastructure

**Why Supabase**:
- Managed PostgreSQL with automatic backups
- Built-in authentication (OAuth, SAML, JWT)
- Auto-generated REST API with RLS enforcement
- Real-time subscriptions via WebSockets
- Edge Functions for custom logic (Deno runtime)
- Row Level Security (RLS) enforces RBAC at database level

### Schema Deployment

**Core schema** (from `packages/database/`):
- Event Sourcing tables (record_audit, record_state)
- RLS policies for RBAC
- Triggers for Event Sourcing pattern
- Compliance functions (tamper detection, ALCOA+ validation)

**Sponsor extensions** (from sponsor repo `database/extensions.sql`):
- Sponsor-specific tables
- Custom indexes
- Additional RLS policies
- Stored procedures

**Deployment**:


### Event Sourcing Pattern

All diary data changes stored as immutable events in `record_audit` table. 
Current state derived in `record_state` table via database triggers.

**See**: prd-database-event-sourcing.md for complete pattern details.

---

## Edge Functions (Proxy Mode)

### EDC Synchronization

For sponsors in **proxy mode**, Edge Functions sync diary events to their EDC system.

**Trigger**: Database webhook on INSERT to `record_audit`
**Function**: INSERT into `sponsor_queue`, Sponsor-specific implementation of EdcSync interface
**Execution**: Deno runtime on Supabase infrastructure

**Example EDC systems**:
- Medidata Rave (Orion example)
- Oracle InForm
- Veeva Vault CDMS
- Custom RDBMS

**Error Handling**:
- Exponential backoff retry logic for transient failures
- Failed sync tracking in `edc_sync_log` table
- Alerting via monitoring service
- Manual reconciliation interface in portal

---

## Testing Strategy

### Three-Level Testing

**1. Contract Tests** (in public core)
Define requirements all implementations must meet. 
Reusable test suites that verify interface compliance.

**Location**: `packages/core/test/contracts/`

**2. Core Tests** (in public core)
Test core functionality: Event Sourcing, RLS policies, database functions, base UI components.

**Location**: `packages/core/test/`, `apps/mobile/test/`, `apps/portal/test/`

**3. Sponsor Implementation Tests** (in sponsor repos)
Test sponsor-specific implementations custom behavior.

**Location**: `clinical-diary-orion/test/`

### Integration Testing

Test against live Supabase staging instances:
- Database triggers and RLS policies
- Edge Functions with mock EDC endpoints
- Mobile app offline sync
- Portal queries and reports

**Test Data**: Seed scripts create realistic test scenarios

---

## GitHub Package Registry

### Package Distribution

**Published packages**:
- `clinical_diary_core` - Core interfaces and logic
- `clinical_diary_database` - SQL schema and migrations
- `clinical_diary_edge_functions_shared` - Shared Edge Function utilities

**Publishing**: Automated via GitHub Actions on release tag

**Versioning**: Date + Semantic versioning (2025.10.13.a)

**Consumption**: Sponsor repos depend via Git references or GitHub Packages

**Benefits**:
- Version pinning for stability
- Dependency management via pubspec.yaml
- Security scanning by GitHub
- Access control via repository permissions

---

## Workflows

### Creating New Sponsor

**Step 1**: Scaffold new repository

**Step 2**: Customize implementation
- Extend SponsorConfig class
- Implement EdcSync if proxy mode needed
- Define branding and theme
- Add custom widgets/pages

**Step 3**: Configure Supabase
- Create Supabase project
- Configure authentication (OAuth/SAML)
- Set environment variables

**Step 4**: Test locally
- Run contract tests
- Test against staging Supabase
- Validate mobile and portal builds

**Step 5**: Deploy
- Push to GitHub
- CI/CD builds and deploys automatically
- Mobile app updated in next release
- Portal live immediately

### Updating Core Platform

**Quarterly release cycle**:

**Step 1**: Develop in public repository
- Create feature branch
- Implement new features
- Add tests
- Update documentation

**Step 2**: Tag release

**Step 3**: Notify sponsors
- Release notes published
- Breaking changes highlighted (target: never during active trial)
- Migration guide provided (target: no action)

**Step 4**: Sponsors upgrade
- Update dependency version in pubspec.yaml
- Run tests to verify compatibility
- Deploy to Prodcution after Sponsor approves UAT deployment

### Developer Workflow

The following workflow aligns with the principles of 21 CFR Part 11 and is similar to 
established strategies like GitFlow: 

**develop branch**: All new features and bug fixes are developed on feature 
  branches and merged into a develop branch.
**Release branch**: When ready for a deployment, create a new, separate release branch (e.g., release/1.2.3) from the develop branch.
**Validation**: Deploy from the release branch to a testing environment. Run all validation protocols and user acceptance tests (UAT). Fix any bugs directly on the release branch.
**Tagging**: Once the software passes all validation, a git tag (e.g., v1.2.3) is applied to the release branch commit. This tag serves as the permanent, immutable record of the deployed version.
**Deployment** and merging: Deploy the tagged version to the production environment. After a successful deployment, merge the release branch into main and back into develop.
**main branch**: The main branch now contains only validated, production-ready code. It reflects the history of all official releases. 

This process provides an authoritative and unalterable record of all changes, creating a verifiable audit trail that satisfies FDA requirements. ---

## Security and Compliance

### Code Isolation

**Public core**: Contains no proprietary information, secrets, or sponsor-specific logic

**Sponsor repositories**:
- Private GitHub repositories
- Access controlled per sponsor
- Each sponsor cannot see other sponsors' code
- We (developers) have access to all sponsor repos

### Audit Process

**For regulatory audits**: Export snapshot of sponsor repository at specific commit
- Includes sponsor code
- Includes referenced core version
- Packaged as ZIP for auditor review
- No Git access required

### Secrets Management

**Never in repositories**:
- Supabase credentials
- EDC API keys
- OAuth secrets

**Stored in**:
- GitHub Secrets (for CI/CD)
- Environment variables (for local development)
- Supabase project secrets (for Edge Functions)

### FDA 21 CFR Part 11 Compliance

Event Sourcing architecture ensures:
- Complete audit trail (all changes captured)
- Immutable event store
- Cryptographic tamper detection
- ALCOA+ principles enforced

**See**: prd-clinical-trials.md for complete compliance requirements.

---

## References

- **Database Architecture**: prd-database.md
- **Event Sourcing Pattern**: prd-database-event-sourcing.md
- **FDA Compliance**: prd-clinical-trials.md
- **Security**: prd-security.md
- **RBAC**: prd-security-RBAC.md
- **RLS**: prd-security-RLS.md
- **Data Classification**: prd-security-data-classification.md

---

**Document Status**: Active specification for multi-sponsor architecture
**Implementation Timeline**: Q4 2025 - Core platform, Q4 2025 - First sponsor deployment
**Review Cycle**: Quarterly or as needed for major changes
