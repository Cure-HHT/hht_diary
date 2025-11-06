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
| REQ-p00001 | prd-security.md | Complete Multi-Sponsor Data Separation | 38c1df2e |
| REQ-p00002 | prd-security.md | Multi-Factor Authentication for Staff | d8228946 |
| REQ-p00003 | prd-database.md | Separate Database Per Sponsor | 9be1f491 |
| REQ-p00004 | prd-database.md | Immutable Audit Trail via Event Sourcing | 914a0234 |
| REQ-p00005 | prd-security-RBAC.md | Role-Based Access Control | f74eed3e |
| REQ-p00006 | prd-app.md | Offline-First Data Entry | 56ace32a |
| REQ-p00007 | prd-app.md | Automatic Sponsor Configuration | 65b8e866 |
| REQ-p00008 | prd-architecture-multi-sponsor.md | Single Mobile App for All Sponsors | a9a18658 |
| REQ-p00009 | prd-architecture-multi-sponsor.md | Sponsor-Specific Web Portals | 1ca2a9f3 |
| REQ-p00010 | prd-clinical-trials.md | FDA 21 CFR Part 11 Compliance | 6d0b1c5b |
| REQ-p00011 | prd-clinical-trials.md | ALCOA+ Data Integrity Principles | 79a68145 |
| REQ-p00012 | prd-clinical-trials.md | Clinical Data Retention Requirements | a46e06aa |
| REQ-p00013 | prd-database.md | Complete Data Change History | 2d24be49 |
| REQ-p00014 | prd-security-RBAC.md | Least Privilege Access | 32ca9b47 |
| REQ-p00015 | prd-security-RLS.md | Database-Level Access Enforcement | 1ce0895b |
| REQ-p00016 | prd-security-data-classification.md | Separation of Identity and Clinical Data | 2ef944f3 |
| REQ-p00017 | prd-security-data-classification.md | Data Encryption | 7ab46ab0 |
| REQ-p00018 | prd-architecture-multi-sponsor.md | Multi-Site Support Per Sponsor | ff049149 |
| REQ-p00020 | prd-requirements-management.md | System Validation and Traceability | 11bee00d |
| REQ-p00021 | prd-requirements-management.md | Architecture Decision Documentation | 4543f153 |
| REQ-p00022 | prd-security-RLS.md | Analyst Read-Only Access | 05acef24 |
| REQ-p00023 | prd-security-RLS.md | Sponsor Global Data Access | 17a90175 |
| REQ-p00024 | prd-portal.md | Portal User Roles and Permissions | 2d494361 |
| REQ-p00025 | prd-portal.md | Patient Enrollment Workflow | 5e6b9507 |
| REQ-p00026 | prd-portal.md | Patient Monitoring Dashboard | 4d52eaa3 |
| REQ-p00027 | prd-portal.md | Questionnaire Management | 61f843ad |
| REQ-p00028 | prd-portal.md | Token Revocation and Access Control | c4be450b |
| REQ-p00029 | prd-portal.md | Auditor Dashboard and Data Export | 3501dc5d |
| REQ-p00030 | prd-portal.md | Role-Based Visual Indicators | 3e61467b |
| REQ-p00031 | requirements-format.md | Multi-Sponsor Data Isolation | TBD |
| REQ-p00032 | requirements-format.md | Complete Multi-Sponsor Data Separation | TBD |
| REQ-p00033 | requirements-format.md | Role-Based Access Control | TBD |
| REQ-p00034 | requirements-format.md | Least Privilege Access | TBD |
| REQ-p00035 | prd-security-RLS.md | Patient Data Isolation | a86e189b |
| REQ-p00036 | prd-security-RLS.md | Investigator Site-Scoped Access | 3d449930 |
| REQ-p00037 | prd-security-RLS.md | Investigator Annotation Restrictions | b24dcf67 |
| REQ-p00038 | prd-security-RLS.md | Auditor Compliance Access | 7f2d41c2 |
| REQ-p00039 | prd-security-RLS.md | Administrator Access with Audit Trail | 7c4c5009 |
| REQ-p00040 | prd-security-RLS.md | Event Sourcing State Protection | 63b7f3b4 |
| REQ-p01000 | prd-event-sourcing-system.md | Event Sourcing Client Interface | df83b03b |
| REQ-p01001 | prd-event-sourcing-system.md | Offline Event Queue with Automatic Synchronization | fd7e065d |
| REQ-p01002 | prd-event-sourcing-system.md | Optimistic Concurrency Control | 6a216c36 |
| REQ-p01003 | prd-event-sourcing-system.md | Immutable Event Storage with Audit Trail | 8fdffd02 |
| REQ-p01004 | prd-event-sourcing-system.md | Schema Version Management | 469da09e |
| REQ-p01005 | prd-event-sourcing-system.md | Real-time Event Subscription | ce2fe099 |
| REQ-p01006 | prd-event-sourcing-system.md | Type-Safe Materialized View Queries | ad9bb9d4 |
| REQ-p01007 | prd-event-sourcing-system.md | Error Handling and Diagnostics | 31b5b1b6 |
| REQ-p01008 | prd-event-sourcing-system.md | Event Replay and Time Travel Debugging | 10cb16c5 |
| REQ-p01009 | prd-event-sourcing-system.md | Encryption at Rest for Offline Queue | 72bfae8a |
| REQ-p01010 | prd-event-sourcing-system.md | Multi-tenancy Support | 8c1e3e88 |
| REQ-p01011 | prd-event-sourcing-system.md | Event Transformation and Migration | 445f6d8d |
| REQ-p01012 | prd-event-sourcing-system.md | Batch Event Operations | ac069ec9 |
| REQ-p01013 | prd-event-sourcing-system.md | GraphQL or gRPC Transport Option | d0e1f2b1 |
| REQ-p01014 | prd-event-sourcing-system.md | Observability and Monitoring | 41be67f8 |
| REQ-p01015 | prd-event-sourcing-system.md | Automated Testing Support | aaa3256e |
| REQ-p01016 | prd-event-sourcing-system.md | Performance Benchmarking | 6be5dd5b |
| REQ-p01017 | prd-event-sourcing-system.md | Backward Compatibility Guarantees | ce39c603 |
| REQ-p01018 | prd-event-sourcing-system.md | Security Audit and Compliance | 366174ae |
| REQ-p01019 | prd-event-sourcing-system.md | Phased Implementation | 46cf5cb8 |
| REQ-o00001 | ops-deployment.md | Separate Supabase Projects Per Sponsor | 20a7fa61 |
| REQ-o00002 | ops-deployment.md | Environment-Specific Configuration Management | b58b6034 |
| REQ-o00003 | ops-database-setup.md | Supabase Project Provisioning Per Sponsor | 727c966c |
| REQ-o00004 | ops-database-setup.md | Database Schema Deployment | 118798b8 |
| REQ-o00005 | ops-operations.md | Audit Trail Monitoring | ce6850ec |
| REQ-o00006 | ops-security-authentication.md | MFA Configuration for Staff Accounts | ff126efd |
| REQ-o00007 | ops-security.md | Role-Based Permission Configuration | 211d6d18 |
| REQ-o00008 | ops-operations.md | Backup and Retention Policy | e67b7899 |
| REQ-o00009 | ops-deployment.md | Portal Deployment Per Sponsor | 845789b0 |
| REQ-o00010 | ops-deployment.md | Mobile App Release Process | 7cce6d34 |
| REQ-o00011 | ops-database-setup.md | Multi-Site Data Configuration Per Sponsor | 716b0df6 |
| REQ-o00013 | ops-requirements-management.md | Requirements Format Validation | 1df2a252 |
| REQ-o00014 | ops-requirements-management.md | Top-Down Requirement Cascade | c71f376a |
| REQ-o00015 | ops-requirements-management.md | Documentation Structure Enforcement | 3cc8dbb9 |
| REQ-o00016 | ops-requirements-management.md | Architecture Decision Process | 3261270e |
| REQ-o00017 | ops-requirements-management.md | Version Control Workflow | 914da5a1 |
| REQ-o00018 | obsolete |  | TBD |
| REQ-o00020 | ops-security-RLS.md | Patient Data Isolation Policy Deployment | 82895a52 |
| REQ-o00021 | ops-security-RLS.md | Investigator Site-Scoped Access Policy Deployment | 21fa62f3 |
| REQ-o00022 | ops-security-RLS.md | Investigator Annotation Access Policy Deployment | ff792c68 |
| REQ-o00023 | ops-security-RLS.md | Analyst Read-Only Access Policy Deployment | 965815e2 |
| REQ-o00024 | ops-security-RLS.md | Sponsor Global Access Policy Deployment | 00d15e96 |
| REQ-o00025 | ops-security-RLS.md | Auditor Compliance Access Policy Deployment | eb764225 |
| REQ-o00026 | ops-security-RLS.md | Administrator Access Policy Deployment | b57ab41f |
| REQ-o00027 | ops-security-RLS.md | Event Sourcing State Protection Policy Deployment | 6b080458 |
| REQ-o00041 | ops-infrastructure-as-code.md | Infrastructure as Code for Cloud Resources | ac9be6a0 |
| REQ-o00042 | ops-infrastructure-as-code.md | Infrastructure Change Control | 43a7acdd |
| REQ-o00043 | ops-deployment-automation.md | Automated Deployment Pipeline | e8c189f3 |
| REQ-o00044 | ops-deployment-automation.md | Database Migration Automation | 74a39697 |
| REQ-o00045 | ops-monitoring-observability.md | Error Tracking and Monitoring | b3056896 |
| REQ-o00046 | ops-monitoring-observability.md | Uptime Monitoring | 3022eb23 |
| REQ-o00047 | ops-monitoring-observability.md | Performance Monitoring | 363c9ab1 |
| REQ-o00048 | ops-monitoring-observability.md | Audit Log Monitoring | 5fe0604e |
| REQ-o00049 | ops-artifact-management.md | Artifact Retention and Archival | 2c4f1cc8 |
| REQ-o00050 | ops-artifact-management.md | Environment Parity and Separation | f0f94c5f |
| REQ-o00051 | ops-artifact-management.md | Change Control and Audit Trail | 2ea40b98 |
| REQ-o00052 | ops-cicd.md | CI/CD Pipeline for Requirement Traceability | eb2455e2 |
| REQ-o00053 | ops-cicd.md | Branch Protection Enforcement | 460bdd7c |
| REQ-o00054 | ops-cicd.md | Audit Trail Generation for CI/CD | 44d8603e |
| REQ-o00055 | ops-portal.md | Role-Based Visual Indicator Verification | b8467dc0 |
| REQ-o00056 | requirements-format.md | Separate Supabase Projects Per Sponsor | TBD |
| REQ-d00001 | dev-configuration.md | Sponsor-Specific Configuration Loading | df6f2f7e |
| REQ-d00002 | dev-configuration.md | Pre-Build Configuration Validation | e2f81aed |
| REQ-d00003 | dev-security.md | Supabase Auth Configuration Per Sponsor | 408ef986 |
| REQ-d00004 | dev-app.md | Local-First Data Entry Implementation | 0244d680 |
| REQ-d00005 | dev-app.md | Sponsor Configuration Detection Implementation | 406bc29b |
| REQ-d00006 | dev-app.md | Mobile App Build and Release Process | 95535663 |
| REQ-d00007 | dev-database.md | Database Schema Implementation and Deployment | aff68592 |
| REQ-d00008 | dev-security.md | MFA Enrollment and Verification Implementation | 63e0a046 |
| REQ-d00009 | dev-security.md | Role-Based Permission Enforcement Implementation | 1cad1d18 |
| REQ-d00010 | dev-security.md | Data Encryption Implementation | f3e089f1 |
| REQ-d00011 | dev-database.md | Multi-Site Schema Implementation | 8ffaf0dc |
| REQ-d00012 | requirements-format.md | Environment-Specific Configuration Files | TBD |
| REQ-d00013 | dev-app.md | Application Instance UUID Generation | 595cdce2 |
| REQ-d00014 | dev-requirements-management.md | Requirement Validation Tooling | 1a0c1a8c |
| REQ-d00015 | dev-requirements-management.md | Traceability Matrix Auto-Generation | b6cdf365 |
| REQ-d00016 | dev-requirements-management.md | Code-to-Requirement Linking | ee8c3a1d |
| REQ-d00017 | dev-requirements-management.md | ADR Template and Lifecycle Tooling | 876811a4 |
| REQ-d00018 | dev-requirements-management.md | Git Hook Implementation | 3025b8a0 |
| REQ-d00019 | dev-security-RLS.md | Patient Data Isolation RLS Implementation | 6421baf6 |
| REQ-d00020 | dev-security-RLS.md | Investigator Site-Scoped RLS Implementation | 8d6992de |
| REQ-d00021 | dev-security-RLS.md | Investigator Annotation RLS Implementation | 79c92802 |
| REQ-d00022 | dev-security-RLS.md | Analyst Read-Only RLS Implementation | 71119f2b |
| REQ-d00023 | dev-security-RLS.md | Sponsor Global Access RLS Implementation | 30c879b8 |
| REQ-d00024 | dev-security-RLS.md | Auditor Compliance RLS Implementation | d622043f |
| REQ-d00025 | dev-security-RLS.md | Administrator Break-Glass RLS Implementation | 8b0f32b4 |
| REQ-d00026 | dev-security-RLS.md | Event Sourcing State Protection RLS Implementation | 17e1bdf5 |
| REQ-d00027 | dev-environment.md | Containerized Development Environments | c825be5c |
| REQ-d00028 | dev-portal.md | Portal Frontend Framework | 0156e239 |
| REQ-d00029 | dev-portal.md | Portal UI Design System | 59fdab3b |
| REQ-d00030 | dev-portal.md | Portal Routing and Navigation | d0aee4b0 |
| REQ-d00031 | dev-portal.md | Supabase Authentication Integration | aaa8f76a |
| REQ-d00032 | dev-portal.md | Role-Based Access Control Implementation | a38f0d12 |
| REQ-d00033 | dev-portal.md | Site-Based Data Isolation | e587cff4 |
| REQ-d00034 | dev-portal.md | Login Page Implementation | 0fde167f |
| REQ-d00035 | dev-portal.md | Admin Dashboard Implementation | 2cfb4bc8 |
| REQ-d00036 | dev-portal.md | Create User Dialog Implementation | b26e3867 |
| REQ-d00037 | dev-portal.md | Investigator Dashboard Implementation | d2984949 |
| REQ-d00038 | dev-portal.md | Enroll Patient Dialog Implementation | 45c79415 |
| REQ-d00039 | dev-portal.md | Portal Users Table Schema | fa3c43cd |
| REQ-d00040 | dev-portal.md | User Site Access Table Schema | f00fc7ba |
| REQ-d00041 | dev-portal.md | Patients Table Extensions for Portal | 01a2584c |
| REQ-d00042 | dev-portal.md | Questionnaires Table Schema | 41ab859a |
| REQ-d00043 | dev-portal.md | Netlify Deployment Configuration | fd52ff8d |
| REQ-d00051 | dev-portal.md | Auditor Dashboard Implementation | e4806c99 |
| REQ-d00052 | dev-portal.md | Role-Based Banner Component | af584eb8 |
| REQ-d00053 | dev-requirements-management.md | Development Environment and Tooling Setup | 0be0970a |
| REQ-d00055 | dev-environment.md | Role-Based Environment Separation | 9b60d2ed |
| REQ-d00056 | dev-environment.md | Cross-Platform Development Support | 4c479e07 |
| REQ-d00057 | dev-environment.md | CI/CD Environment Parity | 0a8f4cce |
| REQ-d00058 | dev-environment.md | Secrets Management via Doppler | ddcc7f11 |
| REQ-d00059 | dev-environment.md | Development Tool Specifications | bc384e02 |
| REQ-d00060 | dev-environment.md | VS Code Dev Containers Integration | 47b72611 |
| REQ-d00061 | dev-environment.md | Automated QA Workflow | 42e506bd |
| REQ-d00062 | dev-environment.md | Environment Validation & Change Control | e1652867 |
| REQ-d00063 | dev-environment.md | Shared Workspace and File Exchange | 7f5b28a9 |
| REQ-d00064 | dev-marketplace-json-validation.md | Plugin JSON Validation Tooling | 7f8a2b1e |
| REQ-d00065 | dev-marketplace-path-validation.md | Plugin Path Validation | a3f9c7d2 |
| REQ-d00066 | dev-marketplace-permissions.md | Plugin-Specific Permission Management | b4c8e9a1 |
| REQ-d00067 | dev-marketplace-streamlined-tickets.md | Streamlined Ticket Creation Agent | a377daf9 |
| REQ-d00068 | dev-marketplace-workflow-detection.md | Enhanced Workflow New Work Detection | 6f24ed4a |

---

**Total Requirements:** 159 (62 PRD, 39 Ops, 57 Dev, 1 obsolete)
