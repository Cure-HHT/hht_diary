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

**Level**: Dev | **Status**: Draft | **Implements**: o00076

## Rationale

This requirement establishes a standardized directory structure and configuration template for sponsor repositories to ensure consistency across all sponsor-specific implementations. A uniform structure enables automated validation tools to verify repository completeness, simplifies developer onboarding when working across multiple sponsors, and ensures that sponsor-specific code and configuration are organized predictably. This supports the multi-sponsor deployment model where each sponsor has isolated code while sharing the core platform.

## Assertions

A. The sponsor repository SHALL include a spec/ directory for sponsor-specific requirements with namespace prefix.
B. The sponsor repository SHALL include a spec/INDEX.md file containing the sponsor requirement index.
C. The sponsor repository SHALL include a docs/ directory for sponsor documentation.
D. The sponsor repository SHALL include a config/ directory for sponsor configuration files.
E. The sponsor repository SHALL include a .core-repo file containing the path to the core repository worktree.
F. The sponsor repository SHALL include a .elspais.toml file containing Elspais configuration with sponsor-specific patterns.
G. The sponsor repository SHALL include a sponsor-config.yml file containing sponsor configuration with name, code, and namespace.
H. The sponsor repository SHALL include a README.md file containing setup and development instructions.
I. The tools/build/verify-sponsor-structure.sh script SHALL validate that the required structure is present.
J. The sponsor-config.yml file SHALL pass schema validation.
K. The README.md file SHALL contain complete setup instructions.
L. The elspais validate command SHALL pass when executed in the sponsor repository.

*End* *Sponsor Repository Structure Template* | **Hash**: 4b7874ee

---

# REQ-d00087: Core Repo Reference Configuration

**Level**: Dev | **Status**: Draft | **Implements**: d00086

## Rationale

This requirement establishes a configuration mechanism for sponsor repositories to reference their parent core repository location. This reference enables cross-repository validation and requirement linking while supporting multiple development environments (local, CI/CD, worktrees). The configuration follows a priority-based resolution pattern to accommodate different deployment scenarios, from developer workstations using worktrees to CI/CD pipelines with custom paths. The validation rules ensure the referenced core repository is valid and contains the necessary tooling and requirements infrastructure.

## Assertions

A. Sponsor repositories SHALL use a `.core-repo` configuration file to reference the core repository location for cross-repository validation and requirement linking.
B. The `.core-repo` file format SHALL be plain text containing a relative path.
C. The default path pattern SHALL be `../hht_diary-worktrees/{sponsor-codename}`.
D. The path SHALL be resolved relative to the sponsor repository root.
E. The system SHALL resolve the core repository path using the following priority order: (1) `--core-repo` CLI argument, (2) `.core-repo` file in repository root, (3) environment variable `CORE_REPO_PATH`, (4) default assumption of running in core repo with no cross-repo validation.
F. The system SHALL validate that the resolved path exists and is a git repository.
G. The system SHALL validate that the core repository contains a `spec/` directory with valid requirements.
H. The system SHALL validate that the core repository contains a `.elspais.toml` configuration file.
I. The system SHALL validate that the core repository contains `tools/requirements/` tooling.
J. Validation scripts SHALL resolve the core repo path correctly according to the priority order.
K. The system SHALL validate cross-repository requirement links.
L. The system SHALL display a warning when the `.core-repo` path is not found.
M. CI/CD environments SHALL be able to override the core repo path via SPONSOR_MANIFEST.

*End* *Core Repo Reference Configuration* | **Hash**: 91ce804d

---

# REQ-d00088: Sponsor Requirement Namespace Validation

**Level**: Dev | **Status**: Draft | **Implements**: o00077

## Rationale

