# Requirements Index

## Product Requirements (PRD)

| ID         | Title                                                               | File                                      | Hash     |
| ---------- | ------------------------------------------------------------------- | ----------------------------------------- | -------- |
| REQ-p00001 | Complete Multi-Sponsor Data Separation                              | prd-security.md                           | 57702900 |
| REQ-p00002 | Multi-Factor Authentication for Staff                               | prd-security.md                           | b014564d |
| REQ-p00003 | Separate Database Per Sponsor                                       | prd-database.md                           | 08e74590 |
| REQ-p00004 | Immutable Audit Trail via Event Sourcing                            | prd-database.md                           | 4353a766 |
| REQ-p00005 | Role-Based Access Control                                           | prd-security-RBAC.md                      | 83e3e545 |
| REQ-p00006 | Offline-First Data Entry                                            | prd-diary-app.md                          | 2224fecf |
| REQ-p00007 | Automatic Sponsor Configuration                                     | prd-diary-app.md                          | 504e360e |
| REQ-p00008 | Single Mobile App for All Sponsors                                  | prd-architecture-multi-sponsor.md         | 3fe1fad0 |
| REQ-p00009 | Sponsor-Specific Portals                                            | prd-architecture-multi-sponsor.md         | e26dfd95 |
| REQ-p00010 | FDA 21 CFR Part 11 Compliance                                       | prd-clinical-trials.md                    | 20c0e7bc |
| REQ-p00011 | ALCOA+ Data Integrity Principles                                    | prd-clinical-trials.md                    | 54818734 |
| REQ-p00012 | Clinical Data Retention Requirements                                | prd-clinical-trials.md                    | 42ddd27b |
| REQ-p00013 | Complete Data Change History                                        | prd-database.md                           | a5e8ac78 |
| REQ-p00014 | Least Privilege Access                                              | prd-security-RBAC.md                      | 6b0df135 |
| REQ-p00015 | Database-Level Access Enforcement                                   | prd-security-RLS.md                       | e0b19391 |
| REQ-p00016 | Separation of Identity and Clinical Data                            | prd-security-data-classification.md       | 4a8b2335 |
| REQ-p00017 | Data Encryption                                                     | prd-security-data-classification.md       | 55d8aea3 |
| REQ-p00018 | Multi-Site Support Per Sponsor                                      | prd-architecture-multi-sponsor.md         | c4d7df6f |
| REQ-p00020 | System Validation and Traceability                                  | prd-requirements-management.md            | 7d81caf7 |
| REQ-p00021 | Architecture Decision Documentation                                 | prd-requirements-management.md            | 76c82ce6 |
| REQ-p00022 | Analyst Read-Only Access                                            | prd-security-RLS.md                       | f6c37670 |
| REQ-p00023 | Sponsor Global Data Access                                          | prd-security-RLS.md                       | de7caa72 |
| REQ-p00035 | Patient Data Isolation                                              | prd-security-RLS.md                       | d519a005 |
| REQ-p00036 | Investigator Site-Scoped Access                                     | prd-security-RLS.md                       | 8cba2876 |
| REQ-p00037 | Investigator Annotation Restrictions                                | prd-security-RLS.md                       | 18789c92 |
| REQ-p00038 | Auditor Compliance Access                                           | prd-security-RLS.md                       | b5c84953 |
| REQ-p00039 | Administrator Access with Audit Trail                               | prd-security-RLS.md                       | 5082758c |
| REQ-p00040 | Event Sourcing State Protection                                     | prd-security-RLS.md                       | 1694c31b |
| REQ-p00042 | HHT Epistaxis Data Capture Standard                                 | prd-epistaxis-terminology.md              | 36dc9faf |
| REQ-p00043 | Diary Mobile Application                                            | prd-diary-app.md                          | d5bc3ef8 |
| REQ-p00044 | Clinical Trial Compliant Diary Platform                             | prd-system.md                             | 0919ad00 |
| REQ-p00045 | Regulatory Compliance Framework                                     | prd-clinical-trials.md                    | c4fa27f7 |
| REQ-p00046 | Clinical Data Storage System                                        | prd-database.md                           | 75ec9efe |
| REQ-p00047 | Data Backup and Archival                                            | prd-backup.md                             | 4e9501e4 |
| REQ-p00048 | Platform Operations and Monitoring                                  | prd-devops.md                             | af349286 |
| REQ-p00049 | Ancillary Platform Services                                         | prd-services.md                           | ff326529 |
| REQ-p00050 | Temporal Entry Validation                                           | prd-diary-app.md                          | 7b918745 |
| REQ-p01000 | Event Sourcing Client Interface                                     | prd-event-sourcing-system.md              | c289ba20 |
| REQ-p01001 | Offline Event Queue with Automatic Synchronization                  | prd-event-sourcing-system.md              | 192df7e9 |
| REQ-p01002 | Optimistic Concurrency Control                                      | prd-event-sourcing-system.md              | dd66beb1 |
| REQ-p01003 | Immutable Event Storage with Audit Trail                            | prd-event-sourcing-system.md              | db231d89 |
| REQ-p01004 | Schema Version Management                                           | prd-event-sourcing-system.md              | 94c032f0 |
| REQ-p01005 | Real-time Event Subscription                                        | prd-event-sourcing-system.md              | 61d80d18 |
| REQ-p01006 | Type-Safe Materialized View Queries                                 | prd-event-sourcing-system.md              | 0ca0d9ae |
| REQ-p01007 | Error Handling and Diagnostics                                      | prd-event-sourcing-system.md              | 142a4821 |
| REQ-p01008 | Event Replay and Time Travel Debugging                              | prd-event-sourcing-system.md              | cef615c5 |
| REQ-p01009 | Encryption at Rest for Offline Queue                                | prd-event-sourcing-system.md              | c6c8ad62 |
| REQ-p01010 | Multi-tenancy Support                                               | prd-event-sourcing-system.md              | 46265e7f |
| REQ-p01011 | Event Transformation and Migration                                  | prd-event-sourcing-system.md              | e1fbce81 |
| REQ-p01012 | Batch Event Operations                                              | prd-event-sourcing-system.md              | 5cf4df20 |
| REQ-p01014 | Observability and Monitoring                                        | prd-event-sourcing-system.md              | ad6ebb22 |
| REQ-p01015 | Automated Testing Support                                           | prd-event-sourcing-system.md              | f15b2c58 |
| REQ-p01016 | Performance Benchmarking                                            | prd-event-sourcing-system.md              | 5f5f0fe9 |
| REQ-p01017 | Backward Compatibility Guarantees                                   | prd-event-sourcing-system.md              | 68686f0b |
| REQ-p01018 | Security Audit and Compliance                                       | prd-event-sourcing-system.md              | ae8f6e49 |
| REQ-p01019 | Phased Implementation                                               | prd-event-sourcing-system.md              | 42cdad57 |
| REQ-p01020 | Privacy Policy and Regulatory Compliance Documentation              | prd-privacy-policy.md                     | 93b12550 |
| REQ-p01021 | Service Availability Commitment                                     | prd-SLA.md                                | d39861a9 |
| REQ-p01022 | Incident Severity Classification                                    | prd-SLA.md                                | d1734735 |
| REQ-p01023 | Incident Response Times                                             | prd-SLA.md                                | 40fb577e |
| REQ-p01024 | Disaster Recovery Objectives                                        | prd-SLA.md                                | 6b076a50 |
| REQ-p01025 | Third-Party Timestamp Attestation Capability                        | prd-evidence-records.md                   | f2ab1f17 |
| REQ-p01026 | Bitcoin-Based Timestamp Implementation                              | prd-evidence-records.md                   | 94499ad5 |
| REQ-p01027 | Timestamp Verification Interface                                    | prd-evidence-records.md                   | 9956bd94 |
| REQ-p01028 | Timestamp Proof Archival                                            | prd-evidence-records.md                   | 69a49395 |
| REQ-p01029 | Device Fingerprinting                                               | prd-evidence-records.md                   | 8e10b85a |
| REQ-p01030 | Patient Authentication for Data Attribution                         | prd-evidence-records.md                   | da907239 |
| REQ-p01031 | Optional Geolocation Tagging                                        | prd-evidence-records.md                   | f9a69607 |
| REQ-p01032 | Hashed Email Identity Verification                                  | prd-evidence-records.md                   | 0ba2d208 |
| REQ-p01033 | Customer Incident Notification                                      | prd-SLA.md                                | 3ca3df0f |
| REQ-p01034 | Root Cause Analysis                                                 | prd-SLA.md                                | 0778e3bb |
| REQ-p01035 | Corrective and Preventive Action                                    | prd-SLA.md                                | f2c78d76 |
| REQ-p01036 | Data Recovery Guarantee                                             | prd-SLA.md                                | 5909fb2b |
| REQ-p01037 | Chronic Failure Escalation                                          | prd-SLA.md                                | 63205737 |
| REQ-p01038 | Regulatory Event Support                                            | prd-SLA.md                                | f62f5e4d |
| REQ-p01039 | Diary Start Day Definition                                          | prd-diary-app.md                          | acabeeb1 |
| REQ-p01040 | Calendar Visual Indicators for Entry Status                         | prd-diary-app.md                          | e4e1c4c2 |
| REQ-p01041 | Open Source Licensing                                               | prd-system.md                             | 7e6b1e00 |
| REQ-p01042 | Web Diary Application                                               | prd-diary-web.md                          | a19f716f |
| REQ-p01043 | Web Diary Authentication via Linking Code                           | prd-diary-web.md                          | 8c7d6240 |
| REQ-p01044 | Web Diary Session Management                                        | prd-diary-web.md                          | 8264ceb9 |
| REQ-p01045 | Web Diary Privacy Protection                                        | prd-diary-web.md                          | 58e010cd |
| REQ-p01046 | Web Diary Account Creation                                          | prd-diary-web.md                          | 8d39c8e6 |
| REQ-p01047 | Web Diary User Profile                                              | prd-diary-web.md                          | c132adc2 |
| REQ-p01048 | Web Diary Login Interface                                           | prd-diary-web.md                          | d643690a |
| REQ-p01049 | Web Diary Lost Credential Recovery                                  | prd-diary-web.md                          | 0af0c79c |
| REQ-p01050 | Event Type Registry                                                 | prd-event-sourcing-system.md              | 52464e42 |
| REQ-p01051 | Questionnaire Versioning Model                                      | prd-event-sourcing-system.md              | e311e5fc |
| REQ-p01052 | Questionnaire Localization and Translation Tracking                 | prd-event-sourcing-system.md              | 4218237c |
| REQ-p01053 | Sponsor Questionnaire Eligibility Configuration                     | prd-event-sourcing-system.md              | 3bc66244 |
| REQ-p01054 | Complete Infrastructure Isolation Per Sponsor                       | prd-architecture-multi-sponsor.md         | 5f9f93ed |
| REQ-p01055 | Sponsor Confidentiality                                             | prd-architecture-multi-sponsor.md         | 364675e2 |
| REQ-p01056 | Confidentiality Sufficiency                                         | prd-architecture-multi-sponsor.md         | f29524ee |
| REQ-p01057 | Mono Repository with Sponsor Repositories                           | prd-architecture-multi-sponsor.md         | a54d5ad6 |
| REQ-p01058 | Unified App Deployment                                              | prd-architecture-multi-sponsor.md         | c22435c6 |
| REQ-p01059 | Customization Policy                                                | prd-architecture-multi-sponsor.md         | bf7c7b8e |
| REQ-p01060 | UX Changes During Trials                                            | prd-architecture-multi-sponsor.md         | fadb4f60 |
| REQ-p01061 | EU GDPR                                                             | prd-clinical-trials.md                    | ebe9e2ad |
| REQ-p01062 | GDPR Data Portability                                               | prd-clinical-trials.md                    | 30b27336 |
| REQ-p01064 | Investigator Questionnaire Approval Workflow                        | prd-questionnaire-approval.md             | 8790cf5d |
| REQ-p01065 | Clinical Questionnaire System                                       | prd-questionnaire-system.md               | 0a439bc2 |
| REQ-p01066 | Daily Epistaxis Record Questionnaire                                | prd-questionnaire-epistaxis.md            | 29498f8f |
| REQ-p01067 | NOSE HHT Questionnaire                                              | prd-questionnaire-nose-hht.md             | 23b411c6 |
| REQ-p01068 | HHT Quality of Life Questionnaire                                   | prd-questionnaire-qol.md                  | e4980a4b |
| REQ-p01069 | Daily Epistaxis Record User Interface                               | prd-questionnaire-epistaxis.md            | 0efa31a6 |
| REQ-p01070 | NOSE HHT User Interface                                             | prd-questionnaire-nose-hht.md             | 84fa171d |
| REQ-p01071 | HHT Quality of Life User Interface                                  | prd-questionnaire-qol.md                  | a231a942 |
| REQ-p01072 | Mobile App Linking Status and History                               | prd-diary-app.md                          | cf32de6c |
| REQ-p01073 | Questionnaire Session Management                                    | prd-questionnaire-session.md              | a101e60e |
| REQ-p70000 | Local Data Storage                                                  | prd-diary-app.md                          | ab1e5121 |
| REQ-p70001 | Sponsor Portal Application                                          | prd-portal.md                             | 493e8af0 |
| REQ-p70005 | Customizable Role-Based Access Control                              | prd-portal.md                             | d0617ddb |
| REQ-p70006 | Comprehensive Audit Trail                                           | prd-portal.md                             | e3ed7b52 |
| REQ-p70007 | Linking Code Lifecycle Management                                   | prd-portal.md                             | c0a77938 |
| REQ-p70008 | Sponsor-Specific Role Mapping                                       | prd-portal.md                             | 9b56c1c9 |
| REQ-p70009 | Link New Patient Workflow                                           | prd-portal.md                             | 84d192e7 |
| REQ-p70010 | Patient Disconnection Workflow                                      | prd-portal.md                             | 79bc39eb |
| REQ-p70011 | Patient Reconnection Workflow                                       | prd-portal.md                             | c386824f |
| REQ-p70012 | Portal Data Acceptance and Rejection                                | prd-portal.md                             | 2f615ddb |
| REQ-p80001 | FDA 21 CFR Part 11 Compliance                                       | regulations/fda/prd-fda-21-cfr-11.md      | 54daf3d2 |
| REQ-p80002 | 21 CFR Part 11 Compliance                                           | regulations/fda/prd-fda-21-cfr-11.md      | a5d5da23 |
| REQ-p80003 | FDA Guidance on Electronic Records in Clinical Investigations       | regulations/fda/prd-fda-21-cfr-11.md      | 7330eda3 |
| REQ-p80004 | GCP Data Requirements for Audit Trails and Data Corrections         | regulations/fda/prd-fda-21-cfr-11.md      | 52eb4a31 |
| REQ-p80005 | GCP Consolidated Requirements for Audit Trails and Data Corrections | regulations/fda/prd-fda-21-cfr-11.md      | 70cb1b59 |
| REQ-p80010 | Electronic Records Controls                                         | regulations/fda/prd-fda-part11-domains.md | 6d82267c |
| REQ-p80020 | Electronic Signatures                                               | regulations/fda/prd-fda-part11-domains.md | 5eb03a00 |
| REQ-p80030 | Audit Trail Requirements                                            | regulations/fda/prd-fda-part11-domains.md | 2070327e |
| REQ-p80040 | Data Correction Controls                                            | regulations/fda/prd-fda-part11-domains.md | a4ce844c |
| REQ-p80050 | System Access and Security Controls                                 | regulations/fda/prd-fda-part11-domains.md | c9937e50 |
| REQ-p80060 | Closed and Open System Controls                                     | regulations/fda/prd-fda-part11-domains.md | 20d10fe8 |

