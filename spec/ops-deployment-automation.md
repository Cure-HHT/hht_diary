# Deployment Automation Specification

**Version**: 2.0
**Audience**: Operations team
**Purpose**: Define automated deployment procedures for all environments
**Last Updated**: 2025-12-28
**Status**: Ready to activate (workflows created but not triggered)

---

## Requirements

# REQ-o00043: Automated Deployment Pipeline

**Level**: Ops | **Status**: Draft | **Implements**: p00048

## Rationale

This requirement establishes the automated deployment pipeline infrastructure for the clinical trial platform, ensuring controlled, traceable, and safe delivery of software changes across development, staging, and production environments. Automated deployment pipelines reduce human error, enforce consistency, and maintain comprehensive audit trails required for FDA 21 CFR Part 11 compliance. The requirement balances automation for efficiency with manual controls for safety-critical production deployments. Different environments have different approval requirements reflecting their risk profiles: development deployments can be fully automated, while production deployments require human oversight and validation. Safety controls such as deployment windows, rate limiting, and automatic rollback mechanisms protect against deployment-related incidents in production. The audit trail requirements ensure regulatory compliance by maintaining tamper-evident records of all deployment activities, approvals, and outcomes for the required retention period.

## Assertions

A. The system SHALL automatically trigger deployment to the development environment on merge to the main branch.
B. The system SHALL require manual approval before deploying to the staging environment.
C. The system SHALL require manual approval before deploying to the production environment.
D. The system SHALL require smoke tests to pass before deploying to the production environment.
E. The system SHALL execute build validation including lint, type check, and tests before deployment.
F. The system SHALL execute database migrations with a rollback plan during deployment.
G. The system SHALL deploy the application to Cloud Run as part of the deployment process.
H. The system SHALL execute smoke tests after deployment.
I. The system SHALL perform automated rollback on deployment failure.
J. The system SHALL restrict production deployments to business hours only.
K. The system SHALL enforce a rate limit of maximum 1 production deployment per 4 hours.
L. The system SHALL execute automated health checks post-deployment.
M. The system SHALL log all deployments with timestamp, deployer identity, and commit SHA.
N. The system SHALL record all approvals with approver identity.
O. The system SHALL record deployment duration and outcome for each deployment.
P. The system SHALL maintain deployment audit trails in compliance with FDA 21 CFR Part 11.
Q. The system SHALL maintain deployment audit trails for a minimum of 7 years.
R. The system SHALL complete development environment deployments within 10 minutes.
S. The system SHALL complete staging environment deployments within 15 minutes.
T. The system SHALL complete production environment deployments within 20 minutes.

*End* *Automated Deployment Pipeline* | **Hash**: e74d24c7
---

# REQ-o00044: Database Migration Automation

**Level**: Ops | **Status**: Draft | **Implements**: p00048

## Rationale

This requirement establishes automated database migration processes to ensure safe, traceable, and reversible schema changes in a production clinical trial environment. Automated migrations reduce human error during deployments while maintaining strict audit trails required for FDA 21 CFR Part 11 compliance. The requirement emphasizes safety through transactional execution, mandatory rollback scripts, pre-migration backups, and comprehensive logging. Performance monitoring ensures migrations complete within acceptable timeframes to minimize system downtime. Validation through IQ/OQ/PQ protocols ensures the migration framework meets operational and regulatory standards.

## Assertions

A. The system SHALL apply migrations in sequential numbered order.
B. The system SHALL execute migrations transactionally as all-or-nothing operations.
C. The system SHALL automatically verify migration execution after completion.
D. The system SHALL validate database schema after migration execution.
E. Every migration SHALL have a corresponding rollback script.
F. The system SHALL test rollback scripts before production deployment.
G. The system SHALL automatically execute rollback on migration failure.
H. The system SHALL provide a manual rollback command.
I. The system SHALL provide dry-run mode for migration validation.
J. The system SHALL create database backup before production migrations.
K. The system SHALL implement lock timeout to prevent hanging migrations.
L. The system SHALL alert when migration duration exceeds 5 minutes.
M. The system SHALL log migration execution with timestamp, user, and duration.
N. The system SHALL capture pre-migration schema snapshots.
O. The system SHALL capture post-migration schema snapshots.
P. The system SHALL log rollback events.
Q. Migration audit records SHALL comply with FDA 21 CFR Part 11.
R. The migration framework SHALL integrate Cloud SQL migrations via pgmigrate.
S. The system SHALL require rollback scripts for all migrations.
T. Typical migrations SHALL complete within 5 minutes.

