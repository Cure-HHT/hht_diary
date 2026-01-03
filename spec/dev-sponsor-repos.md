# Sponsor Repository Development

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2026-01-03
**Status**: Draft

> **See**: ops-sponsor-repos.md for operational provisioning procedures
> **See**: docs/sponsor-development-guide.md for developer workflow

---

## Executive Summary

This document defines development requirements for the multi-repo sponsor architecture, including repository structure, configuration format, namespace validation, and cross-repository traceability.

---

## Technology Stack

- **Configuration**: YAML (sponsor-config.yml, .core-repo)
- **Validation**: elspais CLI with `.elspais.toml` configuration
- **Shell**: Bash (resolve-sponsors.sh, verify-sponsor-structure.sh)
- **CI/CD**: GitHub Actions
- **Traceability**: trace_view package with multi-repo support

---

# REQ-d00086: Sponsor Repository Structure Template

**Level**: Dev | **Implements**: o00076 | **Status**: Draft

Sponsor repositories SHALL follow a standard directory structure template with required and optional directories for sponsor-specific code and configuration.

Implementation SHALL include required directories:
- `spec/` - Sponsor-specific requirements with namespace prefix
- `spec/INDEX.md` - Sponsor requirement index
- `docs/` - Sponsor documentation
- `config/` - Sponsor configuration files

Required files:
- `.core-repo` - Path to core repository worktree (see REQ-d00087)
- `.elspais.toml` - Elspais configuration with sponsor-specific patterns
- `sponsor-config.yml` - Sponsor configuration with name, code, namespace
- `README.md` - Setup and development instructions

Optional directories (migrated when implementation code moves):
- `lib/` - Dart library code
- `mobile-module/` - Mobile app integration
- `portal/` - Portal customizations
- `database/` - Sponsor-specific SQL

**Rationale**: Consistent structure enables automated validation and simplifies onboarding for developers working across sponsors.

**Acceptance Criteria**:
- `tools/build/verify-sponsor-structure.sh` validates required structure
- All required files present and correctly formatted
- sponsor-config.yml passes schema validation
- README.md contains complete setup instructions
- `elspais validate` passes in sponsor repository

*End* *Sponsor Repository Structure Template* | **Hash**: fadb6266

---

# REQ-d00087: Core Repo Reference Configuration

**Level**: Dev | **Implements**: d00086 | **Status**: Draft

Sponsor repositories SHALL use a `.core-repo` configuration file to reference the core repository location for cross-repository validation and requirement linking.

Implementation SHALL include:
- `.core-repo` file format: plain text containing relative path
- Default pattern: `../hht_diary-worktrees/{sponsor-codename}`
- Path resolved relative to sponsor repository root

Path resolution order (highest priority first):
1. `--core-repo` CLI argument
2. `.core-repo` file in repository root
3. Environment variable `CORE_REPO_PATH`
4. Default: assume running in core repo (no cross-repo validation)

Validation rules:
- Path must exist and be a git repository
- Must contain `spec/` directory with valid requirements
- Must contain `.elspais.toml` configuration
- Must contain `tools/requirements/` tooling

**Rationale**: Explicit core repo reference enables cross-repository requirement validation while supporting multiple development environments (local, CI/CD, worktrees).

**Acceptance Criteria**:
- Validation scripts resolve core repo path correctly
- Cross-repository requirement links validated
- Warning displayed when `.core-repo` path not found
- CI/CD environments can override via SPONSOR_MANIFEST

*End* *Core Repo Reference Configuration* | **Hash**: 71b148c5

---

# REQ-d00088: Sponsor Requirement Namespace Validation

**Level**: Dev | **Implements**: o00077 | **Status**: Draft

Requirements in sponsor repositories SHALL use namespaced IDs with the sponsor code prefix, validated by tooling to prevent namespace collisions.

Implementation SHALL include namespace format:
- Sponsor requirements: `REQ-{CODE}-{type}{number}`
- CODE: 2-4 uppercase letters matching sponsor code (e.g., CAL, TIT)
- type: `p` (PRD), `o` (Ops), `d` (Dev)
- number: 5 digits (00001-99999)

Examples:
- Core requirement: `REQ-d00042`
- Callisto sponsor: `REQ-CAL-d00001`
- Titan sponsor: `REQ-TIT-p00003`

Validation rules:
- Sponsor repos MUST use namespaced IDs (REQ-{CODE}-*)
- Sponsor repos MAY NOT define core IDs (REQ-{type}{number})
- Core repo MAY NOT define namespaced IDs
- "Implements" links may cross namespaces (sponsor -> core)

Elspais configuration in sponsor `.elspais.toml`:
```toml
[patterns.associated]
enabled = true
prefix = "CAL"  # Sponsor code
```

**Rationale**: Namespace prefixes prevent ID collisions when multiple sponsors exist and make it clear which sponsor owns each requirement.

**Acceptance Criteria**:
- `elspais validate` validates namespace consistency
- `validate-commit-msg.sh` accepts both core and sponsor formats
- No namespace conflicts between sponsors
- Cross-namespace "Implements" links resolve correctly

*End* *Sponsor Requirement Namespace Validation* | **Hash**: bdf0c216

---

# REQ-d00089: Cross-Repository Traceability

**Level**: Dev | **Implements**: o00077, p00020 | **Status**: Draft

Traceability matrix generation SHALL support multiple repositories, producing combined and per-sponsor reports with cross-repository requirement link validation.

Implementation SHALL include multi-repository scanning:
- `trace_view` package supports `--mode` parameter: core, sponsor, combined
- `tools/build/resolve-sponsors.sh` provides unified sponsor list
- Sources (priority order): Doppler SPONSOR_MANIFEST → sponsors.yml → directory scan

Implementation file scanning:
- Core patterns: `packages/**/*.dart`, `apps/**/*.dart`, `tools/**/*.py`
- Sponsor patterns (mono-repo): `sponsor/{name}/**/*.dart`
- Remote sponsor: Clone to `build/sponsors/` then scan

Report output structure:
```
build-reports/
├── combined/traceability/
│   ├── traceability-matrix.md
│   └── traceability-matrix.html
└── {sponsor}/traceability/
    ├── traceability-matrix.md
    └── traceability-matrix.html
```

**Rationale**: Cross-repository traceability ensures requirements are tracked across the distributed codebase and enables sponsor-specific compliance reports.

**Acceptance Criteria**:
- Combined matrix includes all core and sponsor requirements
- Per-sponsor matrices filter to relevant requirements only
- Cross-repository "Implements" links validated successfully
- Orphaned requirements (no implementation) reported as warnings

*End* *Cross-Repository Traceability* | **Hash**: 285f6952

---