## Operations Requirements (OPS)

| ID         | Title                                             | File                                   | Hash     |
| ---------- | ------------------------------------------------- | -------------------------------------- | -------- |
| REQ-o00001 | Separate GCP Projects Per Sponsor                 | ops-deployment.md                      | 5e07b75b |
| REQ-o00002 | Environment-Specific Configuration Management     | ops-deployment.md                      | 0d39cea7 |
| REQ-o00003 | GCP Project Provisioning Per Sponsor              | ops-database-setup.md                  | f7f7d3bc |
| REQ-o00004 | Database Schema Deployment                        | ops-database-setup.md                  | 26cf428c |
| REQ-o00005 | Audit Trail Monitoring                            | ops-operations.md                      | d5d52f2f |
| REQ-o00006 | MFA Configuration for Staff Accounts              | ops-security-authentication.md         | 5bb3d071 |
| REQ-o00007 | Role-Based Permission Configuration               | ops-security.md                        | d07993e9 |
| REQ-o00008 | Backup and Retention Policy                       | ops-operations.md                      | 9178fe2d |
| REQ-o00009 | Portal Deployment Per Sponsor                     | ops-deployment.md                      | 79fba7ec |
| REQ-o00010 | Mobile App Release Process                        | ops-deployment.md                      | c3b108f5 |
| REQ-o00011 | Multi-Site Data Configuration Per Sponsor         | ops-database-setup.md                  | 529b59ce |
| REQ-o00013 | Requirements Format Validation                    | ops-requirements-management.md         | 73eb4415 |
| REQ-o00014 | Top-Down Requirement Cascade                      | ops-requirements-management.md         | 68a8deeb |
| REQ-o00015 | Documentation Structure Enforcement               | ops-requirements-management.md         | bafe78ff |
| REQ-o00016 | Architecture Decision Process                     | ops-requirements-management.md         | d2bf6cb2 |
| REQ-o00017 | Version Control Workflow                          | ops-requirements-management.md         | c5c6c55e |
| REQ-o00020 | Patient Data Isolation Policy Deployment          | ops-security-RLS.md                    | 21abbb15 |
| REQ-o00021 | Investigator Site-Scoped Access Policy Deployment | ops-security-RLS.md                    | 06f5f0f4 |
| REQ-o00022 | Investigator Annotation Access Policy Deployment  | ops-security-RLS.md                    | c758cd88 |
| REQ-o00023 | Analyst Read-Only Access Policy Deployment        | ops-security-RLS.md                    | 98aa758b |
| REQ-o00024 | Sponsor Global Access Policy Deployment           | ops-security-RLS.md                    | a3f24a6b |
| REQ-o00025 | Auditor Compliance Access Policy Deployment       | ops-security-RLS.md                    | de3aa240 |
| REQ-o00026 | Administrator Access Policy Deployment            | ops-security-RLS.md                    | bd4a9530 |
| REQ-o00027 | Event Sourcing State Protection Policy Deployment | ops-security-RLS.md                    | bd5a22c4 |
| REQ-o00041 | Infrastructure as Code for Cloud Resources        | ops-infrastructure-as-code.md          | 0f754a8a |
| REQ-o00042 | Infrastructure Change Control                     | ops-infrastructure-as-code.md          | ee749ae7 |
| REQ-o00043 | Automated Deployment Pipeline                     | ops-deployment-automation.md           | e74d24c7 |
| REQ-o00044 | Database Migration Automation                     | ops-deployment-automation.md           | 52d9a6a1 |
| REQ-o00045 | Error Tracking and Monitoring                     | ops-monitoring-observability.md        | 072c07f1 |
| REQ-o00046 | Uptime Monitoring                                 | ops-monitoring-observability.md        | 9238bdfd |
| REQ-o00047 | Performance Monitoring                            | ops-monitoring-observability.md        | 8bc9b0d1 |
| REQ-o00048 | Audit Log Monitoring                              | ops-monitoring-observability.md        | 412d2f6d |
| REQ-o00049 | Artifact Retention and Archival                   | ops-artifact-management.md             | 9bbb7f6e |
| REQ-o00050 | Environment Parity and Separation                 | ops-artifact-management.md             | cc66f548 |
| REQ-o00051 | Change Control and Audit Trail                    | ops-artifact-management.md             | e9a92b1f |
| REQ-o00052 | CI/CD Pipeline for Requirement Traceability       | ops-cicd.md                            | 4bfaefe3 |
| REQ-o00053 | Branch Protection Enforcement                     | ops-cicd.md                            | 52dc7376 |
| REQ-o00054 | Audit Trail Generation for CI/CD                  | ops-cicd.md                            | c4d7f202 |
| REQ-o00056 | SLO Definition and Tracking                       | ops-SLA.md                             | 819feadc |
| REQ-o00057 | Automated Uptime Monitoring                       | ops-SLA.md                             | d09940b2 |
| REQ-o00058 | On-Call Automation                                | ops-SLA.md                             | ceb37b43 |
| REQ-o00059 | Automated Status Page                             | ops-SLA.md                             | b29ff754 |
| REQ-o00060 | SLA Reporting Automation                          | ops-SLA.md                             | 6e4844d5 |
| REQ-o00061 | Incident Classification Automation                | ops-SLA.md                             | 0f46ea2d |
| REQ-o00062 | RCA and CAPA Workflow                             | ops-SLA.md                             | 8d5d697b |
| REQ-o00063 | Error Budget Alerting                             | ops-SLA.md                             | 0cce1138 |
| REQ-o00064 | Maintenance Window Management                     | ops-SLA.md                             | f400a1ed |
| REQ-o00065 | Clinical Trial Diary Platform Operations          | ops-system.md                          | 6e292a0f |
| REQ-o00066 | Multi-Framework Compliance Automation             | ops-system.md                          | 3088420e |
| REQ-o00067 | Automated Compliance Evidence Collection          | ops-system.md                          | 2f678f41 |
| REQ-o00068 | Automated Access Review                           | ops-system.md                          | 92fc93fa |
| REQ-o00069 | Encryption Verification                           | ops-system.md                          | d04c0b4a |
| REQ-o00070 | Data Residency Enforcement                        | ops-system.md                          | 7aaf0355 |
| REQ-o00071 | Automated Incident Detection                      | ops-system.md                          | e55b65e5 |
| REQ-o00072 | Regulatory Breach Notification                    | ops-system.md                          | de7d604f |
| REQ-o00073 | Automated Change Control                          | ops-system.md                          | 6ca94be5 |
| REQ-o00074 | Automated Backup Verification                     | ops-system.md                          | 6a7b7dba |
| REQ-o00075 | Third-Party Security Assessment                   | ops-system.md                          | 345140ac |
| REQ-o00076 | Sponsor Repository Provisioning                   | ops-sponsor-repos.md                   | 831fa654 |
| REQ-o00077 | Sponsor CI/CD Integration                         | ops-sponsor-repos.md                   | 7104b083 |
| REQ-o00078 | Change-Appropriate CI Validation                  | ops-cicd.md                            | ab0977df |
| REQ-o00079 | Commit and PR Traceability Enforcement            | ops-cicd.md                            | cc298537 |
| REQ-o00080 | Secret and Vulnerability Scanning                 | ops-cicd.md                            | 90e58ccc |
| REQ-o00081 | Code Quality and Static Analysis                  | ops-cicd.md                            | 0b222d9e |
| REQ-o00082 | Automated Test Execution                          | ops-cicd.md                            | 63cc8fe6 |
| REQ-o00083 | QA Promotion Gate                                 | ops-cicd.md                            | dd06f8de |
| REQ-o80010 | Training and Personnel Qualification              | regulations/fda/ops-fda-part11-SOPs.md | 53e1ba24 |
| REQ-o80020 | Record Retention and Archival                     | regulations/fda/ops-fda-part11-SOPs.md | 9fcd1947 |
| REQ-o80030 | Standard Operating Procedures                     | regulations/fda/ops-fda-part11-SOPs.md | 50d11093 |