*End* *Database Migration Automation* | **Hash**: 52d9a6a1
---

## Architecture

### Deployment Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Developer Workflow                                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Local Development                                              │
│  ┌─────────────┐                                                │
│  │ Code Change │                                                │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐     ┌──────────────┐                          │
│  │ Git Commit  │────▶│ Pre-commit   │                          │
│  └──────┬──────┘     │ Hooks        │                          │
│         │            └──────────────┘                          │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │ Git Push    │                                                │
│  └──────┬──────┘                                                │
│         │                                                       │
└─────────┼─────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ CI/CD Pipeline (GitHub Actions)                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Build & Test Stage                       │                  │
│  │ ┌────────────┐  ┌────────────┐           │                  │
│  │ │ Lint       │  │ Type Check │           │                  │
│  │ └─────┬──────┘  └─────┬──────┘           │                  │
│  │       │               │                  │                  │
│  │       └───────┬───────┘                  │                  │
│  │               ▼                          │                  │
│  │       ┌────────────┐                     │                  │
│  │       │ Unit Tests │                     │                  │
│  │       └─────┬──────┘                     │                  │
│  └─────────────┼──────────────────────────┘                  │
│                │                                                │
│                ▼                                                │
│  ┌──────────────────────────────────────────┐                  │
│  │ Development Deployment                    │                  │
│  │ (Automatic on main)                      │                  │
│  │                                           │                  │
│  │ ┌─────────────┐   ┌──────────────┐       │                  │
│  │ │ DB Migrate  │──▶│ Deploy App   │       │                  │
│  │ └─────────────┘   └──────┬───────┘       │                  │
│  │                          │               │                  │
│  │                          ▼               │                  │
│  │                   ┌──────────────┐       │                  │
│  │                   │ Smoke Tests  │       │                  │
│  │                   └──────────────┘       │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
│                ┌─ PASS ─▶ Notify Success                       │
│                │                                                │
│                └─ FAIL ─▶ Auto Rollback ─▶ Notify Failure      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Staging Deployment (Manual Trigger)                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐                                           │
│  │ Manual Approval  │ ◀── QA Lead                              │
│  └────────┬─────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  ┌──────────────────────────────────────────┐                  │
│  │ ┌─────────────┐   ┌──────────────┐       │                  │
│  │ │ DB Migrate  │──▶│ Deploy App   │       │                  │
│  │ └─────────────┘   └──────┬───────┘       │                  │
│  │                          │               │                  │
│  │                          ▼               │                  │
│  │                   ┌──────────────┐       │                  │
│  │                   │ Smoke Tests  │       │                  │
│  │                   └──────────────┘       │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
│                ┌─ PASS ─▶ Ready for Production                 │
│                │                                                │
│                └─ FAIL ─▶ Auto Rollback ─▶ Notify QA           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ Production Deployment (Manual Trigger + Approval)              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐                                           │
│  │ Manual Trigger   │ ◀── Deployment Manager                   │
│  └────────┬─────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  ┌──────────────────┐                                           │
│  │ Approval Gate    │ ◀── Tech Lead + QA Lead                  │
│  └────────┬─────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  ┌──────────────────────────────────────────┐                  │
│  │ Pre-deployment Checks                    │                  │
│  │ • Deployment window (business hours)     │                  │
│  │ • Rate limit (1 per 4 hours)             │                  │
│  │ • Smoke tests passed on staging          │                  │
│  └────────┬─────────────────────────────────┘                  │
│           │                                                     │
│           ▼                                                     │
│  ┌──────────────────────────────────────────┐                  │
│  │ ┌─────────────┐   ┌──────────────┐       │                  │
│  │ │ DB Backup   │──▶│ DB Migrate   │       │                  │
│  │ └─────────────┘   └──────┬───────┘       │                  │
│  │                          │               │                  │
│  │                          ▼               │                  │
│  │                   ┌──────────────┐       │                  │
│  │                   │ Deploy App   │       │                  │
│  │                   └──────┬───────┘       │                  │
│  │                          │               │                  │
│  │                          ▼               │                  │
│  │                   ┌──────────────┐       │                  │
│  │                   │ Smoke Tests  │       │                  │
│  │                   └──────────────┘       │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
│                ┌─ PASS ─▶ Deployment Complete ─▶ Notify Team   │
│                │                                                │
│                └─ FAIL ─▶ Auto Rollback ─▶ Incident Response   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Component | Technology | Purpose |
| --- | --- | --- |
| **CI/CD Platform** | GitHub Actions | Workflow orchestration |
| **Migration Tool** | dbmate + Cloud SQL Proxy | Database migrations |
| **Secrets Management** | Doppler + GCP Secret Manager | Secure credential injection |
| **Infrastructure as Code** | Pulumi (TypeScript) | Infrastructure provisioning |
| **Container Registry** | GCP Artifact Registry | Docker image storage |
| **Approval System** | GitHub Environments | Manual approval gates |

