# Formal Requirements System

This directory contains **formal requirements documents** organized by audience and topic using a hierarchical naming convention. Files reference other files rather than containing redundant information.

**Status**: Reorganization complete (2025-10-23). All requirements now use the hierarchical naming convention.

## spec/ vs docs/

- **spec/** (this directory): Formal requirements defining WHAT, WHY, and HOW to build/deploy
- **docs/**: Implementation documentation, ADRs, and technical decision explanations

**See**: `docs/README.md` for when to use docs/ vs spec/.


# Hierarchical File Naming Convention

filename: {audience}-{topic}(-{subtopic}).{ext}

examples:
- prd-app.md
- prd-app-UX.md
- prd-clinical-trials.md
- prd-security.md
- prd-security-RBAC.md
- ops-security.md
- ops-security-RBAC.md
- dev-security.md
- dev-security-RBAC.md

# Audience

Typically the hierarchy from broad to specific is prd -> ops -> dev.

prd: product requirement documents. High-level, C-suite, customer-facing, evaluation for suitability
ops: devops. Deployment, maintenance, daily operations and monitoring, incident reponse and reporting.
dev: software developers. Code writing practices, libraries used, toolchain.

Although dev and ops are in many ways parallel, ops requirements inform developer requirements, not vice-versa.

---

# Audience Scope Rules

## prd- files (Product Requirements)
**Purpose**: Define WHAT the system does and WHY from user/business perspective
**Allowed**:
- User workflows and use cases
- Architecture diagrams (ASCII art OK)
- Data structure descriptions (conceptual, not schema)
- Feature lists and capabilities
- Compliance requirements (what must be met)

**FORBIDDEN**:
- Code examples (any language)
- SQL queries or schema DDL
- CLI commands (belongs in ops- or dev-)
- API endpoint definitions (belongs in dev-)
- Configuration file examples (belongs in ops- or dev-)

## ops- files (Operations)
**Purpose**: How to deploy, monitor, and maintain the system
**Allowed**:
- CLI commands and scripts (bash, SQL admin commands)
- Configuration file examples (YAML, env files)
- Monitoring queries and dashboards
- Runbooks and checklists
- Deployment procedures

**Context**: Commands are operational instructions, not implementation code

## dev- files (Development)
**Purpose**: How to implement features as a software developer
**Allowed**:
- Code examples (Dart, TypeScript, SQL)
- API documentation
- Library usage examples
- Implementation patterns
- Testing strategies

---

# Topics

app: the patient-facing application (the motivation for the project)
portal: a (non-patient) user-facing application for interacting with the system
clinical-trials: the operating paradigm for the system. Regulations and best-practice requirements.
sponsor: special requirements of the Sponsor.
security: ensuring only authorized access to protect the integrity of the data
RBAC: roll based access control. A system for authorizing specific activities.
RLS: row level security. A system for controlling access to data within the database.
database: where patient data is stored, as well as trial configuration and audit logs.

---

# Topic Scope Definitions

To prevent redundant information across files, each topic has a narrow, focused scope. Files should reference other docs instead of duplicating content.

## architecture
**Scope**: Multi-sponsor deployment model, repository structure, build system composition, technology stack
**Includes**: How components connect, where code lives, how builds compose core + sponsor code
**Excludes**: Individual component internals (see component-specific docs like app, portal, database)

## app
**Scope**: Patient-facing mobile application features and user workflows from user perspective
**Includes**: User enrollment flow, screens, features users interact with, what happens from user's viewpoint
**Excludes**: Technical implementation details (dev-app.md), deployment procedures (ops-deployment.md), backend architecture (database.md)

## portal
**Scope**: Investigator/sponsor/admin web application features and workflows from user perspective
**Includes**: Portal dashboards, reports, user workflows, what portal users can do
**Excludes**: Technical implementation (dev-portal.md), deployment (ops-deployment.md)

## database
**Scope**: Data storage schema, Event Sourcing mechanics, query patterns, audit trail implementation
**Includes**: Tables, relationships, how Event Sourcing works, JSONB structure, audit log storage, how data flows
**Excludes**: Compliance interpretation (clinical-trials.md), who can access what (security.md), encryption decisions (data-classification.md)

## security
**Scope**: Authentication and authorization ONLY - who can access what and how access is verified
**Includes**: Authentication mechanisms, RBAC role definitions, RLS policy specifications, multi-sponsor access isolation, session management
**Excludes**: Audit trail implementation (database.md), compliance requirements (clinical-trials.md), encryption strategies (data-classification.md), data privacy architecture (data-classification.md)

## clinical-trials
**Scope**: Regulatory compliance requirements, validation procedures, what must be audited and why
**Includes**: FDA 21 CFR Part 11 requirements, ALCOA+ principles, audit requirements, validation protocols, compliance mandates
**Excludes**: How audits are implemented (database.md), who can access audit data (security.md), encryption decisions (data-classification.md)

## data-classification
**Scope**: Data sensitivity levels, protection strategies, encryption decisions, privacy architecture
**Includes**: PHI/PII definitions, what data gets encrypted and why, de-identification strategies, privacy-by-design patterns
**Excludes**: Access control mechanisms (security.md), compliance mandates (clinical-trials.md), database schema (database.md)

## deployment
**Scope**: Build processes, CI/CD pipelines, release procedures, environment configuration
**Includes**: Build system usage, deployment workflows, environment setup, release validation
**Excludes**: Daily operations (operations.md), ongoing monitoring (operations.md)

## operations
**Scope**: Daily operational procedures, monitoring, incident response, routine maintenance
**Includes**: Health checks, monitoring dashboards, incident runbooks, routine tasks
**Excludes**: Initial deployment (deployment.md), schema changes (database-migration.md)

---

# Cross-Reference Guidelines

When writing specs:
- Stay within your topic's scope
- Reference other docs instead of duplicating
- Use format: **See**: {filename} for {specific topic}

Examples:
- prd-security.md: "For audit trail requirements, see prd-clinical-trials.md. For audit implementation, see prd-database.md."
- prd-database.md: "For compliance requirements, see prd-clinical-trials.md. For access control, see prd-security.md."

