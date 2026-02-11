# Veritite (tm) - the Open eSource

**Version**: 1.1
**Audience**: Product Requirements
**Status**: Draft
**Reviewed**: 2026-01-01 Michael Lewis
---

---

## Executive Summary

Veritite is a collection of applications and services that enables the deployment
of a user-centric cross-platform health-related data collection application. Initially
designed to implement a daily nosebleed diary for Cure HHT as a service to its pa

Veritite also supports using this dat in regulated clinical trials and scientific
studies by implementing best-in-class tamper-proofing for evidence records and
traceability. Sponsors and investigators access trial data through secure web portals.
The platform operates on compliant cloud infrastructure designed to ensure
data integrity, security, auditability, and regulatory acceptance.

---

# REQ-p00044: Clinical Trial Compliant Diary Platform

**Level**: PRD  **Status**: Draft  **Implements**: -

## Rationale

This requirement defines the existence, scope, and regulatory nature of the platform without constraining internal design or implementation mechanisms.

## Assertions

A. The system SHALL provide a platform for collecting patient-reported clinical diary data for regulated clinical trials.
B. The system SHALL support multiple independent pharmaceutical sponsors within a single platform.
C. The system SHALL enable patient data entry via mobile applications.
D. The system SHALL enable sponsor and investigator access to trial data via web-based interfaces.
E. The system SHALL operate in a manner compliant with FDA regulations governing electronic records.
F. The system SHALL comply with all applicable regulatory requirements for electronic records and data integrity in clinical investigations.

*End* *Clinical Trial Compliant Diary Platform* | **Hash**: 7933530e
---

# REQ-p01041: Open Source Licensing

**Level**: PRD  **Status**: Draft  **Implements**: -

## Rationale

Open-source licensing ensures transparency, encourages collaboration, and prevents
closed proprietary forks of the core platform while preserving sponsor IP boundaries.

## Assertions

A. The Veritite core codebase SHALL be licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
B. Sponsor-specific extensions and customizations SHALL be permitted to remain proprietary to each sponsor.
C. Platform documentation SHALL be distributed under an open documentation license compatible with redistribution and modification.

*End* *Open Source Licensing* | **Hash**: 7e6b1e00
