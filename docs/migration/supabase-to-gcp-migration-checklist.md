# Supabase to GCP Migration Checklist

**Version**: 1.0
**Status**: In Progress
**Created**: 2025-11-24
**Last Updated**: 2025-11-24 (Session 2)

> **Purpose**: Track migration from Supabase backend to Google Cloud Platform (CloudSQL Postgres, Cloud Run, IAM) for enhanced compliance with HIPAA, GDPR, and FDA 21 CFR Part 11 requirements.

---

## Executive Summary

This document tracks the migration of the Clinical Trial Diary Platform from Supabase to Google Cloud Platform. The migration is driven by compliance requirements that are better served by GCP's healthcare-specific certifications and controls.

### Migration Overview

| Component | Current (Supabase) | Target (GCP) |
| --- | --- | --- |
| Database | Supabase PostgreSQL | Cloud SQL (PostgreSQL) |
| Auth | Supabase Auth | Identity Platform / Firebase Auth |
| Backend | Supabase Edge Functions | Cloud Run (Dart server) |
| Storage | Supabase Storage | Cloud Storage |
| Secrets | Doppler | Doppler + Secret Manager (hybrid) |
| Monitoring | Sentry + Better Uptime | Cloud Logging + Cloud Monitoring |
| Container Registry | GitHub Packages | Artifact Registry |
| Infrastructure | Terraform (Supabase provider) | Terraform (GCP provider) |

---

## Migration Checklist

### Phase 1: Specification Updates

#### PRD Files (No code - requirements only)

These files define WHAT the system does and should NOT contain code examples. They may need updates to:
- Replace "Supabase" with "GCP" in architecture descriptions
- Update compliance certification references
- Update multi-sponsor isolation model descriptions

| File | Status | Notes |
| --- | --- | --- |
| `prd-architecture-multi-sponsor.md` | [x] **DONE** | No Supabase references found |
| `prd-database.md` | [x] **DONE** | No Supabase references found |
| `prd-security.md` | [x] **DONE** | No Supabase references found |
| `prd-security-data-classification.md` | [x] **DONE** | No Supabase references found |
| `prd-security-RBAC.md` | [x] **DONE** | Updated to GCP project isolation |
| `prd-security-RLS.md` | [x] **DONE** | PostgreSQL RLS unchanged (no Supabase refs) |
| `prd-event-sourcing-system.md` | [x] **DONE** | PostgreSQL core (no Supabase refs) |
| `prd-portal.md` | [x] **DONE** | Updated database reference |
| `prd-clinical-trials.md` | [x] **DONE** | No Supabase references found |

#### DEV Files (Implementation guides with code)

| File | Status | Notes |
| --- | --- | --- |
| `dev-app.md` | [x] **DONE** | Updated to GCP backend references |
| `dev-architecture-multi-sponsor.md` | [x] **DONE** | GCP project structure |
| `dev-compliance-practices.md` | [x] **DONE** | GCP compliance patterns |
| `dev-configuration.md` | [x] **DONE** | Replace Supabase env vars with GCP |
| `dev-core-practices.md` | [x] **DONE** | GCP project references |
| `dev-data-models.md` | [x] **DONE** | No Supabase references found |
| `dev-data-models-jsonb.md` | [x] **DONE** | No Supabase references found |
| `dev-database.md` | [x] **DONE** | Cloud SQL connection patterns, Dart server |
| `dev-database-reference.md` | [x] **DONE** | Updated to Dart/Firebase Auth examples |
| `dev-environment.md` | [x] **DONE** | GCP SDK setup |
| `dev-portal.md` | [x] **DONE** | Cloud Run backend, Firebase Auth, application-set RLS |
| `dev-security.md` | [x] **DONE** | GCP IAM + Identity Platform |
| `dev-security-RLS.md` | [x] **DONE** | Updated to application-set session variables |

#### OPS Files (Deployment and operations)