## Development Requirements (DEV)

| ID         | Title                                              | File                                                 | Hash     |
| ---------- | -------------------------------------------------- | ---------------------------------------------------- | -------- |
| REQ-d00001 | Sponsor-Specific Configuration Loading             | dev-configuration.md                                 | a2825584 |
| REQ-d00002 | Pre-Build Configuration Validation                 | dev-configuration.md                                 | 5dde0fc5 |
| REQ-d00003 | Identity Platform Configuration Per Sponsor        | dev-security.md                                      | f4493561 |
| REQ-d00004 | Local-First Data Entry Implementation              | dev-app.md                                           | 39589dad |
| REQ-d00005 | Sponsor Configuration Detection Implementation     | dev-app.md                                           | 33d3b6b0 |
| REQ-d00006 | Mobile App Build and Release Process               | dev-app.md                                           | 3b07a626 |
| REQ-d00007 | Database Schema Implementation and Deployment      | dev-database.md                                      | 94170736 |
| REQ-d00008 | MFA Enrollment and Verification Implementation     | dev-security.md                                      | c60371f2 |
| REQ-d00009 | Role-Based Permission Enforcement Implementation   | dev-security.md                                      | c713723f |
| REQ-d00010 | Data Encryption Implementation                     | dev-security.md                                      | be1c205f |
| REQ-d00011 | Multi-Site Schema Implementation                   | dev-database.md                                      | 982caeb9 |
| REQ-d00013 | Application Instance UUID Generation               | dev-app.md                                           | 5a81d46b |
| REQ-d00014 | Requirement Validation Tooling                     | dev-requirements-management.md                       | ed143a48 |
| REQ-d00015 | Traceability Matrix Auto-Generation                | dev-requirements-management.md                       | 235c988e |
| REQ-d00016 | Code-to-Requirement Linking                        | dev-requirements-management.md                       | 7723f737 |
| REQ-d00017 | ADR Template and Lifecycle Tooling                 | dev-requirements-management.md                       | 4fa259a5 |
| REQ-d00018 | Git Hook Implementation                            | dev-requirements-management.md                       | fcfe6de1 |
| REQ-d00019 | Patient Data Isolation RLS Implementation          | dev-security-RLS.md                                  | f3cbf5fe |
| REQ-d00020 | Investigator Site-Scoped RLS Implementation        | dev-security-RLS.md                                  | 2b982234 |
| REQ-d00021 | Investigator Annotation RLS Implementation         | dev-security-RLS.md                                  | 01b5e939 |
| REQ-d00022 | Analyst Read-Only RLS Implementation               | dev-security-RLS.md                                  | 0a4be6ec |
| REQ-d00023 | Sponsor Global Access RLS Implementation           | dev-security-RLS.md                                  | 3cad1719 |
| REQ-d00024 | Auditor Compliance RLS Implementation              | dev-security-RLS.md                                  | 434eca80 |
| REQ-d00025 | Administrator Break-Glass RLS Implementation       | dev-security-RLS.md                                  | ca7b4eac |
| REQ-d00026 | Event Sourcing State Protection RLS Implementation | dev-security-RLS.md                                  | f670b1e5 |
| REQ-d00027 | Containerized Development Environments             | dev-environment.md                                   | 380e7b8c |
| REQ-d00053 | Development Environment and Tooling Setup          | dev-requirements-management.md                       | 31e32e36 |
| REQ-d00055 | Role-Based Environment Separation                  | dev-environment.md                                   | 9d8e2081 |
| REQ-d00056 | Cross-Platform Development Support                 | dev-environment.md                                   | 7ca59703 |
| REQ-d00057 | CI/CD Environment Parity                           | dev-environment.md                                   | 608781a5 |
| REQ-d00058 | Secrets Management via Doppler                     | dev-environment.md                                   | 18a5881a |
| REQ-d00059 | Development Tool Specifications                    | dev-environment.md                                   | 1ddd744c |
| REQ-d00060 | VS Code Dev Containers Integration                 | dev-environment.md                                   | 4b7e967b |
| REQ-d00061 | Automated QA Workflow                              | dev-environment.md                                   | 75dfd6e6 |
| REQ-d00062 | Environment Validation & Change Control            | dev-environment.md                                   | edff16ee |
| REQ-d00063 | Shared Workspace and File Exchange                 | dev-environment.md                                   | 8a68ffca |
| REQ-d00064 | Plugin JSON Validation Tooling                     | dev-ai-claude.md                                     | ade1a4f4 |
| REQ-d00065 | Plugin Path Validation                             | dev-ai-claude.md                                     | 09911117 |
| REQ-d00066 | Plugin-Specific Permission Management              | dev-marketplace-permissions.md                       | 03045719 |
| REQ-d00067 | Streamlined Ticket Creation Agent                  | dev-ai-claude.md                                     | f6d9e288 |
| REQ-d00068 | Enhanced Workflow New Work Detection               | dev-ai-claude.md                                     | 951ecf65 |
| REQ-d00077 | Web Diary Frontend Framework                       | dev-diary-web.md                                     | 8e194f4d |
| REQ-d00078 | Linking Code Validation                            | dev-linking.md                                       | 8cc744c2 |
| REQ-d00079 | Linking Code Pattern Matching                      | dev-linking.md                                       | f5e20cde |
| REQ-d00080 | Web Session Management Implementation              | dev-diary-web.md                                     | 4b91624f |
| REQ-d00081 | Linked Device Records                              | dev-linking.md                                       | 16853ebd |
| REQ-d00082 | Password Hashing Implementation                    | dev-diary-web.md                                     | 1174dead |
| REQ-d00083 | Browser Storage Clearing                           | dev-diary-web.md                                     | 3c9baff2 |
| REQ-d00084 | Sponsor Configuration Loading                      | dev-diary-web.md                                     | b8eb0a19 |
| REQ-d00085 | Local Database Export and Import                   | dev-app.md                                           | eaa18d27 |
| REQ-d00086 | Sponsor Repository Structure Template              | dev-sponsor-repos.md                                 | 0ede3cec |
| REQ-d00087 | Core Repo Reference Configuration                  | dev-sponsor-repos.md                                 | 2f2f7a26 |
| REQ-d00088 | Sponsor Requirement Namespace Validation           | dev-sponsor-repos.md                                 | bfec100c |
| REQ-d00089 | Cross-Repository Traceability                      | dev-sponsor-repos.md                                 | e0ee0f65 |
| REQ-d00090 | Development Environment Installation Qualification | dev-environment.md                                   | f170b97a |
| REQ-d00091 | Development Environment Operational Qualification  | dev-environment.md                                   | 1c2e52c9 |
| REQ-d00092 | Development Environment Performance Qualification  | dev-environment.md                                   | fcb5c6ba |
| REQ-d00093 | Development Environment Change Control             | dev-environment.md                                   | d0a9c48d |
| REQ-d00094 | Linking Code Entry Interface                       | dev-diary-app-linking.md                             | dae36394 |
| REQ-d00095 | Linking Code Input Validation                      | dev-diary-app-linking.md                             | d124cbf4 |
| REQ-d00096 | Enrollment Token Secure Storage                    | dev-diary-app-linking.md                             | 2f2321ae |
| REQ-d00097 | Token Lifecycle and Network Resilience             | dev-diary-app-linking.md                             | 8b7af588 |
| REQ-d00098 | Token Invalidation on Disconnection                | dev-diary-app-linking.md                             | 654a51e8 |
| REQ-d00099 | Linking Code Error Handling                        | dev-diary-app-linking.md                             | 3a1f9cc5 |
| REQ-d00100 | Network Failure Handling During Linking            | dev-diary-app-linking.md                             | fe5b5e9a |
| REQ-d00101 | Enrollment State Machine                           | dev-diary-app-linking.md                             | 2505852b |
| REQ-d00102 | Enrollment State Behaviors                         | dev-diary-app-linking.md                             | ae21987f |
| REQ-d00103 | Disconnection Detection                            | dev-diary-app-linking.md                             | 0ef54680 |
| REQ-d00104 | Contact Study Coordinator Screen                   | dev-diary-app-linking.md                             | 9e53fe8a |
| REQ-d00105 | Reconnection Recovery Path                         | dev-diary-app-linking.md                             | 01389d10 |
| REQ-d00106 | Study Start Questionnaire Rendering                | dev-diary-app-linking.md                             | cbb2b7e7 |
| REQ-d00107 | Questionnaire Response Collection and Storage      | dev-diary-app-linking.md                             | d5097084 |
| REQ-d00108 | Questionnaire Submission Flow                      | dev-diary-app-linking.md                             | 50d5db71 |
| REQ-d00109 | Portal Linking Code Validation Endpoint            | dev-portal-api.md                                    | bac91a72 |
| REQ-d00110 | Linking API Error Response Strategy                | dev-portal-api.md                                    | 39ae2a18 |
| REQ-d00111 | Linking API Audit Trail                            | dev-portal-api.md                                    | 90a41f24 |
| REQ-d00112 | Enrollment Token Revocation                        | dev-portal-api.md                                    | e8863441 |
| REQ-d80011 | ALCOA++ Data Integrity Implementation              | regulations/fda/dev-fda-part11-technical-controls.md | 9bbe74ec |
| REQ-d80021 | Electronic Signature Technical Controls            | regulations/fda/dev-fda-part11-technical-controls.md | dd16ae7a |
| REQ-d80031 | Audit Trail Technical Implementation               | regulations/fda/dev-fda-part11-technical-controls.md | 5e69b0c1 |
| REQ-d80041 | Data Correction Technical Implementation           | regulations/fda/dev-fda-part11-technical-controls.md | 78ef7572 |
| REQ-d80051 | Authentication and Authorization Controls          | regulations/fda/dev-fda-part11-technical-controls.md | a72beb36 |
| REQ-d80052 | User Account Management                            | regulations/fda/dev-fda-part11-technical-controls.md | 95f45277 |
| REQ-d80061 | System Validation Controls                         | regulations/fda/dev-fda-part11-technical-controls.md | 08ae9589 |
| REQ-d80062 | IT Service Provider and Cloud System Controls      | regulations/fda/dev-fda-part11-technical-controls.md | e5b6cafb |
| REQ-d80063 | Digital Health Technology Data Capture             | regulations/fda/dev-fda-part11-technical-controls.md | 151b3a71 |

