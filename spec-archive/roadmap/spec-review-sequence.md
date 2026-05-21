Spec Review Order

Phase 1: PRD Files (Product Requirements) - Read First

1.1 Foundation & Glossary

1. spec/README.md - Naming conventions and scope definitions
2. spec/requirements-format.md - Requirement format specification
3. spec/prd-glossary.md - Term definitions
4. spec/prd-epistaxis-terminology.md - Domain-specific terminology
5. spec/prd-standards.md - Reference standards

1.2 System & Architecture Core

6. spec/prd-system.md - Top-level system requirement (hub for all features)
7. spec/prd-clinical-trials.md - FDA 21 CFR Part 11, ALCOA+ (drives compliance)
8. spec/prd-architecture-multi-sponsor.md - Multi-sponsor architecture (referenced by 15+ files)

1.3 Security Stack (tight coupling - read in order)

9. spec/prd-security.md - Security architecture overview
10. spec/prd-security-data-classification.md - Data encryption, separation
11. spec/prd-security-RBAC.md - Role-Based Access Control
12. spec/prd-security-RLS.md - Row-Level Security policies

1.4 Data Architecture

13. spec/prd-database.md - Data persistence blueprint
14. spec/prd-event-sourcing-system.md - Event sourcing pattern (depends on database)
15. spec/prd-evidence-records.md - Evidence records feature

1.5 Application Components

16. spec/prd-diary-app.md - Mobile app requirements
17. spec/prd-diary-web.md - Web diary requirements
18. spec/prd-portal.md - Sponsor portal requirements

1.6 Supporting Requirements

19. spec/prd-services.md - External services
20. spec/prd-backup.md - Backup requirements
21. spec/prd-SLA.md - Service level requirements
22. spec/prd-devops.md - DevOps requirements
23. spec/prd-requirements-management.md - Traceability requirements

  ---
Phase 2: OPS Files (Operations) - Read Second

2.1 Security Operations (mirrors PRD security stack)

1. spec/ops-security.md - Security operations overview
2. spec/ops-security-authentication.md - Authentication configuration
3. spec/ops-security-RLS.md - RLS deployment
4. spec/ops-security-tamper-proofing.md - Tamper protection

2.2 Infrastructure & Database

5. spec/ops-system.md - System operations overview
6. spec/ops-infrastructure-as-code.md - IaC requirements
7. spec/ops-database-setup.md - Database provisioning
8. spec/ops-database-migration.md - Migration procedures

2.3 Deployment Pipeline

9. spec/ops-deployment.md - Deployment architecture
10. spec/ops-deployment-automation.md - Automation requirements
11. spec/ops-deployment-checklist.md - Deployment checklist
12. spec/ops-cicd.md - CI/CD pipeline requirements

2.4 Application Operations

13. spec/ops-portal.md - Portal deployment
14. spec/ops-artifact-management.md - Build artifact management
15. spec/ops-github-access-control.md - Repository access
16. spec/ops-data-custody-handoff.md - Data custody procedures

2.5 Maintenance & SLA

17. spec/ops-operations.md - Ongoing operations
18. spec/ops-SLA.md - SLA operations
19. spec/ops-requirements-management.md - Requirement tracking ops
20. spec/ops-monitoring-observability.md - Monitoring (leaf - read last)

  ---
Phase 3: DEV Files (Development) - Read Third

3.1 Development Practices

1. spec/dev-core-practices.md - Core development practices
2. spec/dev-principles-quick-reference.md - Quick reference
3. spec/dev-compliance-practices.md - FDA compliance in code
4. spec/dev-requirements-management.md - REQ traceability in code

3.2 Environment & Configuration

5. spec/dev-environment.md - Development environment
6. spec/dev-configuration.md - Configuration management
7. spec/dev-ai-claude.md - AI assistant guidelines

3.3 Security Implementation (mirrors PRD/OPS)

8. spec/dev-security.md - Security implementation
9. spec/dev-security-RLS.md - RLS implementation (d00019-d00026)

3.4 Data Implementation

10. spec/dev-database.md - Database implementation
11. spec/dev-database-reference.md - Database schema reference
12. spec/dev-data-models.md - Data models
13. spec/dev-data-models-jsonb.md - JSONB implementation
14. spec/dev-evidence-records.md - Evidence records implementation

3.5 Application Implementation

15. spec/dev-architecture-multi-sponsor.md - Multi-sponsor code architecture
16. spec/dev-app.md - Mobile app implementation
17. spec/dev-diary-web.md - Web diary implementation
18. spec/dev-portal.md - Portal implementation

3.6 Specialized Features (leaves)

19. spec/dev-marketplace-permissions.md - Marketplace permissions
20. spec/dev-marketplace-devcontainer-detection.md - Devcontainer detection

  ---
Phase 4: Architecture Decision Records

4.1 Foundational ADRs (read in order - chained dependencies)