| File | Status | Notes |
| --- | --- | --- |
| `ops-artifact-management.md` | [x] **DONE** | GCP Artifact Registry |
| `ops-cicd.md` | [x] **DONE** | Minimal changes (validation focused) |
| `ops-database-migration.md` | [x] **DONE** | Cloud SQL migration tooling |
| `ops-database-setup.md` | [x] **DONE** | Complete rewrite for Cloud SQL |
| `ops-deployment.md` | [x] **DONE** | Cloud Run deployment |
| `ops-deployment-automation.md` | [x] **DONE** | Updated for Cloud Run + Artifact Registry |
| `ops-deployment-checklist.md` | [x] **DONE** | GCP-specific checklist |
| `ops-github-access-control.md` | [x] **DONE** | Updated secrets and incident response |
| `ops-infrastructure-as-code.md` | [x] **DONE** | Terraform GCP modules |
| `ops-monitoring-observability.md` | [x] **DONE** | Cloud Logging/Monitoring (removed Sentry) |
| `ops-operations.md` | [x] **DONE** | GCP Console operations |
| `ops-portal.md` | [x] **DONE** | Cloud Run portal deployment |
| `ops-security.md` | [x] **DONE** | GCP security controls |
| `ops-security-authentication.md` | [x] **DONE** | Identity Platform setup (version 2.0) |
| `ops-security-RLS.md` | [x] **DONE** | Updated to Cloud SQL references |
| `ops-security-tamper-proofing.md` | [x] **DONE** | Updated to GCP stack |
| `ops-requirements-management.md` | [x] **DONE** | No Supabase references found |

---

### Phase 2: New Documentation Required

| Document | Status | Purpose |
| --- | --- | --- |
| `docs/migration/doppler-vs-secret-manager.md` | [x] **DONE** | Compare Doppler to GCP Secret Manager |
| `docs/gcp/project-structure.md` | [x] **DONE** | GCP project organization |
| `docs/gcp/cloud-sql-setup.md` | [x] **DONE** | Cloud SQL provisioning guide |
| `docs/gcp/cloud-run-deployment.md` | [x] **DONE** | Dart server deployment |
| `docs/gcp/identity-platform-setup.md` | [x] **DONE** | Authentication setup |
| `infrastructure/terraform/modules/gcp-sponsor-project/` | [x] **DONE** | Terraform GCP modules |

---

## Detailed Migration Notes by Area

### 1. Database: Supabase PostgreSQL → Cloud SQL

**Current State**:
- Supabase managed PostgreSQL
- Connection via Supabase client SDK
- RLS policies via JWT claims from Supabase Auth

**Target State**:
- Cloud SQL for PostgreSQL (with Private IP)
- Connection via Cloud SQL Proxy or direct (VPC)
- RLS policies via application-set session variables

**Migration Tasks**:
- [ ] Create Cloud SQL instance per sponsor/environment
- [ ] Configure Private IP and VPC connector
- [ ] Set up Cloud SQL Proxy for local development
- [ ] Migrate schema (PostgreSQL-compatible, minimal changes)
- [ ] Update RLS functions to use application-set claims
- [ ] Configure automated backups with Cloud SQL
- [ ] Set up point-in-time recovery (PITR)

**Spec Files to Update**:
- `ops-database-setup.md` - Complete rewrite
- `dev-database.md` - Connection patterns
- `ops-database-migration.md` - Cloud SQL migration tooling

### 2. Authentication: Supabase Auth → Identity Platform

**Current State**:
- Supabase Auth with email/OAuth
- JWT tokens with custom claims via hooks
- MFA via Supabase

**Target State**:
- Google Identity Platform (Firebase Auth)
- Custom claims via Cloud Functions
- MFA via Identity Platform

**Migration Tasks**:
- [ ] Provision Identity Platform per sponsor
- [ ] Configure OAuth providers (Google, Apple, Microsoft)
- [ ] Implement custom claims function (Cloud Functions)
- [ ] Set up MFA configuration
- [ ] Migrate user accounts (optional - may restart)
- [ ] Update Flutter app to use Firebase Auth SDK

