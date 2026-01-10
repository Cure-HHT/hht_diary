# Developer Onboarding Guide

Welcome to the HHT Clinical Trial Diary Platform team. This document will orient you to our system architecture, regulatory context, and development practices.

## The Simple Idea

At its core, this system does one thing: **collect diary entries from clinical trial participants**.

Patients open a mobile app, record information about their symptoms (primarily epistaxis/nosebleeds for HHT patients), and that data flows to researchers. Simple, right?

## The Complex Reality

Clinical trials operate under FDA regulations. Our system must comply with **FDA 21 CFR Part 11**, which governs electronic records and electronic signatures in pharmaceutical and medical device industries. This regulation transforms our "simple diary app" into a sophisticated compliance platform.

### What 21 CFR Part 11 Means for Us

The regulation requires:

- **Immutable audit trails** - Every action must be recorded and cannot be altered
- **Electronic signatures** - Must be legally equivalent to handwritten signatures
- **Access controls** - Strict role-based permissions (RBAC)
- **Data integrity** - Records must be accurate, complete, and verifiable
- **System validation** - Documented evidence that the system works correctly

### The Audit Reality

During a regulatory audit, an FDA inspector may ask questions like:
- "Show me every change made to Patient X's record on Date Y"
- "Prove this data hasn't been tampered with"
- "Who had access to modify this record and when?"

**We must answer these questions within minutes, with documented evidence.** This drives much of our architecture: event sourcing, cryptographic hashing, comprehensive logging, and evidence record generation.

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         SPONSORS                                 │
│   (Each sponsor has isolated data, config, and deployments)     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │  Mobile App  │     │  Web Portal  │     │   EDC/CRF    │    │
│  │  (Patient)   │     │ (Investigator│     │  (External)  │    │
│  │              │     │   Sponsor)   │     │              │    │
│  └──────┬───────┘     └──────┬───────┘     └──────▲───────┘    │
│         │                    │                    │             │
│         ▼                    ▼                    │             │
│  ┌──────────────────────────────────────────┐    │             │
│  │           Supabase / PostgreSQL          │────┘             │
│  │  • Event Store (immutable)               │                  │
│  │  • Row-Level Security (RLS)              │                  │
│  │  • Audit Triggers                        │                  │
│  │  • Cryptographic Hashing                 │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Purpose | Where to Learn More |
| --------- | ------- | ------------------- |
| Mobile App (Flutter) | Patient diary entry | `apps/daily-diary/clinical_diary/`, `spec/prd-diary-app.md` |
| Web Portal (Flutter) | Investigator/sponsor/admin interface | `apps/portal/`, `spec/prd-portal.md` |
| Database (PostgreSQL) | Event store, audit trails, RLS | `database/`, `spec/dev-database.md` |
| EDC Integration | Export to sponsor's Electronic Data Capture | `spec/dev-CDISC.md` |

## Core Architectural Patterns

### 1. Event Sourcing

We don't just store current state—we store every event that led to that state. A diary entry isn't a row that gets updated; it's a sequence of events:

```
DiaryEntryCreated → DiaryEntryEdited → DiaryEntrySubmitted
```

This provides a complete, immutable history. You can reconstruct the state at any point in time.

**Read**: `docs/adr/ADR-001-event-sourcing-pattern.md`, `spec/prd-event-sourcing-system.md`

### 2. Row-Level Security (RLS)

PostgreSQL RLS ensures data isolation at the database level. A sponsor can only see their own data, regardless of what queries the application sends.

**Read**: `spec/prd-security-RLS.md`, `docs/adr/ADR-003-row-level-security.md`

### 3. Multi-Sponsor Architecture

The platform serves multiple sponsors (pharmaceutical companies running trials). Each sponsor has:
- Isolated data (enforced by RLS)
- Customizable configuration (branding, trial-specific fields)
- Separate deployments

Core code is shared; sponsor-specific code lives in `sponsor/{name}/`.

**Read**: `spec/prd-architecture-multi-sponsor.md`, `spec/dev-architecture-multi-sponsor.md`

### 4. Evidence Records

For audit purposes, we generate cryptographically-signed evidence records that prove data integrity at a point in time.

**Read**: `spec/prd-evidence-records.md`, `spec/dev-evidence-records.md`

## Development Workflow

### Requirement Traceability (Non-Negotiable)

