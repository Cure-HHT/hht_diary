# Requirements Index

This file provides a complete index of all requirements.

## Product Requirements (PRD)

| ID | Title | File | Hash |
| --- | --- | --- | --- |
| REQ-p00001 | Complete Multi-Sponsor Data Separation | prd-security.md | 081d1dc6 |
| REQ-p00002 | Multi-Factor Authentication for Staff | prd-security.md | 0c06ec29 |
| REQ-p00003 | Separate Database Per Sponsor | prd-database.md | bfb45afa |
| REQ-p00004 | Immutable Audit Trail via Event Sourcing | prd-database.md | 3be570a3 |
| REQ-p00005 | Role-Based Access Control | prd-security-RBAC.md | 83122106 |
| REQ-p00006 | Offline-First Data Entry | prd-diary-app.md | 438d5f2d |
| REQ-p00007 | Automatic Sponsor Configuration | prd-diary-app.md | 5498f554 |
| REQ-p00008 | Single Mobile App for All Sponsors | prd-architecture-multi-sponsor.md | 6be0ee0f |
| REQ-p00009 | Sponsor-Specific Portals | prd-architecture-multi-sponsor.md | f3149879 |
| REQ-p00010 | FDA 21 CFR Part 11 Compliance | prd-clinical-trials.md | 192ec8c7 |
| REQ-p00011 | ALCOA+ Data Integrity Principles | prd-clinical-trials.md | 75efc558 |
| REQ-p00012 | Clinical Data Retention Requirements | prd-clinical-trials.md | 1e94b089 |
| REQ-p00013 | Complete Data Change History | prd-database.md | 173331a9 |
| REQ-p00014 | Least Privilege Access | prd-security-RBAC.md | 84b123a2 |
| REQ-p00015 | Database-Level Access Enforcement | prd-security-RLS.md | 5090c64b |
| REQ-p00016 | Separation of Identity and Clinical Data | prd-security-data-classification.md | ce95a5e6 |
| REQ-p00017 | Data Encryption | prd-security-data-classification.md | 2ca02635 |
| REQ-p00018 | Multi-Site Support Per Sponsor | prd-architecture-multi-sponsor.md | 68512c64 |
| REQ-p00020 | System Validation and Traceability | prd-requirements-management.md | 59dad31e |
| REQ-p00021 | Architecture Decision Documentation | prd-requirements-management.md | a6a58cac |
| REQ-p00022 | Analyst Read-Only Access | prd-security-RLS.md | e248e5a4 |
| REQ-p00023 | Sponsor Global Data Access | prd-security-RLS.md | d23eae40 |
| REQ-p00035 | Patient Data Isolation | prd-security-RLS.md | 78940b2e |
| REQ-p00036 | Investigator Site-Scoped Access | prd-security-RLS.md | 3610fabe |
| REQ-p00037 | Investigator Annotation Restrictions | prd-security-RLS.md | b63fd139 |
| REQ-p00038 | Auditor Compliance Access | prd-security-RLS.md | a7649da6 |
| REQ-p00039 | Administrator Access with Audit Trail | prd-security-RLS.md | 4672a9dc |
| REQ-p00040 | Event Sourcing State Protection | prd-security-RLS.md | 06025d8a |
| REQ-p00042 | HHT Epistaxis Data Capture Standard | prd-epistaxis-terminology.md | f0a37c7e |
| REQ-p00043 | Diary Mobile Application | prd-diary-app.md | 85554ec9 |
| REQ-p00044 | Clinical Trial Compliant Diary Platform | prd-system.md | a72852cf |
| REQ-p00046 | Clinical Data Storage System | prd-database.md | 2e588136 |
| REQ-p00047 | Data Backup and Archival | prd-backup.md | cf938097 |
| REQ-p00048 | Platform Operations and Monitoring | prd-devops.md | 54f66258 |
| REQ-p00049 | Ancillary Platform Services | prd-services.md | cb9bb123 |
| REQ-p00050 | Temporal Entry Validation | prd-diary-app.md | 0dff6cc4 |
| REQ-p01000 | Event Sourcing Client Interface | prd-event-sourcing-system.md | 750e5c35 |
| REQ-p01001 | Offline Event Queue with Automatic Synchronization | prd-event-sourcing-system.md | 35094804 |
| REQ-p01002 | Optimistic Concurrency Control | prd-event-sourcing-system.md | 994871a2 |
| REQ-p01003 | Immutable Event Storage with Audit Trail | prd-event-sourcing-system.md | 29a2c2ac |
| REQ-p01004 | Schema Version Management | prd-event-sourcing-system.md | 102eb5a1 |
| REQ-p01005 | Real-time Event Subscription | prd-event-sourcing-system.md | 58430215 |
| REQ-p01006 | Type-Safe Materialized View Queries | prd-event-sourcing-system.md | 13f605de |
| REQ-p01007 | Error Handling and Diagnostics | prd-event-sourcing-system.md | baaaa244 |
| REQ-p01008 | Event Replay and Time Travel Debugging | prd-event-sourcing-system.md | 5762fc28 |
| REQ-p01009 | Encryption at Rest for Offline Queue | prd-event-sourcing-system.md | 740eb955 |
| REQ-p01010 | Multi-tenancy Support | prd-event-sourcing-system.md | 4284f635 |
| REQ-p01011 | Event Transformation and Migration | prd-event-sourcing-system.md | adff05f2 |
| REQ-p01012 | Batch Event Operations | prd-event-sourcing-system.md | 0070c072 |
| REQ-p01014 | Observability and Monitoring | prd-event-sourcing-system.md | 9df008fb |
| REQ-p01015 | Automated Testing Support | prd-event-sourcing-system.md | fb5dbbff |
| REQ-p01016 | Performance Benchmarking | prd-event-sourcing-system.md | 2c0805cf |
| REQ-p01017 | Backward Compatibility Guarantees | prd-event-sourcing-system.md | c0664b5d |
| REQ-p01018 | Security Audit and Compliance | prd-event-sourcing-system.md | acb9854a |
| REQ-p01019 | Phased Implementation | prd-event-sourcing-system.md | 44d8ece3 |
| REQ-p01020 | Privacy Policy and Regulatory Compliance Documentation | prd-glossary.md | c67b91d2 |
| REQ-p01021 | Service Availability Commitment | prd-SLA.md | fc65d10f |
| REQ-p01022 | Incident Severity Classification | prd-SLA.md | b38ac116 |
| REQ-p01023 | Incident Response Times | prd-SLA.md | dcee0291 |
| REQ-p01024 | Disaster Recovery Objectives | prd-SLA.md | 5db46324 |
| REQ-p01025 | Third-Party Timestamp Attestation Capability | prd-evidence-records.md | a926adf0 |
| REQ-p01026 | Bitcoin-Based Timestamp Implementation | prd-evidence-records.md | 4a1ce95c |
| REQ-p01027 | Timestamp Verification Interface | prd-evidence-records.md | a0a66254 |
| REQ-p01028 | Timestamp Proof Archival | prd-evidence-records.md | 01f23d44 |
| REQ-p01029 | Device Fingerprinting | prd-evidence-records.md | 2cd57e40 |
| REQ-p01030 | Patient Authentication for Data Attribution | prd-evidence-records.md | a3c9353f |
| REQ-p01031 | Optional Geolocation Tagging | prd-evidence-records.md | b864499d |
| REQ-p01032 | Hashed Email Identity Verification | prd-evidence-records.md | 8f227ca7 |
| REQ-p01033 | Customer Incident Notification | prd-SLA.md | a8193b60 |
| REQ-p01034 | Root Cause Analysis | prd-SLA.md | 69a5318a |
| REQ-p01035 | Corrective and Preventive Action | prd-SLA.md | 23046f23 |
| REQ-p01036 | Data Recovery Guarantee | prd-SLA.md | 0224912a |
| REQ-p01037 | Chronic Failure Escalation | prd-SLA.md | 3a07854b |
| REQ-p01038 | Regulatory Event Support | prd-SLA.md | 64f84d80 |
| REQ-p01039 | Diary Start Day Definition | prd-diary-app.md | fe48ad66 |
| REQ-p01040 | Calendar Visual Indicators for Entry Status | prd-diary-app.md | ae8a494b |
| REQ-p01041 | Open Source Licensing | prd-system.md | 85c600f4 |
| REQ-p01042 | Web Diary Application | prd-diary-web.md | 3a7e056b |
| REQ-p01043 | Web Diary Authentication via Linking Code | prd-diary-web.md | f9efb798 |
| REQ-p01044 | Web Diary Session Management | prd-diary-web.md | e1565e20 |
| REQ-p01045 | Web Diary Privacy Protection | prd-diary-web.md | 3f9fee14 |
| REQ-p01046 | Web Diary Account Creation | prd-diary-web.md | 6f862e69 |
| REQ-p01047 | Web Diary User Profile | prd-diary-web.md | 2d343eab |
| REQ-p01048 | Web Diary Login Interface | prd-diary-web.md | 9727c6a8 |
| REQ-p01049 | Web Diary Lost Credential Recovery | prd-diary-web.md | 09aa8fab |
| REQ-p01050 | Event Type Registry | prd-event-sourcing-system.md | e816a02e |
| REQ-p01051 | Questionnaire Versioning Model | prd-event-sourcing-system.md | fbf500ff |
| REQ-p01052 | Questionnaire Localization and Translation Tracking | prd-event-sourcing-system.md | 74dee412 |
| REQ-p01053 | Sponsor Questionnaire Eligibility Configuration | prd-event-sourcing-system.md | d347bcdb |
| REQ-p01054 | Complete Infrastructure Isolation Per Sponsor | prd-architecture-multi-sponsor.md | be0a9046 |
| REQ-p01055 | Sponsor Confidentiality | prd-architecture-multi-sponsor.md | 76b4de61 |
| REQ-p01056 | Confidentiality Sufficiency | prd-architecture-multi-sponsor.md | f340c7b7 |
| REQ-p01057 | Mono Repository with Sponsor Repositories | prd-architecture-multi-sponsor.md | 06c463fb |
| REQ-p01058 | Unified App Deployment | prd-architecture-multi-sponsor.md | 97c79ca1 |
| REQ-p01059 | Customization Policy | prd-architecture-multi-sponsor.md | 1b9d5965 |
| REQ-p01060 | UX Changes During Trials | prd-architecture-multi-sponsor.md | a93a58d7 |
| REQ-p01061 | GDPR Compliance | prd-clinical-trials.md | c4ed4d8a |
| REQ-p01062 | GDPR Data Portability | prd-clinical-trials.md | 4d47581f |
| REQ-p01064 | Investigator Questionnaire Approval Workflow | prd-questionnaire-approval.md | 7ba8d6d5 |
| REQ-p01065 | Clinical Questionnaire System | prd-questionnaire-system.md | c602e22d |
| REQ-p01066 | Daily Epistaxis Record Questionnaire | prd-questionnaire-epistaxis.md | 10695516 |
| REQ-p01067 | NOSE HHT Questionnaire | prd-questionnaire-nose-hht.md | 7473ad89 |
| REQ-p01068 | HHT Quality of Life Questionnaire | prd-questionnaire-qol.md | 8feb18c9 |
| REQ-p01069 | Daily Epistaxis Record User Interface | prd-questionnaire-epistaxis.md | 3cd9c967 |
| REQ-p01070 | NOSE HHT User Interface | prd-questionnaire-nose-hht.md | 1f1f5598 |
| REQ-p01071 | HHT Quality of Life User Interface | prd-questionnaire-qol.md | 97122b72 |
| REQ-p70000 | Local Data Storage | prd-diary-app.md | 86fa6920 |
| REQ-p70001 | Sponsor Portal Application | prd-portal.md | be01f827 |
| REQ-p70005 | Customizable Role-Based Access Control | prd-portal.md | a9f3141f |
| REQ-p70006 | Comprehensive Audit Trail | prd-portal.md | 6d89830c |
| REQ-p70007 | Linking Code Lifecycle Management | prd-portal.md | fe32ff5f |
| REQ-p70008 | Sponsor-Specific Role Mapping | prd-portal.md | 74b1201e |
| REQ-p70009 | Link New Patient Workflow | prd-portal.md | 4f1edfe6 |
| REQ-p70010 | Patient Disconnection Workflow | prd-portal.md | 0e956c62 |
| REQ-p70011 | Patient Reconnection Workflow | prd-portal.md | c192cad5 |

