# Requirements Index

This file provides a complete index of all formal requirements across the spec/ directory. Each requirement is listed with its ID, containing file, and title.

**Maintenance Rules:**
- When adding a new requirement, add it to this index with the correct file reference and hash (calculate from requirement body)
- When modifying a requirement, update its hash using `python3 tools/requirements/update-REQ-hashes.py`
- When moving a requirement to a different file, update the file reference
- When removing/deprecating a requirement, change its file reference to `obsolete` and leave description blank
- Keep requirements sorted by ID (REQ-p, REQ-o, REQ-d in ascending numerical order)
- Hash format: First 8 characters of SHA-256 of requirement body text

---

| Requirement ID | File | Title | Hash |
|----------------|------|-------|------|
| REQ-p00001 | prd-security.md | Complete Multi-Sponsor Data Separation | c27350bb |
| REQ-p00002 | prd-security.md | Multi-Factor Authentication for Staff | 91af5dfc |
| REQ-p00003 | prd-database.md | Separate Database Per Sponsor | cfeffc86 |
| REQ-p00004 | prd-database.md | Immutable Audit Trail via Event Sourcing | 914a0234 |
| REQ-p00005 | prd-security-RBAC.md | Role-Based Access Control | 86b90509 |
| REQ-p00006 | prd-app.md | Offline-First Data Entry | 8143105a |
| REQ-p00007 | prd-app.md | Automatic Sponsor Configuration | 3df862a3 |
| REQ-p00008 | prd-architecture-multi-sponsor.md | Single Mobile App for All Sponsors | b095a902 |
| REQ-p00009 | prd-architecture-multi-sponsor.md | Sponsor-Specific Web Portals | 02bb542a |
| REQ-p00010 | prd-clinical-trials.md | FDA 21 CFR Part 11 Compliance | 5204b6f9 |
| REQ-p00011 | prd-clinical-trials.md | ALCOA+ Data Integrity Principles | 994bcd05 |
| REQ-p00012 | prd-clinical-trials.md | Clinical Data Retention Requirements | 8dc29952 |
| REQ-p00013 | prd-database.md | Complete Data Change History | 2d24be49 |
| REQ-p00014 | prd-security-RBAC.md | Least Privilege Access | 6346857d |
| REQ-p00015 | prd-security-RLS.md | Database-Level Access Enforcement | 1ea07e73 |
| REQ-p00016 | prd-security-data-classification.md | Separation of Identity and Clinical Data | 05dfac6b |
| REQ-p00017 | prd-security-data-classification.md | Data Encryption | b44b790d |
| REQ-p00018 | prd-architecture-multi-sponsor.md | Multi-Site Support Per Sponsor | 382707d6 |
| REQ-p00020 | prd-requirements-management.md | System Validation and Traceability | 73d9a7b5 |
| REQ-p00021 | prd-requirements-management.md | Architecture Decision Documentation | a11d9fc7 |
| REQ-p00022 | prd-security-RLS.md | Analyst Read-Only Access | 229391e5 |
| REQ-p00023 | prd-security-RLS.md | Sponsor Global Data Access | e6cdb6b4 |
| REQ-p00024 | prd-portal.md | Portal User Roles and Permissions | 2f8ca74f |
| REQ-p00025 | prd-portal.md | Patient Enrollment Workflow | 0a834b94 |
| REQ-p00026 | prd-portal.md | Patient Monitoring Dashboard | faf10c05 |
| REQ-p00027 | prd-portal.md | Questionnaire Management | 18601191 |
| REQ-p00028 | prd-portal.md | Token Revocation and Access Control | 8689afc2 |
| REQ-p00029 | prd-portal.md | Auditor Dashboard and Data Export | e330f8d1 |
| REQ-p00030 | prd-portal.md | Role-Based Visual Indicators | f147ebcd |
| REQ-p00031 | requirements-format.md | Multi-Sponsor Data Isolation | TBD |
| REQ-p00032 | requirements-format.md | Complete Multi-Sponsor Data Separation | TBD |
| REQ-p00033 | requirements-format.md | Role-Based Access Control | TBD |
| REQ-p00034 | requirements-format.md | Least Privilege Access | TBD |
| REQ-p00035 | prd-security-RLS.md | Patient Data Isolation | 27e93c7b |
| REQ-p00036 | prd-security-RLS.md | Investigator Site-Scoped Access | 5c583e49 |
| REQ-p00037 | prd-security-RLS.md | Investigator Annotation Restrictions | f5977a47 |
| REQ-p00038 | prd-security-RLS.md | Auditor Compliance Access | 99d40d58 |
| REQ-p00039 | prd-security-RLS.md | Administrator Access with Audit Trail | 9e2ec3d2 |
| REQ-p00040 | prd-security-RLS.md | Event Sourcing State Protection | 33ec725b |
| REQ-p01000 | prd-event-sourcing-system.md | Event Sourcing Client Interface | 915d91f4 |
| REQ-p01001 | prd-event-sourcing-system.md | Offline Event Queue with Automatic Synchronization | f15223c6 |
| REQ-p01002 | prd-event-sourcing-system.md | Optimistic Concurrency Control | 574aaa9f |
| REQ-p01003 | prd-event-sourcing-system.md | Immutable Event Storage with Audit Trail | 55e911c7 |
| REQ-p01004 | prd-event-sourcing-system.md | Schema Version Management | c390f7cb |
| REQ-p01005 | prd-event-sourcing-system.md | Real-time Event Subscription | ec835735 |
| REQ-p01006 | prd-event-sourcing-system.md | Type-Safe Materialized View Queries | 21919f36 |
| REQ-p01007 | prd-event-sourcing-system.md | Error Handling and Diagnostics | b56402ec |
| REQ-p01008 | prd-event-sourcing-system.md | Event Replay and Time Travel Debugging | 5b149b28 |
| REQ-p01009 | prd-event-sourcing-system.md | Encryption at Rest for Offline Queue | 968f36ad |
| REQ-p01010 | prd-event-sourcing-system.md | Multi-tenancy Support | 3f0687fa |
| REQ-p01011 | prd-event-sourcing-system.md | Event Transformation and Migration | 9792e8f9 |
| REQ-p01012 | prd-event-sourcing-system.md | Batch Event Operations | e7120ede |
| REQ-p01013 | prd-event-sourcing-system.md | GraphQL or gRPC Transport Option | d225a194 |
| REQ-p01014 | prd-event-sourcing-system.md | Observability and Monitoring | 65df2fb2 |
| REQ-p01015 | prd-event-sourcing-system.md | Automated Testing Support | c05e43ff |
| REQ-p01016 | prd-event-sourcing-system.md | Performance Benchmarking | d180f21b |
| REQ-p01017 | prd-event-sourcing-system.md | Backward Compatibility Guarantees | 2076e414 |
| REQ-p01018 | prd-event-sourcing-system.md | Security Audit and Compliance | b2187382 |
| REQ-p01019 | prd-event-sourcing-system.md | Phased Implementation | fa64bac5 |
| REQ-o00001 | ops-deployment.md | Separate Supabase Projects Per Sponsor | 1aa28891 |
| REQ-o00002 | ops-deployment.md | Environment-Specific Configuration Management | 54c5bd14 |
| REQ-o00003 | ops-database-setup.md | Supabase Project Provisioning Per Sponsor | b8777482 |
| REQ-o00004 | ops-database-setup.md | Database Schema Deployment | 900d1c69 |
| REQ-o00005 | ops-operations.md | Audit Trail Monitoring | 04b77abb |
| REQ-o00006 | ops-security-authentication.md | MFA Configuration for Staff Accounts | 021603f9 |
| REQ-o00007 | ops-security.md | Role-Based Permission Configuration | c11c3254 |
| REQ-o00008 | ops-operations.md | Backup and Retention Policy | 34334e6b |
| REQ-o00009 | ops-deployment.md | Portal Deployment Per Sponsor | be86e5f1 |
| REQ-o00010 | ops-deployment.md | Mobile App Release Process | 48e95308 |
| REQ-o00011 | ops-database-setup.md | Multi-Site Data Configuration Per Sponsor | 8f416201 |
| REQ-o00013 | ops-requirements-management.md | Requirements Format Validation | 22af0a13 |
| REQ-o00014 | ops-requirements-management.md | Top-Down Requirement Cascade | 18aedc4c |
| REQ-o00015 | ops-requirements-management.md | Documentation Structure Enforcement | 1037e0ce |
| REQ-o00016 | ops-requirements-management.md | Architecture Decision Process | 7e9d3a1b |
| REQ-o00017 | ops-requirements-management.md | Version Control Workflow | 5ba1a2d6 |
| REQ-o00018 | obsolete |  | TBD |
| REQ-o00020 | ops-security-RLS.md | Patient Data Isolation Policy Deployment | 8d4e7a32 |
| REQ-o00021 | ops-security-RLS.md | Investigator Site-Scoped Access Policy Deployment | 7ea18ce5 |
| REQ-o00022 | ops-security-RLS.md | Investigator Annotation Access Policy Deployment | 608fb1b8 |
| REQ-o00023 | ops-security-RLS.md | Analyst Read-Only Access Policy Deployment | 2ee0bb2f |
| REQ-o00024 | ops-security-RLS.md | Sponsor Global Access Policy Deployment | f696024c |
| REQ-o00025 | ops-security-RLS.md | Auditor Compliance Access Policy Deployment | e4296c5a |
| REQ-o00026 | ops-security-RLS.md | Administrator Access Policy Deployment | 1dc17673 |
| REQ-o00027 | ops-security-RLS.md | Event Sourcing State Protection Policy Deployment | c4a4b91e |
| REQ-o00041 | ops-infrastructure-as-code.md | Infrastructure as Code for Cloud Resources | 489de0e9 |
| REQ-o00042 | ops-infrastructure-as-code.md | Infrastructure Change Control | 28850d4c |
| REQ-o00043 | ops-deployment-automation.md | Automated Deployment Pipeline | 6a8bf2e3 |
| REQ-o00044 | ops-deployment-automation.md | Database Migration Automation | 9e7027b6 |
| REQ-o00045 | ops-monitoring-observability.md | Error Tracking and Monitoring | 570d206c |
| REQ-o00046 | ops-monitoring-observability.md | Uptime Monitoring | e719be12 |
| REQ-o00047 | ops-monitoring-observability.md | Performance Monitoring | c2e1c383 |
| REQ-o00048 | ops-monitoring-observability.md | Audit Log Monitoring | 0030bda3 |
| REQ-o00049 | ops-artifact-management.md | Artifact Retention and Archival | 864489de |
| REQ-o00050 | ops-artifact-management.md | Environment Parity and Separation | 6b76ea92 |
| REQ-o00051 | ops-artifact-management.md | Change Control and Audit Trail | bb726ab2 |
| REQ-o00052 | ops-cicd.md | CI/CD Pipeline for Requirement Traceability | 0cad57b7 |
| REQ-o00053 | ops-cicd.md | Branch Protection Enforcement | 96d245eb |
| REQ-o00054 | ops-cicd.md | Audit Trail Generation for CI/CD | b61b9d6e |
| REQ-o00055 | ops-portal.md | Role-Based Visual Indicator Verification | 8a6eebbb |
| REQ-o00056 | requirements-format.md | Separate Supabase Projects Per Sponsor | TBD |
| REQ-d00001 | dev-configuration.md | Sponsor-Specific Configuration Loading | 97b389d8 |
| REQ-d00002 | dev-configuration.md | Pre-Build Configuration Validation | 5b807b30 |
| REQ-d00003 | dev-security.md | Supabase Auth Configuration Per Sponsor | 9a412da0 |
| REQ-d00004 | dev-app.md | Local-First Data Entry Implementation | 732efeed |
| REQ-d00005 | dev-app.md | Sponsor Configuration Detection Implementation | cf6c43b6 |
| REQ-d00006 | dev-app.md | Mobile App Build and Release Process | bc46e5a8 |
| REQ-d00007 | dev-database.md | Database Schema Implementation and Deployment | 7cbe14ae |
| REQ-d00008 | dev-security.md | MFA Enrollment and Verification Implementation | 4ab38fcb |
| REQ-d00009 | dev-security.md | Role-Based Permission Enforcement Implementation | b3cecfbf |
| REQ-d00010 | dev-security.md | Data Encryption Implementation | 72f2b4e1 |
| REQ-d00011 | dev-database.md | Multi-Site Schema Implementation | 50c3cb5d |
| REQ-d00012 | requirements-format.md | Environment-Specific Configuration Files | TBD |
| REQ-d00013 | dev-app.md | Application Instance UUID Generation | 25708b1c |
| REQ-d00014 | dev-requirements-management.md | Requirement Validation Tooling | 015357af |
| REQ-d00015 | dev-requirements-management.md | Traceability Matrix Auto-Generation | 0c380d15 |
| REQ-d00016 | dev-requirements-management.md | Code-to-Requirement Linking | 464331db |
| REQ-d00017 | dev-requirements-management.md | ADR Template and Lifecycle Tooling | a0c43044 |
| REQ-d00018 | dev-requirements-management.md | Git Hook Implementation | bcb5b49f |
| REQ-d00019 | dev-security-RLS.md | Patient Data Isolation RLS Implementation | e3f0124b |
| REQ-d00020 | dev-security-RLS.md | Investigator Site-Scoped RLS Implementation | 44561f06 |
| REQ-d00021 | dev-security-RLS.md | Investigator Annotation RLS Implementation | 1a591b82 |
| REQ-d00022 | dev-security-RLS.md | Analyst Read-Only RLS Implementation | cb610863 |
| REQ-d00023 | dev-security-RLS.md | Sponsor Global Access RLS Implementation | 580c876d |
| REQ-d00024 | dev-security-RLS.md | Auditor Compliance RLS Implementation | 66b4879e |
| REQ-d00025 | dev-security-RLS.md | Administrator Break-Glass RLS Implementation | 65895cc4 |
| REQ-d00026 | dev-security-RLS.md | Event Sourcing State Protection RLS Implementation | e79309b4 |
| REQ-d00027 | dev-environment.md | Containerized Development Environments | 8afe0445 |
| REQ-d00028 | dev-portal.md | Portal Frontend Framework | 0156e239 |
| REQ-d00029 | dev-portal.md | Portal UI Design System | 9a779c24 |
| REQ-d00030 | dev-portal.md | Portal Routing and Navigation | bdc1a330 |
| REQ-d00031 | dev-portal.md | Supabase Authentication Integration | 00d11f56 |
| REQ-d00032 | dev-portal.md | Role-Based Access Control Implementation | 77826f31 |
| REQ-d00033 | dev-portal.md | Site-Based Data Isolation | e0a8af01 |
| REQ-d00034 | dev-portal.md | Login Page Implementation | 741fd685 |
| REQ-d00035 | dev-portal.md | Admin Dashboard Implementation | 49a18ff7 |
| REQ-d00036 | dev-portal.md | Create User Dialog Implementation | dceecc76 |
| REQ-d00037 | dev-portal.md | Investigator Dashboard Implementation | 4739a12f |
| REQ-d00038 | dev-portal.md | Enroll Patient Dialog Implementation | e8be1c1b |
| REQ-d00039 | dev-portal.md | Portal Users Table Schema | 1d2b06d4 |
| REQ-d00040 | dev-portal.md | User Site Access Table Schema | 19187974 |
| REQ-d00041 | dev-portal.md | Patients Table Extensions for Portal | 94ed0160 |
| REQ-d00042 | dev-portal.md | Questionnaires Table Schema | f4671fda |
| REQ-d00043 | dev-portal.md | Netlify Deployment Configuration | ac19e32e |
| REQ-d00051 | dev-portal.md | Auditor Dashboard Implementation | ff98b05e |
| REQ-d00052 | dev-portal.md | Role-Based Banner Component | fbe3cfdc |
| REQ-d00053 | dev-requirements-management.md | Development Environment and Tooling Setup | 8a1a0967 |
| REQ-d00055 | dev-environment.md | Role-Based Environment Separation | 5aad618b |
| REQ-d00056 | dev-environment.md | Cross-Platform Development Support | b9002165 |
| REQ-d00057 | dev-environment.md | CI/CD Environment Parity | f4d1f7d0 |
| REQ-d00058 | dev-environment.md | Secrets Management via Doppler | f33a510e |
| REQ-d00059 | dev-environment.md | Development Tool Specifications | c362162a |
| REQ-d00060 | dev-environment.md | VS Code Dev Containers Integration | 881f5a00 |
| REQ-d00061 | dev-environment.md | Automated QA Workflow | ada56bbf |
| REQ-d00062 | dev-environment.md | Environment Validation & Change Control | 09e427c2 |
| REQ-d00063 | dev-environment.md | Shared Workspace and File Exchange | d7c0156f |

---

**Total Requirements:** 154 (62 PRD, 39 Ops, 52 Dev, 1 obsolete)