Every code change must trace back to a requirement. This isn't bureaucracy—it's regulatory necessity.

**Requirements format**: `REQ-{type}{number}`
- `REQ-p#####` - Product requirements (what users need)
- `REQ-o#####` - Operations requirements (how we deploy/monitor)
- `REQ-d#####` - Development requirements (how we build)

**Every commit message must include**: `Implements: REQ-xxxxx` or `Fixes: REQ-xxxxx`

Git hooks enforce this. Your commit will be rejected without a valid requirement reference.

**Browse requirements**: `spec/INDEX.md`

### Branch Workflow

1. Never commit directly to `main`
2. Create feature branches: `feature/CUR-XXX-description`
3. All changes go through PRs with CI validation

### Documentation Structure

| Directory | Contains | Audience |
| --------- | -------- | -------- |
| `spec/` | Formal requirements (WHAT to build) | Product, Ops, Dev |
| `docs/` | Implementation details (HOW we built it) | Developers |
| `docs/adr/` | Architecture Decision Records (WHY we chose) | Architects, Senior Devs |

**Important**: Read `spec/README.md` before modifying any spec files. There are strict rules about what content goes where.

## Setting Up Your Environment

### Quick Start

1. **Read prerequisites**: `docs/development-prerequisites.md`
2. **Set up dev environment**: `docs/setup-dev-environment.md`
3. **Configure secrets**: `docs/setup-doppler-new-dev.md`

### Recommended: Dev Container

We strongly recommend using the dev container (`.devcontainer/`). It ensures:
- Consistent tool versions across the team
- Pre-installed dependencies
- Standardized configuration

```bash
# In VS Code: Cmd/Ctrl+Shift+P → "Reopen in Container"
```

## Security Considerations

### Secrets Management

- **Never** commit secrets (API keys, tokens, passwords)
- All secrets managed via Doppler
- You'll run commands with `doppler run -- <command>`

### Security Scanning

Our CI/CD pipeline runs multiple security scanners:
- **Gitleaks** - Blocks commits containing secrets
- **Trivy** - Dependency vulnerability scanning
- **Squawk** - PostgreSQL migration safety
- **Flutter Analyze** - Dart static analysis

**Read**: `docs/security/scanning-strategy.md`

## Key Specifications to Read First

In order of priority:

1. `spec/README.md` - How our documentation system works
2. `spec/prd-system.md` - System overview
3. `spec/prd-clinical-trials.md` - Domain context (what clinical trials are)
4. `spec/prd-security.md` - Security requirements
5. `spec/dev-core-practices.md` - Development standards
6. `docs/adr/ADR-001-event-sourcing-pattern.md` - Why we use event sourcing

## Glossary Quick Reference

| Term | Meaning |
| ---- | ------- |
| EDC | Electronic Data Capture - sponsor's clinical trial data system |
| CRF | Case Report Form - standardized data collection form |
| CDISC | Clinical Data Interchange Standards Consortium |
| ALCOA+ | Data integrity principles (Attributable, Legible, Contemporaneous, Original, Accurate + Complete, Consistent, Enduring, Available) |
| RLS | Row-Level Security - PostgreSQL feature for data isolation |
| HHT | Hereditary Hemorrhagic Telangiectasia - the disease our first trials focus on |

**Full glossary**: `spec/prd-glossary.md`

## Getting Help

### Claude Code Plugins

This project uses Claude Code with specialized plugins for workflow enforcement. Key sub-agents:

- **workflow** - Claim/release tickets, enforce traceability
- **linear-api** - Interact with Linear (our issue tracker)
- **spec-compliance** - Validate spec file changes
- **requirement-traceability** - Track REQ coverage

### Documentation

- Architecture decisions: `docs/adr/`
- GCP infrastructure: `docs/gcp/`
- Security practices: `docs/security/`

### Team Onboarding

For administrative setup (accounts, access): `docs/setup-team-onboarding.md`

---

## Summary

You're building a regulated medical software system. The diary app is simple; the compliance infrastructure is complex. Everything we build must:

1. **Trace to requirements** - Every change links to a REQ
2. **Be auditable** - Complete history, reconstructible at any point
3. **Be secure** - Data isolation, access controls, encryption
4. **Be provable** - Evidence records, cryptographic verification

When in doubt, ask: "Can we answer an auditor's question about this within two minutes, with documented evidence?"

Welcome to the team.
