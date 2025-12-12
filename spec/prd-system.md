# Clinical Trial Diary Platform

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-02
**Status**: Active

> **See**: prd-diary-app.md for mobile application requirements
> **See**: prd-portal.md for sponsor portal requirements
> **See**: prd-database.md for data storage requirements
> **See**: prd-backup.md for backup and archival requirements
> **See**: prd-devops.md for operations and monitoring requirements
> **See**: prd-services.md for ancillary services requirements

---

## Executive Summary

The Clinical Trial Diary Platform is a multi-sponsor system for FDA 21 CFR Part 11 compliant clinical trial data capture. Patients record health observations via mobile app, sponsors access data through web portals, and compliant cloud infrastructure ensures data integrity, security, and long-term retention.

---

# REQ-p00044: Clinical Trial Diary Platform

**Level**: PRD | **Implements**: - | **Status**: Active

A multi-sponsor clinical trial data capture platform enabling patients to record health observations via mobile app, with sponsor access through web portals, backed by compliant cloud infrastructure.

Platform components SHALL include:
- Patient-facing mobile application (prd-diary-app.md)
- Sponsor-specific web portals (prd-portal.md)
- Cloud database with event sourcing (prd-database.md)
- Long-term backup and archival storage (prd-backup.md)
- DevOps monitoring and support systems (prd-devops.md)
- Ancillary services including push notifications (prd-services.md)

**Rationale**: Defines the complete system scope for FDA 21 CFR Part 11 compliant clinical trial data capture across multiple pharmaceutical sponsors. Component separation enables independent development, testing, and deployment while maintaining system-wide compliance.

**Acceptance Criteria**:
- All platform components operational and integrated
- Complete audit trail maintained across all system boundaries
- Multi-sponsor isolation enforced throughout all components
- FDA 21 CFR Part 11 compliance demonstrated for complete platform

*End* *Clinical Trial Diary Platform* | **Hash**: 0e8a8d5b

---

# REQ-p01041: Open Source Licensing

**Level**: PRD | **Implements**: - | **Status**: Active

The Clinical Trial Diary Platform core codebase SHALL be licensed under the GNU Affero General Public License v3.0 (AGPL-3.0) to ensure derivative works remain open source and network use triggers source disclosure requirements.

Licensing SHALL specify:
- AGPL-3.0 for core platform code (packages/, apps/, database/)
- Sponsor-specific code in sponsor/ directories remains proprietary to each sponsor
- Documentation in docs/ licensed under CC-BY-SA 4.0
- Third-party dependencies must be compatible with AGPL-3.0

**Rationale**: AGPL-3.0 ensures modifications to the platform are shared back with the community while allowing the core platform to benefit from open source collaboration. The copyleft provisions protect against proprietary forks while the network use clause ensures SaaS deployments also share improvements. Sponsor isolation ensures each sponsor's proprietary customizations remain protected.

**Acceptance Criteria**:
- LICENSE file exists at repository root with complete AGPL-3.0 text
- All source files include appropriate license headers or reference root LICENSE
- Sponsor directories clearly marked as proprietary in their README files
- CONTRIBUTING.md references licensing requirements for contributions
- Third-party dependency audit confirms AGPL-3.0 compatibility

*End* *Open Source Licensing* | **Hash**: 8c10dd61

---

## Platform Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CLINICAL TRIAL DIARY PLATFORM                     │
│                         (REQ-p00044)                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Mobile App  │  │   Sponsor    │  │    Ancillary Services    │  │
│  │  (p00043)    │  │   Portal     │  │        (p00049)          │  │
│  │              │  │   (p00045)   │  │  - Push Notifications    │  │
│  │  - iOS      │  │              │  │  - Email Services        │  │
│  │  - Android   │  │  - Admin     │  │  - Reporting             │  │
│  │  - Offline   │  │  - Invest.   │  │                          │  │
│  │              │  │  - Auditor   │  │                          │  │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬─────────────┘  │
│         │                 │                        │                │
│         └─────────────────┴────────────────────────┘                │
│                           │                                         │
│              ┌────────────▼────────────┐                           │
│              │   Cloud Database        │                           │
│              │      (p00046)           │                           │
│              │   - Event Sourcing      │                           │
│              │   - Audit Trail         │                           │
│              │   - Sponsor Isolation   │                           │
│              └────────────┬────────────┘                           │
│                           │                                         │
│         ┌─────────────────┴─────────────────┐                      │
│         │                                   │                      │
│  ┌──────▼──────┐                    ┌───────▼───────┐              │
│  │   Backup    │                    │    DevOps     │              │
│  │  (p00047)   │                    │   (p00048)    │              │
│  │             │                    │               │              │
│  │ - Archives  │                    │ - Monitoring  │              │
│  │ - Retention │                    │ - Alerts      │              │
│  │ - Recovery  │                    │ - Support     │              │
│  └─────────────┘                    └───────────────┘              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Compliance Framework

**FDA 21 CFR Part 11**: Electronic records and signatures
**ALCOA+ Principles**: Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available

**See**: prd-clinical-trials.md for detailed compliance requirements

---

## References

- **Mobile App**: prd-diary-app.md
- **Portal**: prd-portal.md
- **Database**: prd-database.md
- **Backup**: prd-backup.md
- **DevOps**: prd-devops.md
- **Services**: prd-services.md
- **Security**: prd-security.md
- **Compliance**: prd-clinical-trials.md
- **Architecture**: prd-architecture-multi-sponsor.md