**Spec Files to Update**:
- `ops-security-authentication.md` - Identity Platform setup
- `dev-security.md` - Auth implementation
- `ops-security.md` - Auth configuration

### 3. Backend: Edge Functions → Cloud Run

**Current State**:
- Supabase Edge Functions (Deno)
- Direct database access via Supabase client

**Target State**:
- Dart server on Cloud Run
- Database access via Cloud SQL connector
- API Gateway or Cloud Endpoints (optional)

**Migration Tasks**:
- [ ] Create Dart server application structure
- [ ] Implement database connection layer
- [ ] Implement authentication middleware
- [ ] Create Dockerfile for Cloud Run
- [ ] Configure Cloud Run service per sponsor
- [ ] Set up VPC connector for Cloud SQL access
- [ ] Configure auto-scaling policies

**Spec Files to Update**:
- `ops-deployment.md` - Cloud Run deployment
- `dev-portal.md` - Backend implementation
- `ops-portal.md` - Portal operations

### 4. Secrets Management: Doppler vs Secret Manager

**Current State**:
- Doppler for all secrets
- `doppler run -- <command>` pattern
- Environment isolation via Doppler projects

**Decision**: ✅ **Hybrid Approach** (decided 2025-11-25)
- **Dev/Test/UAT**: Continue using Doppler (excellent developer experience)
- **Production**: Use Google Secret Manager (GCP-native, IAM integration)

**Comparison Document**: See `docs/migration/doppler-vs-secret-manager.md`

**Implementation**:
1. Development uses `doppler run -- <command>` (unchanged)
2. CI/CD syncs Doppler → Secret Manager for production secrets
3. Cloud Run reads secrets from Secret Manager via IAM
4. Terraform manages Secret Manager resources

**Migration Tasks**:
- [x] Write comparison document
- [x] Make decision on approach (Hybrid)
- [ ] Create Secret Manager secrets via Terraform
- [ ] Update CI/CD to sync Doppler → Secret Manager
- [ ] Configure Cloud Run to use Secret Manager
- [ ] Update secret management documentation

### 5. Monitoring: Sentry/Better Uptime → Cloud Operations

**Current State**:
- Sentry for error tracking (NOT OpenTelemetry compliant)
- Better Uptime for health checks
- Supabase dashboard for database metrics

**Target State**:
- Cloud Logging for centralized logs
- Cloud Monitoring for metrics/alerts
- Cloud Trace for distributed tracing (OpenTelemetry)
- Cloud Error Reporting (optional, replaces Sentry)

**Decision**: Remove Sentry (not OpenTelemetry compliant per user request)

**Migration Tasks**:
- [ ] Configure Cloud Logging export
- [ ] Set up Cloud Monitoring dashboards
- [ ] Configure alert policies
- [ ] Implement OpenTelemetry in Dart server
- [ ] Configure uptime checks
- [ ] Remove Sentry references from documentation

**Spec Files to Update**:
- `ops-monitoring-observability.md` - Complete rewrite

### 6. Container Registry: GitHub Packages → Artifact Registry

**Current State**:
- GitHub Container Registry (ghcr.io)
- GitHub Packages for dependencies

**Target State**:
- GCP Artifact Registry
- Integrated with Cloud Build and Cloud Run

**Advantages of Artifact Registry**:
- Native GCP integration
- Vulnerability scanning
- IAM-based access control
- Better compliance documentation

**Migration Tasks**:
- [ ] Create Artifact Registry repositories
- [ ] Update CI/CD to push to Artifact Registry
- [ ] Configure vulnerability scanning
- [ ] Update deployment scripts

**Spec Files to Update**:
- `ops-artifact-management.md` - Artifact Registry setup

### 7. Infrastructure as Code: Terraform

**Current State**:
- Terraform with Supabase provider
- S3 backend for state

**Target State**:
- Terraform with Google provider
- GCS backend for state (or keep S3)

**Migration Tasks**:
- [ ] Create GCP Terraform modules
- [ ] Module: GCP Project setup
- [ ] Module: Cloud SQL instance
- [ ] Module: Cloud Run service
- [ ] Module: VPC and networking
- [ ] Module: Identity Platform
- [ ] Module: Artifact Registry
- [ ] Update state backend configuration

