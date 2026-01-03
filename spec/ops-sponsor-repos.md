# Sponsor Repository Operations

**Version**: 1.0
**Audience**: Operations
**Last Updated**: 2026-01-03
**Status**: Draft

> **See**: dev-sponsor-repos.md for development implementation details
> **See**: docs/sponsor-development-guide.md for developer workflow

---

## Executive Summary

This document defines operational requirements for managing separate sponsor repositories in the multi-repo architecture. It covers repository provisioning procedures and CI/CD integration for sponsor validation.

---

# REQ-o00076: Sponsor Repository Provisioning

**Level**: Ops | **Implements**: p01057 | **Status**: Draft

The operations team SHALL follow a standardized procedure for provisioning new sponsor repositories with correct structure, access controls, and integration with the core repository.

Implementation SHALL include:
- Repository naming convention: `hht_diary_{sponsor-name}` (underscore naming)
- Standard directory structure initialized from template
- Access configuration: sponsor team access, core maintainer admin access
- Branch protection rules: require PR, require reviews
- Initial content: `.core-repo` file, `spec/` directory, `.elspais.toml`, `sponsor-config.yml`
- Validation: `tools/build/verify-sponsor-structure.sh` passes on new repo

**Rationale**: Standardized provisioning ensures consistent repository structure across all sponsors, reducing integration issues and enabling automated validation.

**Acceptance Criteria**:
- Repository created with correct naming convention
- Access permissions configured per sponsor team requirements
- Initial structure validates with verify-sponsor-structure.sh
- `elspais validate` passes on new repository
- Doppler SPONSOR_MANIFEST updated with new sponsor entry
- README.md includes sponsor-specific setup instructions

*End* *Sponsor Repository Provisioning* | **Hash**: d6cb1b36

---

# REQ-o00077: Sponsor CI/CD Integration

**Level**: Ops | **Implements**: p01057 | **Status**: Draft

CI/CD pipelines SHALL integrate sponsor repository validation with core repository requirements, including scheduled validation of all remote sponsors and cross-repository traceability generation.

Implementation SHALL include:
- Weekly scheduled workflow validates all remote sponsor repos
- Validation triggered on sponsor repository PR creation
- Core repo CI includes sponsor validation when SPONSOR_MANIFEST available
- Validation checks: directory structure, requirement namespace, implements links
- Elspais validation: `elspais validate` runs on all sponsor requirements
- Cross-repository traceability matrix generation (combined and per-sponsor)
- Failure handling: block PRs, create Linear tickets, notify maintainers

**Rationale**: Automated CI/CD integration ensures sponsor repositories remain synchronized with core requirements and prevents drift over time.

**Acceptance Criteria**:
- Weekly validation workflow runs successfully on schedule
- PR validation blocks merge when sponsor validation fails
- Traceability reports generated for combined and per-sponsor views
- `elspais validate` output included in validation reports
- Validation failures create Linear tickets automatically
- Email notifications delivered to sponsor maintainers on failure

*End* *Sponsor CI/CD Integration* | **Hash**: 672b8201

---