> **See**: ops-infrastructure-as-code.md for detailed Pulumi component definitions

---

## Workflow Definitions

### Development Deployment Workflow

**File**: `.github/workflows/deploy-development.yml`

**Triggers**:
- Push to `main` branch (automatic)

**Steps**:
1. Checkout code
2. Set up environment (Dart, gcloud CLI, Cloud SQL Proxy, Pulumi)
3. Authenticate to GCP via Workload Identity Federation
4. Inject secrets from Doppler
5. Run linting and type checking
6. Run unit tests
7. Execute database migrations via Cloud SQL Proxy (with rollback on failure)
8. Build and push container to Artifact Registry
9. Deploy via Pulumi (`pulumi up` for Cloud Run + infrastructure)
10. Run smoke tests
11. Notify team (Slack/email)

**Rollback**: Automatic on any step failure (Pulumi rollback via `pulumi refresh`)

**SLA**: Complete within 10 minutes

---

### Staging Deployment Workflow

**File**: `.github/workflows/deploy-staging.yml`

**Triggers**:
- Manual workflow dispatch (requires QA Lead approval)

**Steps**:
1. Await manual approval
2. Checkout code
3. Set up environment (Dart, gcloud CLI, Cloud SQL Proxy, Pulumi)
4. Authenticate to GCP via Workload Identity Federation
5. Inject secrets from Doppler
6. Run full test suite
7. Execute database migrations via Cloud SQL Proxy (with backup and rollback)
8. Build and push container to Artifact Registry
9. Preview infrastructure changes (`pulumi preview`)
10. Deploy via Pulumi (`pulumi up`)
11. Run smoke tests
12. Run integration tests
13. Notify QA team

**Rollback**: Automatic on any step failure (Pulumi rollback via `pulumi refresh`)

**SLA**: Complete within 15 minutes

---

### Production Deployment Workflow

**File**: `.github/workflows/deploy-production.yml`

**Triggers**:
- Manual workflow dispatch (requires Tech Lead + QA Lead approval)

**Pre-deployment Checks**:
- Deployment window: Monday-Thursday, 9 AM - 3 PM EST
- Rate limit: Maximum 1 deployment per 4 hours
- Staging smoke tests: Must have passed within last 24 hours
- Open incidents: No critical incidents in last 24 hours

**Steps**:
1. Await manual approval (2 reviewers required)
2. Verify pre-deployment checks
3. Checkout code
4. Set up environment (Dart, gcloud CLI, Cloud SQL Proxy, Pulumi)
5. Authenticate to GCP via Workload Identity Federation
6. Inject secrets from Doppler
7. Create database backup via Cloud SQL (7-year retention)
8. Execute database migrations via Cloud SQL Proxy (with rollback plan)
9. Build and push container to Artifact Registry
10. Preview infrastructure changes (`pulumi preview --expect-no-changes` or with changes)
11. Deploy via Pulumi (`pulumi up`) with traffic management
12. Run smoke tests
13. Run health checks
14. Monitor for 15 minutes post-deployment
15. Notify team