## User Journeys (JNY)

| ID                           | Title                                     | Actor                             | File | Addresses |
| ---------------------------- | ----------------------------------------- | --------------------------------- | ---- | --------- |
| JNY-Epistaxis-Diary-01       | Recording a Nosebleed Event               | James (Patient)                   |      |           |
| JNY-Epistaxis-Diary-02       | Recording a Day Without Nosebleeds        | James (Patient)                   |      |           |
| JNY-Epistaxis-Diary-03       | Recording When Memory Is Uncertain        | Sarah (Patient)                   |      |           |
| JNY-Epistaxis-Diary-04       | Editing a Previous Record                 | James (Patient)                   |      |           |
| JNY-HHT-QoL-01               | Completing the Quality of Life Assessment | Sarah (Patient)                   |      |           |
| JNY-NOSE-HHT-01              | Completing the NOSE HHT Assessment        | Maria (Patient)                   |      |           |
| JNY-Portal-Linking-01        | Link New Patient                          | Dr. Sarah Mitchell (Investigator) |      |           |
| JNY-Portal-Linking-02        | Lost Mobile Phone Recovery                | Dr. Sarah Mitchell (Investigator) |      |           |
| JNY-Questionnaire-Session-01 | Deferring a Questionnaire                 | Maria (Patient)                   |      |           |
| JNY-Questionnaire-Session-02 | Session Expiry After Interruption         | Maria (Patient)                   |      |           |
| JNY-Study-Start-01           | Enrolling in a Clinical Trial             | Maria (Patient)                   |      |           |
