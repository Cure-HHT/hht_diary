## REQ-p00044: Clinical Trial Compliant Diary Platform

**Level**: prd | **Status**: Proposed | **Implements**: -

## Assertions

A. The system SHALL deploy a digital health technology (DHT) mobile app that allows the patient to collect and track information for their own use.

B. The system SHALL provide a platform for collecting patient-reported clinical diary data for regulated clinical trials.

C. The system SHALL support multiple independent pharmaceutical sponsors within a single platform.

D. The system SHALL enable sponsor access to trial data via web-based interfaces.

E. The system SHALL operate in a manner compliant with applicable regulations.

## Rationale

This requirement defines the existence, scope, and regulatory nature of the platform without constraining internal design or implementation mechanisms.

*End* *Clinical Trial Compliant Diary Platform* | **Hash**: 0919ad00
---
## REQ-p01041: Open Source Licensing

**Level**: prd | **Status**: Draft | **Implements**: -

## Assertions

A. The Veritite core codebase SHALL be licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

B. Sponsor-specific extensions and customizations SHALL be permitted to remain proprietary to each sponsor.

C. Platform documentation SHALL be distributed under an open documentation license compatible with redistribution and modification.

## Rationale

Open-source licensing ensures transparency, encourages collaboration, and prevents
closed proprietary forks of the core platform while preserving sponsor IP boundaries.

*End* *Open Source Licensing* | **Hash**: 7e6b1e00
---
## REQ-p01079: License Display

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01041

## Assertions

A. Each application SHALL display the full text of the license for any included code or content.

B. Each application SHALL NOT fetch license content from external URLs at runtime.

C. Each license SHALL be clearly labeled with its name and the software or asset it applies to.

D. The license display SHALL scroll license text when necessary to allow viewing of the full license.

E. The license display SHALL provide a way to return to the previous screen or page.

## Rationale

Open-source license compliance requires that applications display the full text of all applicable licenses to end users. This platform-wide requirement ensures every application in the system provides a dedicated location for license viewing, regardless of the specific deployment target.

*End* *License Display* | **Hash**: 0a061e18
---
## REQ-p01074: User-Facing State Change Communication

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01085

## Assertions

A. When a user action is rejected because the target resource was modified or removed by another actor, the system SHALL display a clear, specific message explaining that the resource is no longer available.

B. Error messages for server-side state changes SHALL NOT imply the user made an error or did anything wrong.

C. When a user's in-progress work cannot be accepted due to a server-side state change, the system SHALL explicitly acknowledge that the user's work was not saved.

D. After displaying a state-change error, the system SHALL return the user to a navigable screen where the invalidated resource no longer appears as actionable.

## Rationale

Multi-user clinical systems allow staff actions (deletion, reassignment, protocol changes) that may invalidate work a patient is actively performing. Without a platform-wide principle, each feature invents its own error handling, leading to inconsistent messaging, silent data loss, or error text that blames the patient. This requirement establishes a baseline contract: when the system cannot accept user work because of a state change initiated by another actor, the user is told clearly, respectfully, and without loss of navigational context.

*End* *User-Facing State Change Communication* | **Hash**: ec6b0b1d
---
# Veritite (tm) - the Open eSource

**Version**: 1.1
**Audience**: Product Requirements
**Status**: Draft
**Reviewed**: 2026-01-01 Michael Lewis
---

---

## Executive Summary

Veritite is a collection of applications and services that enables the deployment of a user-centric cross-platform health-related data collection application. Initially designed to implement a daily nosebleed diary for Cure HHT as a service to its patients.

Veritite also supports using this data in regulated clinical trials and scientific studies by implementing best-in-class tamper-proofing for evidence records and traceability. Sponsors and investigators access trial data through secure web portals.

The platform operates on cloud infrastructure designed to ensure data integrity, security, auditability, and regulatory acceptance.

---


---


---


---