This requirement ensures that in a multi-sponsor deployment model, each sponsor's requirements are uniquely identified through namespaced requirement IDs. The namespace system prevents identifier collisions across sponsors while maintaining clear ownership and traceability. By enforcing namespace validation through automated tooling, the system guarantees that sponsor-specific requirements cannot conflict with core platform requirements or other sponsors' requirements. This isolation is critical for maintaining independent sponsor repositories while allowing cross-namespace implementation relationships when sponsor code builds upon core platform capabilities.

## Assertions

A. Requirements in sponsor repositories SHALL use namespaced IDs with the sponsor code prefix.
B. Sponsor requirement IDs SHALL follow the format REQ-{CODE}-{type}{number} where CODE is the sponsor code, type is p/o/d, and number is 5 digits.
C. The CODE component SHALL be 2-4 uppercase letters matching the sponsor code.
D. The type component SHALL be one of: p (PRD), o (Ops), or d (Dev).
E. The number component SHALL be 5 digits in the range 00001-99999.
F. Sponsor repositories SHALL NOT define core requirement IDs using the format REQ-{type}{number}.
G. The core repository SHALL NOT define namespaced requirement IDs.
H. Sponsor repositories SHALL validate namespace consistency through tooling.
I. The elspais validation tool SHALL validate namespace consistency when invoked.
J. The validate-commit-msg.sh script SHALL accept both core format (REQ-{type}{number}) and sponsor format (REQ-{CODE}-{type}{number}) requirement IDs.
K. The system SHALL prevent namespace conflicts between different sponsors.
L. Cross-namespace 'Implements' links from sponsor requirements to core requirements SHALL be permitted.
M. Cross-namespace 'Implements' links SHALL resolve correctly during validation.
N. Sponsor .elspais.toml configuration files SHALL include a patterns.associated section with enabled=true and the sponsor prefix.

*End* *Sponsor Requirement Namespace Validation* | **Hash**: 128e817d

---

# REQ-d00089: Cross-Repository Traceability

**Level**: Dev | **Status**: Draft | **Implements**: o00077, p00020

## Rationale

Cross-repository traceability ensures requirements are tracked across the distributed codebase architecture where core functionality exists in the main repository alongside per-sponsor implementations that may exist either as subdirectories or as separate repositories. This capability is essential for generating sponsor-specific compliance reports while maintaining a comprehensive view of all requirement implementations. The traceability system must handle both monorepo sponsor implementations and remote sponsor repositories, resolving sponsor lists from multiple sources and producing both unified and filtered views. This supports FDA 21 CFR Part 11 compliance by providing auditable evidence that all requirements have been implemented and validated across the distributed architecture.

## Assertions

A. The trace_view package SHALL support a --mode parameter that accepts the values: core, sponsor, or combined.
B. The system SHALL use tools/build/resolve-sponsors.sh to provide a unified sponsor list.
C. The system SHALL resolve sponsor sources in priority order: Doppler SPONSOR_MANIFEST, then sponsors.yml, then directory scan.
D. The system SHALL scan core implementation files matching the patterns: packages/**/*.dart, apps/**/*.dart, and tools/**/*.py.
E. The system SHALL scan sponsor implementation files in monorepo deployments matching the pattern: sponsor/{name}/**/*.dart.
F. The system SHALL clone remote sponsor repositories to build/sponsors/ before scanning their implementation files.
G. The system SHALL generate combined traceability reports in the directory: build-reports/combined/traceability/.
H. The system SHALL generate per-sponsor traceability reports in the directory: build-reports/{sponsor}/traceability/.
I. The system SHALL output traceability matrices in both Markdown (.md) and HTML (.html) formats.
J. Combined traceability matrices SHALL include all core requirements and all sponsor requirements.
K. Per-sponsor traceability matrices SHALL filter to include only requirements relevant to that specific sponsor.
L. The system SHALL validate all cross-repository 'Implements' links during traceability matrix generation.
M. The system SHALL report orphaned requirements with no implementation as warnings in the traceability output.

*End* *Cross-Repository Traceability* | **Hash**: ca7aeae6

---