**Rollback**: Automatic on any step failure (Pulumi rollback + incident response)

**SLA**: Complete within 20 minutes

---

## Smoke Tests

### Required Smoke Tests

All deployments SHALL execute the following smoke tests:

1. **Database Connectivity**:
   - Connect to database
   - Execute simple query
   - Verify response time <2 seconds

2. **API Availability**:
   - Health check endpoint returns 200
   - Authentication endpoint accepts valid credentials
   - Sample CRUD operation succeeds

3. **Critical Features**:
   - User can log in
   - User can create a new diary entry
   - Audit trail records are created

4. **Data Integrity**:
   - Database schema matches expected version
   - Required tables exist
   - Required functions/triggers exist

**Implementation**: See `tools/testing/smoke-tests/`

**Execution Time**: <3 minutes for all tests

---

## Rollback Procedures

### Automatic Rollback

Triggered automatically on:
- Smoke test failure
- Migration failure
- Pulumi deployment failure
- Health check failure within 15 minutes post-deployment

**Procedure**:
1. Identify last known good state (previous Pulumi stack version)
2. Execute database rollback script
3. Revert infrastructure via Pulumi:
   - `pulumi stack history` to find previous version
   - `git revert <commit>` to revert infrastructure code
   - `pulumi up` to apply rollback
4. Verify rollback with smoke tests
5. Notify team via Slack/email
6. Create incident ticket for investigation

### Manual Rollback

**Command**:
```bash
gh workflow run rollback.yml \
  --ref main \
  -f environment=production \
  -f target_version=v1.2.3
```

**Requirements**:
- Tech Lead approval (production only)
- Reason documented in incident ticket

---

## Deployment Windows

### Development
- **Window**: 24/7 (no restrictions)
- **Approval**: None required
- **Rate Limit**: None

### Staging
- **Window**: 24/7
- **Approval**: QA Lead
- **Rate Limit**: None

### Production
- **Window**: Monday-Thursday, 9 AM - 3 PM EST (avoid Fridays)
- **Approval**: Tech Lead + QA Lead
- **Rate Limit**: Maximum 1 deployment per 4 hours
- **Blackout Periods**:
  - Major holidays
  - Planned maintenance windows
  - Active incidents

---

## Audit Trail

### Required Audit Information

Every deployment SHALL log:

1. **Deployment Metadata**:
   - Timestamp (UTC)
   - Deployer identity (GitHub username)
   - Environment (dev/staging/production)
   - Commit SHA and branch
   - Version number

2. **Approval Records** (staging/production):
   - Approver identity
   - Approval timestamp
   - Comments/notes

3. **Execution Details**:
   - Deployment start time
   - Deployment end time
   - Duration
   - Outcome (success/failure/rollback)

4. **Migration Details**:
   - Migrations executed (list)
   - Migration duration
   - Pre/post-migration schema versions

5. **Test Results**:
   - Smoke test outcomes
   - Health check results
   - Any failures or warnings

**Storage**: Deployment logs stored in Cloud Storage (Archive class) with 7-year retention

**Access**: Auditors can query deployment history via GitHub Actions UI or CLI

---

## Activation Instructions

To activate deployment automation:

1. **Configure GitHub Environments**:
   ```bash
   # In GitHub repo settings, create environments:
   # - development (auto-deploy on push to main)
   # - staging (manual trigger + QA Lead approval)
   # - production (manual trigger + 2 approvals, deployment window)
   ```