## Operations Requirements (OPS)

| ID | Title | File | Hash |
| --- | --- | --- | --- |
| REQ-o00001 | Separate GCP Projects Per Sponsor | ops-deployment.md | 7f9aaf0b |
| REQ-o00002 | Environment-Specific Configuration Management | ops-deployment.md | 720a8e57 |
| REQ-o00003 | GCP Project Provisioning Per Sponsor | ops-database-setup.md | 7110fea1 |
| REQ-o00004 | Database Schema Deployment | ops-database-setup.md | 7ae2ea75 |
| REQ-o00005 | Audit Trail Monitoring | ops-operations.md | a01cc9d7 |
| REQ-o00006 | MFA Configuration for Staff Accounts | ops-security-authentication.md | 807dc978 |
| REQ-o00007 | Role-Based Permission Configuration | ops-security.md | bafee84e |
| REQ-o00008 | Backup and Retention Policy | ops-operations.md | 201d286b |
| REQ-o00009 | Portal Deployment Per Sponsor | ops-deployment.md | bab34904 |
| REQ-o00010 | Mobile App Release Process | ops-deployment.md | ad045610 |
| REQ-o00011 | Multi-Site Data Configuration Per Sponsor | ops-database-setup.md | 87a63123 |
| REQ-o00013 | Requirements Format Validation | ops-requirements-management.md | 1725f670 |
| REQ-o00014 | Top-Down Requirement Cascade | ops-requirements-management.md | 0bbda48b |
| REQ-o00015 | Documentation Structure Enforcement | ops-requirements-management.md | 18aebcc6 |
| REQ-o00016 | Architecture Decision Process | ops-requirements-management.md | 55014c6f |
| REQ-o00017 | Version Control Workflow | ops-requirements-management.md | 76d1310e |
| REQ-o00020 | Patient Data Isolation Policy Deployment | ops-security-RLS.md | 4bc3d244 |
| REQ-o00021 | Investigator Site-Scoped Access Policy Deployment | ops-security-RLS.md | c27a45e9 |
| REQ-o00022 | Investigator Annotation Access Policy Deployment | ops-security-RLS.md | ca9a1f99 |
| REQ-o00023 | Analyst Read-Only Access Policy Deployment | ops-security-RLS.md | 12b6ff84 |
| REQ-o00024 | Sponsor Global Access Policy Deployment | ops-security-RLS.md | 2959cd2c |
| REQ-o00025 | Auditor Compliance Access Policy Deployment | ops-security-RLS.md | 0e5f91ee |
| REQ-o00026 | Administrator Access Policy Deployment | ops-security-RLS.md | 2797fed4 |
| REQ-o00027 | Event Sourcing State Protection Policy Deployment | ops-security-RLS.md | 3d86ff4e |
| REQ-o00041 | Infrastructure as Code for Cloud Resources | ops-infrastructure-as-code.md | ba0592d5 |
| REQ-o00042 | Infrastructure Change Control | ops-infrastructure-as-code.md | 1a9f687d |
| REQ-o00043 | Automated Deployment Pipeline | ops-deployment-automation.md | 0dacb8c9 |
| REQ-o00044 | Database Migration Automation | ops-deployment-automation.md | 78684c79 |
| REQ-o00045 | Error Tracking and Monitoring | ops-monitoring-observability.md | 0b3b3002 |
| REQ-o00046 | Uptime Monitoring | ops-monitoring-observability.md | 89ca2abc |
| REQ-o00047 | Performance Monitoring | ops-monitoring-observability.md | cc6097be |
| REQ-o00048 | Audit Log Monitoring | ops-monitoring-observability.md | ddecc3fd |
| REQ-o00049 | Artifact Retention and Archival | ops-artifact-management.md | 657b1be8 |
| REQ-o00050 | Environment Parity and Separation | ops-artifact-management.md | 6e251c7f |
| REQ-o00051 | Change Control and Audit Trail | ops-artifact-management.md | 245582fc |
| REQ-o00052 | CI/CD Pipeline for Requirement Traceability | ops-cicd.md | 1997bd7f |
| REQ-o00053 | Branch Protection Enforcement | ops-cicd.md | 6f17c0af |
| REQ-o00054 | Audit Trail Generation for CI/CD | ops-cicd.md | 501b33ec |
| REQ-o00056 | SLO Definition and Tracking | ops-SLA.md | bc5b89e6 |
| REQ-o00057 | Automated Uptime Monitoring | ops-SLA.md | 3d0a47f6 |
| REQ-o00058 | On-Call Automation | ops-SLA.md | 2a99b2cc |
| REQ-o00059 | Automated Status Page | ops-SLA.md | 5645788d |
| REQ-o00060 | SLA Reporting Automation | ops-SLA.md | 4e49c4c5 |
| REQ-o00061 | Incident Classification Automation | ops-SLA.md | c22e84e1 |
| REQ-o00062 | RCA and CAPA Workflow | ops-SLA.md | 2d9df605 |
| REQ-o00063 | Error Budget Alerting | ops-SLA.md | 1d760fd6 |
| REQ-o00064 | Maintenance Window Management | ops-SLA.md | 179a2f5a |
| REQ-o00065 | Clinical Trial Diary Platform Operations | ops-system.md | bfc2940e |
| REQ-o00066 | Multi-Framework Compliance Automation | ops-system.md | 567513fa |
| REQ-o00067 | Automated Compliance Evidence Collection | ops-system.md | 78c147a2 |
| REQ-o00068 | Automated Access Review | ops-system.md | 2b4f314b |
| REQ-o00069 | Encryption Verification | ops-system.md | 0f8caa4c |
| REQ-o00070 | Data Residency Enforcement | ops-system.md | 63dab109 |
| REQ-o00071 | Automated Incident Detection | ops-system.md | 66296f8a |
| REQ-o00072 | Regulatory Breach Notification | ops-system.md | 71f2357b |
| REQ-o00073 | Automated Change Control | ops-system.md | 55aac77d |
| REQ-o00074 | Automated Backup Verification | ops-system.md | cf3ee0ab |
| REQ-o00075 | Third-Party Security Assessment | ops-system.md | 372a4c1e |
| REQ-o00076 | Sponsor Repository Provisioning | ops-sponsor-repos.md | a18bdb2a |
| REQ-o00077 | Sponsor CI/CD Integration | ops-sponsor-repos.md | 1f262276 |