**Spec Files to Update**:
- `ops-infrastructure-as-code.md` - GCP provider

---

## GCP Compliance Advantages

| Requirement | Supabase | GCP |
| --- | --- | --- |
| HIPAA BAA | Limited support | Full BAA available |
| GDPR | Compliant | Compliant + data residency |
| FDA 21 CFR Part 11 | Self-managed | Managed + certifications |
| SOC 2 Type II | Via AWS | Native GCP certification |
| ISO 27001 | Via AWS | Native GCP certification |
| FedRAMP | No | Available (GovCloud) |

---

## GCP Service Mapping

| Supabase Feature | GCP Equivalent | Notes |
| --- | --- | --- |
| PostgreSQL | Cloud SQL | Direct PostgreSQL compatibility |
| Auth | Identity Platform | Firebase Auth SDK |
| Edge Functions | Cloud Run | Containerized Dart server |
| Storage | Cloud Storage | Object storage |
| Realtime | Pub/Sub + Firestore | Or implement WebSockets in Cloud Run |
| Dashboard | Cloud Console | GCP management interface |
| CLI | gcloud CLI | GCP command line |
| REST API | Cloud Endpoints | API management |

---

## Timeline Estimation

| Phase | Description | Duration |
| --- | --- | --- |
| 1 | Specification updates | 2-3 days |
| 2 | New documentation | 1-2 days |
| 3 | Terraform modules | 3-5 days |
| 4 | Cloud SQL setup | 1-2 days |
| 5 | Identity Platform | 2-3 days |
| 6 | Cloud Run server | 3-5 days |
| 7 | CI/CD updates | 2-3 days |
| 8 | Testing & validation | 3-5 days |
| **Total** | | **17-28 days** |

---

## Rollback Plan

If critical issues arise during migration:

1. **Database**: Keep Supabase project active during migration
2. **Auth**: Maintain parallel auth systems temporarily
3. **Config**: Feature flag to switch backends
4. **DNS**: Route traffic via load balancer for instant switch

---

## References

- [GCP Healthcare Solutions](https://cloud.google.com/solutions/healthcare)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Identity Platform Documentation](https://cloud.google.com/identity-platform/docs)
- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

---

## Change Log

| Date | Version | Changes | Author |
| --- | --- | --- | --- |
| 2025-11-24 | 1.0 | Initial migration checklist | Claude |
| 2025-11-24 | 1.1 | Completed dev-database.md, dev-security.md | Claude |
| 2025-11-24 | 1.2 | Completed dev-environment.md, ops-database-migration.md, ops-portal.md | Claude |
| 2025-11-24 | 1.3 | Completed dev-architecture-multi-sponsor.md, ops-operations.md | Claude |
| 2025-11-24 | 1.4 | Completed dev-core-practices.md, dev-compliance-practices.md, ops-deployment-checklist.md, prd-portal.md | Claude |
| 2025-11-24 | 1.5 | Completed dev-app.md, ops-deployment-automation.md, dev-database-reference.md | Claude |
| 2025-11-24 | 1.6 | Completed RLS files, prd-security-RBAC.md, ops-github-access-control.md, ops-security-tamper-proofing.md, INDEX.md, requirements-format.md | Claude |
| 2025-11-24 | 1.7 | Completed dev-portal.md - comprehensive rewrite (Firebase Auth, Cloud Run deployment, application-set RLS policies) | Claude |
| 2025-11-24 | 1.8 | **Phase 1 Complete**: All PRD, DEV, and OPS spec files verified - no remaining Supabase references (except historical changelog entries) | Claude |
| 2025-11-25 | 2.0 | **Phase 2 Complete**: Created GCP documentation (project-structure, cloud-sql-setup, cloud-run-deployment, identity-platform-setup) and Terraform gcp-sponsor-project module. Secrets decision: Hybrid (Doppler dev/test/uat, Secret Manager prod) | Claude |
