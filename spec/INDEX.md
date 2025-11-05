# Requirements Index

This file provides a complete index of all formal requirements across the spec/ directory. Each requirement is listed with its ID, containing file, and title.

**Maintenance Rules:**
- When adding a new requirement, add it to this index with the correct file reference
- When moving a requirement to a different file, update the file reference
- When removing/deprecating a requirement, change its file reference to `obsolete` and leave description blank
- Keep requirements sorted by ID (REQ-p, REQ-o, REQ-d in ascending numerical order)

---

| Requirement ID | File | Title |
|----------------|------|-------|
| REQ-p00001 | prd-security.md | Complete Multi-Sponsor Data Separation |
| REQ-p00002 | prd-security.md | Multi-Factor Authentication for Staff |
| REQ-p00003 | prd-database.md | Separate Database Per Sponsor |
| REQ-p00004 | prd-database.md | Immutable Audit Trail via Event Sourcing |
| REQ-p00005 | prd-security-RBAC.md | Role-Based Access Control |
| REQ-p00006 | prd-app.md | Offline-First Data Entry |
| REQ-p00007 | prd-app.md | Automatic Sponsor Configuration |
| REQ-p00008 | prd-architecture-multi-sponsor.md | Single Mobile App for All Sponsors |
| REQ-p00009 | prd-architecture-multi-sponsor.md | Sponsor-Specific Web Portals |
| REQ-p00010 | prd-clinical-trials.md | FDA 21 CFR Part 11 Compliance |
| REQ-p00011 | prd-clinical-trials.md | ALCOA+ Data Integrity Principles |
| REQ-p00012 | prd-clinical-trials.md | Clinical Data Retention Requirements |
| REQ-p00013 | prd-database.md | Complete Data Change History |
| REQ-p00014 | prd-security-RBAC.md | Least Privilege Access |
| REQ-p00015 | prd-security-RLS.md | Database-Level Access Enforcement |
| REQ-p00016 | prd-security-data-classification.md | Separation of Identity and Clinical Data |
| REQ-p00017 | prd-security-data-classification.md | Data Encryption |
| REQ-p00018 | prd-architecture-multi-sponsor.md | Multi-Site Support Per Sponsor |
| REQ-p00020 | prd-requirements-management.md | System Validation and Traceability |
| REQ-p00021 | prd-requirements-management.md | Architecture Decision Documentation |
| REQ-p00022 | prd-security-RLS.md | Analyst Read-Only Access |
| REQ-p00023 | prd-security-RLS.md | Sponsor Global Data Access |
| REQ-p00024 | prd-portal.md | Portal User Roles and Permissions |
| REQ-p00025 | prd-portal.md | Patient Enrollment Workflow |
| REQ-p00026 | prd-portal.md | Patient Monitoring Dashboard |
| REQ-p00027 | prd-portal.md | Questionnaire Management |
| REQ-p00028 | prd-portal.md | Token Revocation and Access Control |
| REQ-p00029 | prd-portal.md | Auditor Dashboard and Data Export |
| REQ-p00030 | prd-portal.md | Role-Based Visual Indicators |
| REQ-p00031 | requirements-format.md | Multi-Sponsor Data Isolation |
| REQ-p00032 | requirements-format.md | Complete Multi-Sponsor Data Separation |
| REQ-p00033 | requirements-format.md | Role-Based Access Control |
| REQ-p00034 | requirements-format.md | Least Privilege Access |
| REQ-p00035 | prd-security-RLS.md | Patient Data Isolation |
| REQ-p00036 | prd-security-RLS.md | Investigator Site-Scoped Access |
| REQ-p00037 | prd-security-RLS.md | Investigator Annotation Restrictions |
| REQ-p00038 | prd-security-RLS.md | Auditor Compliance Access |
| REQ-p00039 | prd-security-RLS.md | Administrator Access with Audit Trail |
| REQ-p00040 | prd-security-RLS.md | Event Sourcing State Protection |
| REQ-p01000 | prd-event-sourcing-system.md | Event Sourcing Client Interface |
| REQ-p01001 | prd-event-sourcing-system.md | Offline Event Queue with Automatic Synchronization |
| REQ-p01002 | prd-event-sourcing-system.md | Optimistic Concurrency Control |
| REQ-p01003 | prd-event-sourcing-system.md | Immutable Event Storage with Audit Trail |
| REQ-p01004 | prd-event-sourcing-system.md | Schema Version Management |
| REQ-p01005 | prd-event-sourcing-system.md | Real-time Event Subscription |
| REQ-p01006 | prd-event-sourcing-system.md | Type-Safe Materialized View Queries |
| REQ-p01007 | prd-event-sourcing-system.md | Error Handling and Diagnostics |
| REQ-p01008 | prd-event-sourcing-system.md | Event Replay and Time Travel Debugging |
| REQ-p01009 | prd-event-sourcing-system.md | Encryption at Rest for Offline Queue |
| REQ-p01010 | prd-event-sourcing-system.md | Multi-tenancy Support |
| REQ-p01011 | prd-event-sourcing-system.md | Event Transformation and Migration |
| REQ-p01012 | prd-event-sourcing-system.md | Batch Event Operations |
| REQ-p01013 | prd-event-sourcing-system.md | GraphQL or gRPC Transport Option |
| REQ-p01014 | prd-event-sourcing-system.md | Observability and Monitoring |
| REQ-p01015 | prd-event-sourcing-system.md | Automated Testing Support |
| REQ-p01016 | prd-event-sourcing-system.md | Performance Benchmarking |
| REQ-p01017 | prd-event-sourcing-system.md | Backward Compatibility Guarantees |
| REQ-p01018 | prd-event-sourcing-system.md | Security Audit and Compliance |
| REQ-p01019 | prd-event-sourcing-system.md | Phased Implementation |
| REQ-o00001 | ops-deployment.md | Separate Supabase Projects Per Sponsor |
| REQ-o00002 | ops-deployment.md | Environment-Specific Configuration Management |
| REQ-o00003 | ops-database-setup.md | Supabase Project Provisioning Per Sponsor |
| REQ-o00004 | ops-database-setup.md | Database Schema Deployment |
| REQ-o00005 | ops-operations.md | Audit Trail Monitoring |
| REQ-o00006 | ops-security-authentication.md | MFA Configuration for Staff Accounts |
| REQ-o00007 | ops-security.md | Role-Based Permission Configuration |
| REQ-o00008 | ops-operations.md | Backup and Retention Policy |
| REQ-o00009 | ops-deployment.md | Portal Deployment Per Sponsor |
| REQ-o00010 | ops-deployment.md | Mobile App Release Process |
| REQ-o00011 | ops-database-setup.md | Multi-Site Data Configuration Per Sponsor |
| REQ-o00013 | ops-requirements-management.md | Requirements Format Validation |
| REQ-o00014 | ops-requirements-management.md | Top-Down Requirement Cascade |
| REQ-o00015 | ops-requirements-management.md | Documentation Structure Enforcement |
| REQ-o00016 | ops-requirements-management.md | Architecture Decision Process |
| REQ-o00017 | ops-requirements-management.md | Version Control Workflow |
| REQ-o00018 | obsolete | |
| REQ-o00020 | ops-security-RLS.md | Patient Data Isolation Policy Deployment |
| REQ-o00021 | ops-security-RLS.md | Investigator Site-Scoped Access Policy Deployment |
| REQ-o00022 | ops-security-RLS.md | Investigator Annotation Access Policy Deployment |
| REQ-o00023 | ops-security-RLS.md | Analyst Read-Only Access Policy Deployment |
| REQ-o00024 | ops-security-RLS.md | Sponsor Global Access Policy Deployment |
| REQ-o00025 | ops-security-RLS.md | Auditor Compliance Access Policy Deployment |
| REQ-o00026 | ops-security-RLS.md | Administrator Access Policy Deployment |
| REQ-o00027 | ops-security-RLS.md | Event Sourcing State Protection Policy Deployment |
| REQ-o00041 | ops-infrastructure-as-code.md | Infrastructure as Code for Cloud Resources |
| REQ-o00042 | ops-infrastructure-as-code.md | Infrastructure Change Control |
| REQ-o00043 | ops-deployment-automation.md | Automated Deployment Pipeline |
| REQ-o00044 | ops-deployment-automation.md | Database Migration Automation |
| REQ-o00045 | ops-monitoring-observability.md | Error Tracking and Monitoring |
| REQ-o00046 | ops-monitoring-observability.md | Uptime Monitoring |
| REQ-o00047 | ops-monitoring-observability.md | Performance Monitoring |
| REQ-o00048 | ops-monitoring-observability.md | Audit Log Monitoring |
| REQ-o00049 | ops-artifact-management.md | Artifact Retention and Archival |
| REQ-o00050 | ops-artifact-management.md | Environment Parity and Separation |
| REQ-o00051 | ops-artifact-management.md | Change Control and Audit Trail |
| REQ-o00052 | ops-cicd.md | CI/CD Pipeline for Requirement Traceability |
| REQ-o00053 | ops-cicd.md | Branch Protection Enforcement |
| REQ-o00054 | ops-cicd.md | Audit Trail Generation for CI/CD |
| REQ-o00055 | ops-portal.md | Role-Based Visual Indicator Verification |
| REQ-o00056 | requirements-format.md | Separate Supabase Projects Per Sponsor |
| REQ-d00001 | dev-configuration.md | Sponsor-Specific Configuration Loading |
| REQ-d00002 | dev-configuration.md | Pre-Build Configuration Validation |
| REQ-d00003 | dev-security.md | Supabase Auth Configuration Per Sponsor |
| REQ-d00004 | dev-app.md | Local-First Data Entry Implementation |
| REQ-d00005 | dev-app.md | Sponsor Configuration Detection Implementation |
| REQ-d00006 | dev-app.md | Mobile App Build and Release Process |
| REQ-d00007 | dev-database.md | Database Schema Implementation and Deployment |
| REQ-d00008 | dev-security.md | MFA Enrollment and Verification Implementation |
| REQ-d00009 | dev-security.md | Role-Based Permission Enforcement Implementation |
| REQ-d00010 | dev-security.md | Data Encryption Implementation |
| REQ-d00011 | dev-database.md | Multi-Site Schema Implementation |
| REQ-d00012 | requirements-format.md | Environment-Specific Configuration Files |
| REQ-d00013 | dev-app.md | Application Instance UUID Generation |
| REQ-d00014 | dev-requirements-management.md | Requirement Validation Tooling |
| REQ-d00015 | dev-requirements-management.md | Traceability Matrix Auto-Generation |
| REQ-d00016 | dev-requirements-management.md | Code-to-Requirement Linking |
| REQ-d00017 | dev-requirements-management.md | ADR Template and Lifecycle Tooling |
| REQ-d00018 | dev-requirements-management.md | Git Hook Implementation |
| REQ-d00019 | dev-security-RLS.md | Patient Data Isolation RLS Implementation |
| REQ-d00020 | dev-security-RLS.md | Investigator Site-Scoped RLS Implementation |
| REQ-d00021 | dev-security-RLS.md | Investigator Annotation RLS Implementation |
| REQ-d00022 | dev-security-RLS.md | Analyst Read-Only RLS Implementation |
| REQ-d00023 | dev-security-RLS.md | Sponsor Global Access RLS Implementation |
| REQ-d00024 | dev-security-RLS.md | Auditor Compliance RLS Implementation |
| REQ-d00025 | dev-security-RLS.md | Administrator Break-Glass RLS Implementation |
| REQ-d00026 | dev-security-RLS.md | Event Sourcing State Protection RLS Implementation |
| REQ-d00027 | dev-environment.md | Containerized Development Environments |
| REQ-d00028 | dev-portal.md | Portal Frontend Framework |
| REQ-d00029 | dev-portal.md | Portal UI Design System |
| REQ-d00030 | dev-portal.md | Portal Routing and Navigation |
| REQ-d00031 | dev-portal.md | Supabase Authentication Integration |
| REQ-d00032 | dev-portal.md | Role-Based Access Control Implementation |
| REQ-d00033 | dev-portal.md | Site-Based Data Isolation |
| REQ-d00034 | dev-portal.md | Login Page Implementation |
| REQ-d00035 | dev-portal.md | Admin Dashboard Implementation |
| REQ-d00036 | dev-portal.md | Create User Dialog Implementation |
| REQ-d00037 | dev-portal.md | Investigator Dashboard Implementation |
| REQ-d00038 | dev-portal.md | Enroll Patient Dialog Implementation |
| REQ-d00039 | dev-portal.md | Portal Users Table Schema |
| REQ-d00040 | dev-portal.md | User Site Access Table Schema |
| REQ-d00041 | dev-portal.md | Patients Table Extensions for Portal |
| REQ-d00042 | dev-portal.md | Questionnaires Table Schema |
| REQ-d00043 | dev-portal.md | Netlify Deployment Configuration |
| REQ-d00051 | dev-portal.md | Auditor Dashboard Implementation |
| REQ-d00052 | dev-portal.md | Role-Based Banner Component |
| REQ-d00053 | dev-requirements-management.md | Development Environment and Tooling Setup |
| REQ-d00055 | dev-environment.md | Role-Based Environment Separation |
| REQ-d00056 | dev-environment.md | Cross-Platform Development Support |
| REQ-d00057 | dev-environment.md | CI/CD Environment Parity |
| REQ-d00058 | dev-environment.md | Secrets Management via Doppler |
| REQ-d00059 | dev-environment.md | Development Tool Specifications |
| REQ-d00060 | dev-environment.md | VS Code Dev Containers Integration |
| REQ-d00061 | dev-environment.md | Automated QA Workflow |
| REQ-d00062 | dev-environment.md | Environment Validation & Change Control |
| REQ-d00063 | dev-environment.md | Shared Workspace and File Exchange |

---

**Total Requirements:** 154 (62 PRD, 39 Ops, 52 Dev, 1 obsolete)
