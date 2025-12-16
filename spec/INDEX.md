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
| -------------- | ---- | ----- | ---- |
| REQ-d00001 | dev-configuration.md | Sponsor-Specific Configuration Loading | cf4bce54 |
| REQ-d00002 | dev-configuration.md | Pre-Build Configuration Validation | b551cfb0 |
| REQ-d00003 | dev-security.md | Identity Platform Configuration Per Sponsor | 27095b5c |
| REQ-d00004 | dev-app.md | Local-First Data Entry Implementation | 843d0664 |
| REQ-d00005 | dev-app.md | Sponsor Configuration Detection Implementation | 37465932 |
| REQ-d00006 | dev-app.md | Mobile App Build and Release Process | 24bbf429 |
| REQ-d00007 | dev-database.md | Database Schema Implementation and Deployment | 18df4bc0 |
| REQ-d00008 | dev-security.md | MFA Enrollment and Verification Implementation | e179439d |
| REQ-d00009 | dev-security.md | Role-Based Permission Enforcement Implementation | 32cf086a |
| REQ-d00010 | dev-security.md | Data Encryption Implementation | d2d03aa8 |
| REQ-d00011 | dev-database.md | Multi-Site Schema Implementation | bf785d33 |
| REQ-d00013 | dev-app.md | Application Instance UUID Generation | 447e987e |
| REQ-d00014 | dev-requirements-management.md | Requirement Validation Tooling | 2263dc21 |
| REQ-d00015 | dev-requirements-management.md | Traceability Matrix Auto-Generation | 240a754c |
| REQ-d00016 | dev-requirements-management.md | Code-to-Requirement Linking | c857235a |
| REQ-d00017 | dev-requirements-management.md | ADR Template and Lifecycle Tooling | 36997d8f |
| REQ-d00018 | dev-requirements-management.md | Git Hook Implementation | 85098bca |
| REQ-d00019 | dev-security-RLS.md | Patient Data Isolation RLS Implementation | 42079679 |
| REQ-d00020 | dev-security-RLS.md | Investigator Site-Scoped RLS Implementation | 0b438bc8 |
| REQ-d00021 | dev-security-RLS.md | Investigator Annotation RLS Implementation | 024f5863 |
| REQ-d00022 | dev-security-RLS.md | Analyst Read-Only RLS Implementation | ca57ee0e |
| REQ-d00023 | dev-security-RLS.md | Sponsor Global Access RLS Implementation | 57c79cf5 |
| REQ-d00024 | dev-security-RLS.md | Auditor Compliance RLS Implementation | 64a2ff2e |
| REQ-d00025 | dev-security-RLS.md | Administrator Break-Glass RLS Implementation | 4a44951a |
| REQ-d00026 | dev-security-RLS.md | Event Sourcing State Protection RLS Implementation | a665366e |
| REQ-d00027 | dev-environment.md | Containerized Development Environments | 13d56217 |
| REQ-d00028 | dev-portal.md | Portal Frontend Framework | 27f467d3 |
| REQ-d00029 | dev-portal.md | Portal UI Design System | 022edb23 |
| REQ-d00030 | dev-portal.md | Portal Routing and Navigation | 7429dd55 |
| REQ-d00031 | dev-portal.md | Firebase Authentication Integration | 85ebe53e |
| REQ-d00032 | dev-portal.md | Role-Based Access Control Implementation | 5aeb5131 |
| REQ-d00033 | dev-portal.md | Site-Based Data Isolation | 012bc8b5 |
| REQ-d00034 | dev-portal.md | Login Page Implementation | 90e89cec |
| REQ-d00035 | dev-portal.md | Admin Dashboard Implementation | 4d26164b |
| REQ-d00036 | dev-portal.md | Create User Dialog Implementation | a8751a99 |
| REQ-d00037 | dev-portal.md | Investigator Dashboard Implementation | a4946745 |
| REQ-d00038 | dev-portal.md | Enroll Patient Dialog Implementation | 881fec78 |
| REQ-d00039 | dev-portal.md | Portal Users Table Schema | 7f3f554a |
| REQ-d00040 | dev-portal.md | User Site Access Table Schema | 9ce60fc6 |
| REQ-d00041 | dev-portal.md | Patients Table Extensions for Portal | 4662cd2a |
| REQ-d00042 | dev-portal.md | Questionnaires Table Schema | 166c9e74 |
| REQ-d00043 | dev-portal.md | Cloud Run Deployment Configuration | da14653c |
| REQ-d00051 | dev-portal.md | Auditor Dashboard Implementation | 1c02e54a |
| REQ-d00052 | dev-portal.md | Role-Based Banner Component | 40c44430 |
| REQ-d00053 | dev-requirements-management.md | Development Environment and Tooling Setup | 404b139b |
| REQ-d00055 | dev-environment.md | Role-Based Environment Separation | a8ce8ecf |
| REQ-d00056 | dev-environment.md | Cross-Platform Development Support | 223d3f08 |
| REQ-d00057 | dev-environment.md | CI/CD Environment Parity | e58f7423 |
| REQ-d00058 | dev-environment.md | Secrets Management via Doppler | 313110c3 |
| REQ-d00059 | dev-environment.md | Development Tool Specifications | 42b07b9a |
| REQ-d00060 | dev-environment.md | VS Code Dev Containers Integration | 07abf106 |
| REQ-d00061 | dev-environment.md | Automated QA Workflow | fc47d463 |
| REQ-d00062 | dev-environment.md | Environment Validation & Change Control | 5c269c11 |
| REQ-d00063 | dev-environment.md | Shared Workspace and File Exchange | b407570f |
| REQ-d00064 | dev-marketplace-json-validation.md | Plugin JSON Validation Tooling | e325d07b |
| REQ-d00065 | dev-marketplace-path-validation.md | Plugin Path Validation | 770482b7 |
| REQ-d00066 | dev-marketplace-permissions.md | Plugin-Specific Permission Management | 0dd52eec |
| REQ-d00067 | dev-marketplace-streamlined-tickets.md | Streamlined Ticket Creation Agent | 335415e6 |
| REQ-d00068 | dev-marketplace-workflow-detection.md | Enhanced Workflow New Work Detection | f5f3570e |
| REQ-d00069 | dev-marketplace-devcontainer-detection.md | Dev Container Detection and Warnings | 18471ae1 |
| REQ-d00070 | dev-CDISC.md | CDASH Field Mapping Implementation | 7ff9716c |
| REQ-d00071 | dev-CDISC.md | SDTM Domain Transformation Implementation | 1286bfd8 |
| REQ-d00072 | dev-CDISC.md | ODM-XML Export Implementation | f1b48f69 |
| REQ-d00073 | dev-CDISC.md | Define-XML Metadata Generation | 4a4d28cd |
| REQ-d00074 | dev-CDISC.md | CDISC Controlled Terminology Implementation | 772bf977 |
| REQ-d00075 | dev-CDISC.md | EDC Data Transformation Specification | cd5b72f1 |
| REQ-d00076 | dev-CDISC.md | Clinical Data Export Formats | 718bd3af |
| REQ-d00077 | dev-diary-web.md | Web Diary Frontend Framework | c59bc3ef |
| REQ-d00078 | dev-diary-web.md | HHT Diary Auth Service | 774a18da |
| REQ-d00079 | dev-diary-web.md | Linking Code Pattern Matching | da7b9bb0 |
| REQ-d00080 | dev-diary-web.md | Web Session Management Implementation | 44ade86c |
| REQ-d00081 | dev-diary-web.md | User Document Schema | cde85fd6 |
| REQ-d00082 | dev-diary-web.md | Password Hashing Implementation | 05136a5d |
| REQ-d00083 | dev-diary-web.md | Browser Storage Clearing | d5857410 |
| REQ-d00084 | dev-diary-web.md | Sponsor Configuration Loading | 5a79a42d |
| REQ-o00001 | ops-deployment.md | Separate GCP Projects Per Sponsor | 6d281a2e |
| REQ-o00002 | ops-deployment.md | Environment-Specific Configuration Management | c6ed3379 |
| REQ-o00003 | ops-database-setup.md | GCP Project Provisioning Per Sponsor | 5c8ec50e |
| REQ-o00004 | ops-database-setup.md | Database Schema Deployment | b9f6a0b5 |
| REQ-o00005 | ops-operations.md | Audit Trail Monitoring | f48b8b6b |
| REQ-o00006 | ops-security-authentication.md | MFA Configuration for Staff Accounts | b8739ec1 |
| REQ-o00007 | ops-security.md | Role-Based Permission Configuration | d77cbde8 |
| REQ-o00008 | ops-operations.md | Backup and Retention Policy | 48f424bd |
| REQ-o00009 | ops-deployment.md | Portal Deployment Per Sponsor | d0b93523 |
| REQ-o00010 | ops-deployment.md | Mobile App Release Process | 6985c040 |
| REQ-o00011 | ops-database-setup.md | Multi-Site Data Configuration Per Sponsor | 2af51c8b |
| REQ-o00013 | ops-requirements-management.md | Requirements Format Validation | 2743e711 |
| REQ-o00014 | ops-requirements-management.md | Top-Down Requirement Cascade | d36fc1fb |
| REQ-o00015 | ops-requirements-management.md | Documentation Structure Enforcement | 426b1961 |
| REQ-o00016 | ops-requirements-management.md | Architecture Decision Process | 5efd9802 |
| REQ-o00017 | ops-requirements-management.md | Version Control Workflow | c8076d8e |
| REQ-o00020 | ops-security-RLS.md | Patient Data Isolation Policy Deployment | 055dc1e6 |
| REQ-o00021 | ops-security-RLS.md | Investigator Site-Scoped Access Policy Deployment | 38196c93 |
| REQ-o00022 | ops-security-RLS.md | Investigator Annotation Access Policy Deployment | d428ead1 |
| REQ-o00023 | ops-security-RLS.md | Analyst Read-Only Access Policy Deployment | 346c5484 |
| REQ-o00024 | ops-security-RLS.md | Sponsor Global Access Policy Deployment | 1a54172d |
| REQ-o00025 | ops-security-RLS.md | Auditor Compliance Access Policy Deployment | 7778ee1d |
| REQ-o00026 | ops-security-RLS.md | Administrator Access Policy Deployment | bd1671e2 |
| REQ-o00027 | ops-security-RLS.md | Event Sourcing State Protection Policy Deployment | a2326ae4 |
| REQ-o00041 | ops-infrastructure-as-code.md | Infrastructure as Code for Cloud Resources | e42cc806 |
| REQ-o00042 | ops-infrastructure-as-code.md | Infrastructure Change Control | 8b9ee3b1 |
| REQ-o00043 | ops-deployment-automation.md | Automated Deployment Pipeline | 96f57f47 |
| REQ-o00044 | ops-deployment-automation.md | Database Migration Automation | ba7cbea5 |
| REQ-o00045 | ops-monitoring-observability.md | Error Tracking and Monitoring | 2f30130f |
| REQ-o00046 | ops-monitoring-observability.md | Uptime Monitoring | 8b18418e |
| REQ-o00047 | ops-monitoring-observability.md | Performance Monitoring | aace8eb6 |
| REQ-o00048 | ops-monitoring-observability.md | Audit Log Monitoring | 354985e7 |
| REQ-o00049 | ops-artifact-management.md | Artifact Retention and Archival | 2ad38e10 |
| REQ-o00050 | ops-artifact-management.md | Environment Parity and Separation | 7ccde026 |
| REQ-o00051 | ops-artifact-management.md | Change Control and Audit Trail | f9d8ca86 |
| REQ-o00052 | ops-cicd.md | CI/CD Pipeline for Requirement Traceability | 150d2b29 |
| REQ-o00053 | ops-cicd.md | Branch Protection Enforcement | d0584e9a |
| REQ-o00054 | ops-cicd.md | Audit Trail Generation for CI/CD | 7da5e2e7 |
| REQ-o00055 | ops-portal.md | Role-Based Visual Indicator Verification | b02eb8c1 |
| REQ-o00056 | ops-SLA.md | SLO Definition and Tracking | 5efae38e |
| REQ-o00057 | ops-SLA.md | Automated Uptime Monitoring | 29c323db |
| REQ-o00058 | ops-SLA.md | On-Call Automation | 545e519a |
| REQ-o00059 | ops-SLA.md | Automated Status Page | 6ef867f8 |
| REQ-o00060 | ops-SLA.md | SLA Reporting Automation | 037b0946 |
| REQ-o00061 | ops-SLA.md | Incident Classification Automation | 5e96a7aa |
| REQ-o00062 | ops-SLA.md | RCA and CAPA Workflow | ecec7aed |
| REQ-o00063 | ops-SLA.md | Error Budget Alerting | 60d8b564 |
| REQ-o00064 | ops-SLA.md | Maintenance Window Management | 3732f8ca |
| REQ-p00001 | prd-security.md | Complete Multi-Sponsor Data Separation | e82cbd48 |
| REQ-p00002 | prd-security.md | Multi-Factor Authentication for Staff | 4e8e0638 |
| REQ-p00003 | prd-database.md | Separate Database Per Sponsor | 6a207b1a |
| REQ-p00004 | prd-database.md | Immutable Audit Trail via Event Sourcing | 0c0b0807 |
| REQ-p00005 | prd-security-RBAC.md | Role-Based Access Control | 692bc7bd |
| REQ-p00006 | prd-diary-app.md | Offline-First Data Entry | c5ff6bf6 |
| REQ-p00007 | prd-diary-app.md | Automatic Sponsor Configuration | b90eb7ab |
| REQ-p00008 | prd-architecture-multi-sponsor.md | Single Mobile App for All Sponsors | dd4bbaaa |
| REQ-p00009 | prd-architecture-multi-sponsor.md | Sponsor-Specific Web Portals | f1ff8218 |
| REQ-p00010 | prd-clinical-trials.md | FDA 21 CFR Part 11 Compliance | 62500780 |
| REQ-p00011 | prd-clinical-trials.md | ALCOA+ Data Integrity Principles | 05c9dc79 |
| REQ-p00012 | prd-clinical-trials.md | Clinical Data Retention Requirements | b3332065 |
| REQ-p00013 | prd-database.md | Complete Data Change History | ab598860 |
| REQ-p00014 | prd-security-RBAC.md | Least Privilege Access | 874e9922 |
| REQ-p00015 | prd-security-RLS.md | Database-Level Access Enforcement | 442efc99 |
| REQ-p00016 | prd-security-data-classification.md | Separation of Identity and Clinical Data | d1d5e6d7 |
| REQ-p00017 | prd-security-data-classification.md | Data Encryption | 0b519855 |
| REQ-p00018 | prd-architecture-multi-sponsor.md | Multi-Site Support Per Sponsor | b3de8bbb |
| REQ-p00020 | prd-requirements-management.md | System Validation and Traceability | 1d358edd |
| REQ-p00021 | prd-requirements-management.md | Architecture Decision Documentation | 4cc93241 |
| REQ-p00022 | prd-security-RLS.md | Analyst Read-Only Access | 0b40a159 |
| REQ-p00023 | prd-security-RLS.md | Sponsor Global Data Access | 90a0bb41 |
| REQ-p00024 | prd-portal.md | Portal User Roles and Permissions | cf1917cb |
| REQ-p00025 | prd-portal.md | Patient Enrollment Workflow | 46eedac4 |
| REQ-p00026 | prd-portal.md | Patient Monitoring Dashboard | 256f8363 |
| REQ-p00027 | prd-portal.md | Questionnaire Management | 72da93bc |
| REQ-p00028 | prd-portal.md | Token Revocation and Access Control | 2edf0218 |
| REQ-p00029 | prd-portal.md | Auditor Dashboard and Data Export | 5a77e3bb |
| REQ-p00030 | prd-portal.md | Role-Based Visual Indicators | 59059266 |
| REQ-p00035 | prd-security-RLS.md | Patient Data Isolation | 1b9c3406 |
| REQ-p00036 | prd-security-RLS.md | Investigator Site-Scoped Access | e834fc2e |
| REQ-p00037 | prd-security-RLS.md | Investigator Annotation Restrictions | a5f2e9d6 |
| REQ-p00038 | prd-security-RLS.md | Auditor Compliance Access | 6324bf04 |
| REQ-p00039 | prd-security-RLS.md | Administrator Access with Audit Trail | e8a3d480 |
| REQ-p00040 | prd-security-RLS.md | Event Sourcing State Protection | 0e94f5cf |
| REQ-p00041 | prd-standards.md | CDISC Standards Compliance | bd86de7e |
| REQ-p00042 | prd-epistaxis-terminology.md | HHT Epistaxis Data Capture Standard | e2501d13 |
| REQ-p00043 | prd-diary-app.md | Clinical Diary Mobile Application | 5062a707 |
| REQ-p00044 | prd-system.md | Clinical Trial Diary Platform | 0e8a8d5b |
| REQ-p00045 | prd-portal.md | Sponsor Portal Application | 0a9ccb54 |
| REQ-p00046 | prd-database.md | Clinical Data Storage System | d8a1fdf2 |
| REQ-p00047 | prd-backup.md | Data Backup and Archival | 4e13d1c2 |
| REQ-p00048 | prd-devops.md | Platform Operations and Monitoring | b06492a0 |
| REQ-p00049 | prd-services.md | Ancillary Platform Services | 8ae1bd30 |
| REQ-p00050 | prd-diary-app.md | Temporal Entry Validation | 9f0a0d36 |
| REQ-p01000 | prd-event-sourcing-system.md | Event Sourcing Client Interface | c3f9c7d2 |
| REQ-p01001 | prd-event-sourcing-system.md | Offline Event Queue with Automatic Synchronization | 9a8601c2 |
| REQ-p01002 | prd-event-sourcing-system.md | Optimistic Concurrency Control | 21a2772e |
| REQ-p01003 | prd-event-sourcing-system.md | Immutable Event Storage with Audit Trail | 11944e76 |
| REQ-p01004 | prd-event-sourcing-system.md | Schema Version Management | 569e1667 |
| REQ-p01005 | prd-event-sourcing-system.md | Real-time Event Subscription | 8a3eb6c8 |
| REQ-p01006 | prd-event-sourcing-system.md | Type-Safe Materialized View Queries | 4a0e2442 |
| REQ-p01007 | prd-event-sourcing-system.md | Error Handling and Diagnostics | fb15ef77 |
| REQ-p01008 | prd-event-sourcing-system.md | Event Replay and Time Travel Debugging | b18fe45c |
| REQ-p01009 | prd-event-sourcing-system.md | Encryption at Rest for Offline Queue | b0d10dbb |
| REQ-p01010 | prd-event-sourcing-system.md | Multi-tenancy Support | 08077819 |
| REQ-p01011 | prd-event-sourcing-system.md | Event Transformation and Migration | b1e42685 |
| REQ-p01012 | prd-event-sourcing-system.md | Batch Event Operations | ab8bead4 |
| REQ-p01013 | prd-event-sourcing-system.md | GraphQL or gRPC Transport Option | 2aedb731 |
| REQ-p01014 | prd-event-sourcing-system.md | Observability and Monitoring | 884b4ace |
| REQ-p01015 | prd-event-sourcing-system.md | Automated Testing Support | ca52af16 |
| REQ-p01016 | prd-event-sourcing-system.md | Performance Benchmarking | 1b14b575 |
| REQ-p01017 | prd-event-sourcing-system.md | Backward Compatibility Guarantees | 0af743bf |
| REQ-p01018 | prd-event-sourcing-system.md | Security Audit and Compliance | 6a021418 |
| REQ-p01019 | prd-event-sourcing-system.md | Phased Implementation | d60453bf |
| REQ-p01020 | prd-glossary.md | Privacy Policy and Regulatory Compliance Documentation | 1ff593de |
| REQ-p01021 | prd-SLA.md | Service Availability Commitment | f2662639 |
| REQ-p01022 | prd-SLA.md | Incident Severity Classification | 9eb12926 |
| REQ-p01023 | prd-SLA.md | Incident Response Times | 39e43b49 |
| REQ-p01024 | prd-SLA.md | Disaster Recovery Objectives | b0de06c9 |
| REQ-p01025 | prd-evidence-records.md | Third-Party Timestamp Attestation Capability | 5aef2ec0 |
| REQ-p01026 | prd-evidence-records.md | Bitcoin-Based Timestamp Implementation | 634732d7 |
| REQ-p01027 | prd-evidence-records.md | Timestamp Verification Interface | 7582f435 |
| REQ-p01028 | prd-evidence-records.md | Timestamp Proof Archival | 64a9c3ec |
| REQ-p01029 | prd-evidence-records.md | Device Fingerprinting | 57a2d038 |
| REQ-p01030 | prd-evidence-records.md | Patient Authentication for Data Attribution | e5dd3d06 |
| REQ-p01031 | prd-evidence-records.md | Optional Geolocation Tagging | 034c9479 |
| REQ-p01032 | prd-evidence-records.md | Hashed Email Identity Verification | 769f35e0 |
| REQ-p01033 | prd-SLA.md | Customer Incident Notification | 39a8a25c |
| REQ-p01034 | prd-SLA.md | Root Cause Analysis | 145a7df7 |
| REQ-p01035 | prd-SLA.md | Corrective and Preventive Action | c731bb83 |
| REQ-p01036 | prd-SLA.md | Data Recovery Guarantee | accdee07 |
| REQ-p01037 | prd-SLA.md | Chronic Failure Escalation | c3a07afa |
| REQ-p01038 | prd-SLA.md | Regulatory Event Support | fec701fa |
| REQ-p01039 | prd-diary-app.md | Diary Start Day Definition | ef7a7921 |
| REQ-p01040 | prd-diary-app.md | Calendar Visual Indicators for Entry Status | 75dc8f26 |
| REQ-p01041 | prd-system.md | Open Source Licensing | 8c10dd61 |
| REQ-p01042 | prd-diary-web.md | Web Diary Application | f663bc1b |
| REQ-p01043 | prd-diary-web.md | Web Diary Authentication via Linking Code | 31d36807 |
| REQ-p01044 | prd-diary-web.md | Web Diary Session Management | cdc397b5 |
| REQ-p01045 | prd-diary-web.md | Web Diary Privacy Protection | 3185ed95 |
| REQ-p01046 | prd-diary-web.md | Web Diary Account Creation | 915de272 |
| REQ-p01047 | prd-diary-web.md | Web Diary User Profile | 654d8be8 |
| REQ-p01048 | prd-diary-web.md | Web Diary Login Interface | 1d24c597 |
| REQ-p01049 | prd-diary-web.md | Web Diary Lost Credential Recovery | 934b5e7f |
| REQ-p01050 | prd-event-sourcing-system.md | Event Type Registry | 19386e10 |
| REQ-p01051 | prd-event-sourcing-system.md | Questionnaire Versioning Model | 32f2c5a2 |
| REQ-p01052 | prd-event-sourcing-system.md | Questionnaire Localization and Translation Tracking | 591b34e9 |
| REQ-p01053 | prd-event-sourcing-system.md | Sponsor Questionnaire Eligibility Configuration | a702fcec |

---

**Total Requirements**: 222

**Generated by**: `python3 tools/requirements/regenerate-index.py`