2. **Set up Secrets and Workload Identity**:
   ```bash
   # Configure Workload Identity Federation for GitHub Actions
   # (see ops-infrastructure-as-code.md for Pulumi setup)

   # Add to GitHub repository secrets:
   gh secret set PULUMI_ACCESS_TOKEN --body "<pulumi-cloud-token>"
   gh secret set DOPPLER_TOKEN_DEV --body "<dev-token>"
   gh secret set DOPPLER_TOKEN_STAGING --body "<staging-token>"
   gh secret set DOPPLER_TOKEN_PROD --body "<prod-token>"
   gh secret set GCP_PROJECT_ID --body "<project-id>"
   gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "<provider>"
   gh secret set GCP_SERVICE_ACCOUNT --body "<service-account-email>"
   ```

3. **Enable Workflows**:
   - Workflows are ready but not triggered until environments are configured
   - Development: Activates on next push to `main`
   - Staging: Activate via manual dispatch
   - Production: Activate via manual dispatch with approvals

4. **Test Deployment**:
   ```bash
   # Test in development first:
   git checkout main
   git pull
   # Make small change, commit, push
   # Verify deployment workflow runs automatically
   ```

See `docs/ops-infrastructure-activation.md` for complete activation procedures.

---

## Validation Procedures

### Installation Qualification (IQ)

**Objective**: Verify deployment workflows are correctly installed

**Procedure**:
1. Verify workflow files exist in `.github/workflows/`
2. Validate workflow syntax with `act --list` (local testing)
3. Verify GitHub environments configured
4. Verify secrets are set correctly
5. Document installation in validation log

**Acceptance**: All workflow files present and syntactically valid

---

### Operational Qualification (OQ)

**Objective**: Verify deployment workflows execute correctly

**Procedure**:
1. Execute test deployment to development
2. Verify all steps execute in correct order
3. Test rollback procedure (induce failure, verify auto-rollback)
4. Test manual approval gates (staging/production)
5. Verify audit trail is created correctly
6. Document results in validation log

**Acceptance**: All deployments execute successfully, rollback works correctly

---

### Performance Qualification (PQ)

**Objective**: Verify deployment performance meets SLAs

**Procedure**:
1. Measure deployment duration (10 deployments per environment)
2. Verify SLAs met:
   - Development: <10 minutes
   - Staging: <15 minutes
   - Production: <20 minutes
3. Measure rollback duration (5 rollback tests per environment)
4. Verify rollback completes within 5 minutes
5. Document results in validation log

**Acceptance**: 95% of deployments meet SLA, 100% of rollbacks complete within 5 minutes

---

## Troubleshooting

### Deployment Fails with "Migration Error"

**Symptoms**: Database migration fails during deployment

**Diagnosis**:
1. Check migration logs in GitHub Actions
2. Verify database connectivity
3. Check for conflicting schema changes

**Resolution**:
1. Review migration script for errors
2. Test migration in development environment first
3. If necessary, create rollback migration and re-deploy

---

### Deployment Stuck on "Awaiting Approval"

**Symptoms**: Deployment workflow paused at approval gate

**Diagnosis**:
1. Check GitHub environment settings
2. Verify approvers are configured correctly
3. Check for pending approvals in GitHub UI

**Resolution**:
1. Contact required approvers
2. If urgent, escalate to Tech Lead
3. Once approved, workflow continues automatically

---

### Smoke Tests Fail Post-Deployment

**Symptoms**: Deployment completes but smoke tests fail

**Diagnosis**:
1. Check smoke test logs
2. Verify application is responding
3. Check database connectivity

**Resolution**:
1. Automatic rollback should trigger
2. If rollback fails, execute manual rollback
3. Investigate issue in development environment
4. Fix and redeploy

---

## References

- INFRASTRUCTURE_GAP_ANALYSIS.md - Phase 1 implementation plan
- spec/ops-infrastructure-as-code.md - Pulumi IaC specification
- spec/ops-deployment.md - Deployment operations guide
- .github/workflows/ - Actual workflow definitions
- tools/testing/smoke-tests/ - Smoke test implementations
- docs/ops/incident-response-runbook.md - Incident response procedures

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-27 | 1.0 | Claude | Initial specification (ready to activate) |
| 2025-12-28 | 2.0 | Claude | Migration from Terraform to Pulumi for infrastructure provisioning |