1. docs/adr/README.md - ADR process
2. docs/adr/ADR-001-event-sourcing-pattern.md - Foundation for all data design
3. docs/adr/ADR-002-jsonb-flexible-schema.md - Depends on ADR-001
4. docs/adr/ADR-003-row-level-security.md - Depends on ADR-001, ADR-002
5. docs/adr/ADR-004-investigator-annotations.md - Depends on ADR-001, ADR-003
6. docs/adr/ADR-005-database-migration-strategy.md - Depends on ADR-001, ADR-003
7. docs/adr/ADR-008-timestamp-attestation.md - Standalone compliance

4.2 Infrastructure ADRs

8. docs/adr/ADR-006-docker-dev-environments.md - Dev environment decisions
9. docs/adr/ADR-007-multi-sponsor-build-reports.md - Build system decisions
10. docs/adr/ADR-009-pulumi-infrastructure-as-code.md - IaC decisions (depends on ADR-003, ADR-005)

  ---
Phase 5: Implementation & Operations Docs

5.1 Security & Secrets

1. docs/security/scanning-strategy.md - Security scanning approach
2. docs/security-secret-management.md - Secret management
3. docs/security/doppler-google-cloud.md - Doppler + GCP integration

5.2 Setup & Onboarding (dependency chain)

4. docs/development-prerequisites.md - Tool requirements
5. docs/setup-doppler.md - Doppler overview
6. docs/setup-doppler-project.md - Project setup
7. docs/setup-doppler-new-sponsor.md - Sponsor setup
8. docs/setup-doppler-new-dev.md - Developer setup
9. docs/setup-dev-environment-architecture.md - Dev environment design
10. docs/setup-dev-environment.md - Dev environment setup
11. docs/setup-team-onboarding.md - Team onboarding process

5.3 Git & CI/CD

12. docs/git-hooks-setup.md - Git hooks
13. docs/git-workflow.md - Git workflow
14. docs/cicd-setup-guide.md - CI/CD pipeline
15. docs/architecture-build-integrated-workflow.md - Build integration

5.4 GCP

16. docs/gcp/project-structure.md - GCP project organization
17. docs/gcp/cloud-sql-setup.md - Cloud SQL setup
18. docs/gcp/identity-platform-setup.md - Identity Platform
19. docs/gcp/cloud-run-deployment.md - Cloud Run deployment
20. docs/migration/doppler-vs-secret-manager.md - Secrets decision
21. docs/migration/supabase-to-gcp-migration-checklist.md - Migration tracker

5.5 Database Operations

22. docs/database-backup-setup.md - Backup configuration
23. docs/database-supabase-pre-deployment-audit.md - Pre-deployment audit
24. docs/database-environment-aware-archival-migration.md - Archival strategy
25. docs/ops-database-deployment.md - Database deployment
26. docs/ops-database-backup-enablement.md - Backup enablement

5.6 Operations & Monitoring (leaves - read last)

27. docs/ops-infrastructure-activation.md - Infrastructure activation
28. docs/ops-deployment-production-tagging-hotfix.md - Production tagging
29. docs/ops-dev-environment-maintenance.md - Dev environment maintenance
30. docs/ops-incident-response-runbook.md - Incident response
31. docs/ops-monitoring-sentry.md - Sentry monitoring
32. docs/ops-monitoring-better-uptime.md - Uptime monitoring

  ---
Phase 6: Reference & Domain Docs (Optional/As-Needed)

1. spec/INDEX.md - Requirements index (reference)
2. docs/README.md - Docs overview
3. docs/README-Onboarding.md - Onboarding guide
4. docs/README-Onboarding-QA.md - QA onboarding
5. docs/questionnaire-versioning.md - Questionnaire versioning
6. docs/service-level-agreement.md - SLA document
7. docs/compliance-gcp-verification.md - GCP compliance verification
8. docs/privacy-comprehensive-general.md - Privacy policy (comprehensive)
9. docs/privacy-concise-general.md - Privacy policy (concise)
10. docs/privacy-diary-addendum.md - Privacy addendum
11. docs/sponsor-summaries/evidence-records-overview.md - Evidence records overview
12. docs/cure-hht-history-study-consent.md - Study consent

  ---
Summary: Reading Order Rationale

| Phase | Focus     | Rationale                                              |
|-------|-----------|--------------------------------------------------------|
| 1     | PRD       | Understand WHAT we're building (business requirements) |
| 2     | OPS       | Understand HOW it's deployed and operated              |
| 3     | DEV       | Understand HOW it's implemented in code                |
| 4     | ADRs      | Understand WHY key architectural decisions were made   |
| 5     | Docs      | Practical guides for setup and operations              |
| 6     | Reference | Supporting documentation as needed                     |

Key dependency chains to preserve:
- Security: prd-security → prd-security-RBAC → prd-security-RLS (same for ops/dev)
- Data: prd-database → prd-event-sourcing → ADR-001 → ADR-002/003
- Architecture: prd-system → prd-architecture-multi-sponsor → all component specs
- Observability is always last (it's a leaf that monitors everything else)