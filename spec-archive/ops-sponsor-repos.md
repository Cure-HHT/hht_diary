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

**Level**: Ops | **Status**: Draft | **Implements**: p01057

## Rationale

This requirement establishes a standardized process for creating and configuring new sponsor repositories in the multi-sponsor clinical trial platform. Consistent repository provisioning is critical for maintaining sponsor isolation while ensuring integration with core platform capabilities. The standardized structure enables automated validation tools to verify repository compliance, supports the plugin-based build system (elspais), and ensures proper access controls are established from the outset. This reduces configuration drift, prevents integration issues, and maintains the security boundaries required for multi-sponsor deployments in FDA-regulated clinical trials.

## Assertions

A. The operations team SHALL follow a standardized procedure for provisioning new sponsor repositories.

B. New sponsor repositories SHALL use the naming convention 'hht_diary_{sponsor-name}' with underscore separators.

C. New sponsor repositories SHALL be initialized with a standard directory structure from template.

D. New sponsor repositories SHALL grant access to the sponsor team.

E. New sponsor repositories SHALL grant admin access to core maintainers.

F. New sponsor repositories SHALL have branch protection rules that require pull requests.

G. New sponsor repositories SHALL have branch protection rules that require reviews.

H. New sponsor repositories SHALL include a '.core-repo' file in the initial content.

I. New sponsor repositories SHALL include a 'spec/' directory in the initial content.

J. New sponsor repositories SHALL include an '.elspais.toml' file in the initial content.

K. New sponsor repositories SHALL include a 'sponsor-config.yml' file in the initial content.

L. New sponsor repositories SHALL include a README.md with sponsor-specific setup instructions.

M. New sponsor repositories SHALL pass validation by 'tools/build/verify-sponsor-structure.sh'.

N. New sponsor repositories SHALL pass 'elspais validate' before being considered complete.

O. The Doppler SPONSOR_MANIFEST SHALL be updated with a new entry for each provisioned sponsor.

*End* *Sponsor Repository Provisioning* | **Hash**: 831fa654

---

# REQ-o00077: Sponsor CI/CD Integration

**Level**: Ops | **Status**: Draft | **Implements**: p01057

## Rationale

This requirement ensures that sponsor repositories remain synchronized with core platform requirements through automated continuous integration and validation. CI/CD integration prevents configuration drift, namespace conflicts, and broken requirement traceability across the distributed multi-sponsor architecture. Automated validation on both scheduled intervals and PR events catches issues early, while cross-repository traceability matrices provide visibility into requirement implementation status across all sponsors. Failure handling mechanisms ensure that validation issues are promptly surfaced to the appropriate maintainers through multiple channels (PR blocks, Linear tickets, email notifications).

## Assertions

A. The system SHALL provide a weekly scheduled workflow that validates all remote sponsor repositories.

B. The system SHALL trigger sponsor repository validation when a PR is created in any sponsor repository.

C. The core repository CI pipeline SHALL include sponsor validation when a SPONSOR_MANIFEST file is available.

D. Sponsor validation SHALL verify directory structure compliance.

E. Sponsor validation SHALL verify requirement namespace correctness.

F. Sponsor validation SHALL verify that implements links are valid.

G. The system SHALL execute 'elspais validate' on all sponsor requirements during validation.

H. The system SHALL generate a combined cross-repository traceability matrix that includes all sponsors.

I. The system SHALL generate per-sponsor cross-repository traceability matrices.

J. The system SHALL block PR merge when sponsor validation fails.

K. The system SHALL create Linear tickets automatically when validation failures occur.

L. The system SHALL notify sponsor maintainers via email when validation failures occur.

M. Validation reports SHALL include the output from 'elspais validate'.

*End* *Sponsor CI/CD Integration* | **Hash**: 7104b083

---