## Development Requirements (DEV)

| ID | Title | File | Hash |
| --- | --- | --- | --- |
| REQ-d00001 | Sponsor-Specific Configuration Loading | dev-configuration.md | 5950765d |
| REQ-d00002 | Pre-Build Configuration Validation | dev-configuration.md | c7f7afe9 |
| REQ-d00003 | Identity Platform Configuration Per Sponsor | dev-security.md | 12a3c3c0 |
| REQ-d00004 | Local-First Data Entry Implementation | dev-app.md | 2f8a00ce |
| REQ-d00005 | Sponsor Configuration Detection Implementation | dev-app.md | ef873a14 |
| REQ-d00006 | Mobile App Build and Release Process | dev-app.md | af8f9240 |
| REQ-d00007 | Database Schema Implementation and Deployment | dev-database.md | cb61d31e |
| REQ-d00008 | MFA Enrollment and Verification Implementation | dev-security.md | 6ed406fa |
| REQ-d00009 | Role-Based Permission Enforcement Implementation | dev-security.md | 83f2e694 |
| REQ-d00010 | Data Encryption Implementation | dev-security.md | ff125c2d |
| REQ-d00011 | Multi-Site Schema Implementation | dev-database.md | 09fe472c |
| REQ-d00013 | Application Instance UUID Generation | dev-app.md | ce4d2a77 |
| REQ-d00014 | Requirement Validation Tooling | dev-requirements-management.md | 5ef43845 |
| REQ-d00015 | Traceability Matrix Auto-Generation | dev-requirements-management.md | 761084dc |
| REQ-d00016 | Code-to-Requirement Linking | dev-requirements-management.md | 8bf2c189 |
| REQ-d00017 | ADR Template and Lifecycle Tooling | dev-requirements-management.md | fc6fd26f |
| REQ-d00018 | Git Hook Implementation | dev-requirements-management.md | 70fae011 |
| REQ-d00019 | Patient Data Isolation RLS Implementation | dev-security-RLS.md | 51425522 |
| REQ-d00020 | Investigator Site-Scoped RLS Implementation | dev-security-RLS.md | 75c2466d |
| REQ-d00021 | Investigator Annotation RLS Implementation | dev-security-RLS.md | c020fead |
| REQ-d00022 | Analyst Read-Only RLS Implementation | dev-security-RLS.md | 62c367e5 |
| REQ-d00023 | Sponsor Global Access RLS Implementation | dev-security-RLS.md | dba73524 |
| REQ-d00024 | Auditor Compliance RLS Implementation | dev-security-RLS.md | c263fd32 |
| REQ-d00025 | Administrator Break-Glass RLS Implementation | dev-security-RLS.md | 93358063 |
| REQ-d00026 | Event Sourcing State Protection RLS Implementation | dev-security-RLS.md | 46e9dc01 |
| REQ-d00027 | Containerized Development Environments | dev-environment.md | 12d637c5 |
| REQ-d00053 | Development Environment and Tooling Setup | dev-requirements-management.md | a00606aa |
| REQ-d00055 | Role-Based Environment Separation | dev-environment.md | 03138c47 |
| REQ-d00056 | Cross-Platform Development Support | dev-environment.md | 6e05c815 |
| REQ-d00057 | CI/CD Environment Parity | dev-environment.md | 1b1aaea0 |
| REQ-d00058 | Secrets Management via Doppler | dev-environment.md | cd79209a |
| REQ-d00059 | Development Tool Specifications | dev-environment.md | caee2790 |
| REQ-d00060 | VS Code Dev Containers Integration | dev-environment.md | d8498586 |
| REQ-d00061 | Automated QA Workflow | dev-environment.md | 50c6e242 |
| REQ-d00062 | Environment Validation & Change Control | dev-environment.md | 9a5588aa |
| REQ-d00063 | Shared Workspace and File Exchange | dev-environment.md | c3be06e7 |
| REQ-d00064 | Plugin JSON Validation Tooling | dev-ai-claude.md | ea213114 |
| REQ-d00065 | Plugin Path Validation | dev-ai-claude.md | 6a207563 |
| REQ-d00066 | Plugin-Specific Permission Management | dev-marketplace-permissions.md | 356621f9 |
| REQ-d00067 | Streamlined Ticket Creation Agent | dev-ai-claude.md | 4fe51e65 |
| REQ-d00068 | Enhanced Workflow New Work Detection | dev-ai-claude.md | 36d736e0 |
| REQ-d00077 | Web Diary Frontend Framework | dev-diary-web.md | a84bf289 |
| REQ-d00078 | Linking Code Validation | dev-linking.md | 0a89ae19 |
| REQ-d00079 | Linking Code Pattern Matching | dev-linking.md | 958939ee |
| REQ-d00080 | Web Session Management Implementation | dev-diary-web.md | 1ed9928f |
| REQ-d00081 | Linked Device Records | dev-linking.md | d44ac005 |
| REQ-d00082 | Password Hashing Implementation | dev-diary-web.md | 2f426f50 |
| REQ-d00083 | Browser Storage Clearing | dev-diary-web.md | 781a1594 |
| REQ-d00084 | Sponsor Configuration Loading | dev-diary-web.md | 654added |
| REQ-d00085 | Local Database Export and Import | dev-app.md | 392092af |
| REQ-d00086 | Sponsor Repository Structure Template | dev-sponsor-repos.md | 4b7874ee |
| REQ-d00087 | Core Repo Reference Configuration | dev-sponsor-repos.md | 91ce804d |
| REQ-d00088 | Sponsor Requirement Namespace Validation | dev-sponsor-repos.md | 128e817d |
| REQ-d00089 | Cross-Repository Traceability | dev-sponsor-repos.md | ca7aeae6 |
| REQ-d00090 | Development Environment Installation Qualification | dev-environment.md | 554f4e07 |
| REQ-d00091 | Development Environment Operational Qualification | dev-environment.md | fe899a74 |
| REQ-d00092 | Development Environment Performance Qualification | dev-environment.md | 5185eb02 |
| REQ-d00093 | Development Environment Change Control | dev-environment.md | 25b6fc05 |

---

*Generated by elspais*