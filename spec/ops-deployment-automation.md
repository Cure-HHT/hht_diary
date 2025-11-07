# Deployment Automation Specification

**Audience**: Operations team
**Purpose**: Define automated deployment procedures for all environments
**Status**: Ready to activate (workflows created but not triggered)

---

## Requirements

# REQ-o00043: Automated Deployment Pipeline

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL provide automated deployment pipelines that:

1. **Trigger Conditions**:
   - Development: Automatic on merge to `main` branch
   - Staging: Manual approval required
   - Production: Manual approval + smoke tests passed

2. **Deployment Steps**:
   - Build validation (lint, type check, tests)
   - Database migration execution with rollback plan
   - Application deployment to Supabase
   - Smoke test execution
   - Automated rollback on failure

3. **Safety Controls**:
   - Deployment windows (production: business hours only)
   - Rate limiting (max 1 production deployment per 4 hours)
   - Manual approval gates for production
   - Automated health checks post-deployment
   - Automatic rollback on failure

4. **Audit Trail**:
   - All deployments logged with timestamp, deployer, commit SHA
   - Approval records with approver identity
   - Deployment duration and outcome
   - FDA 21 CFR Part 11 compliant audit trail

**Validation**:
- **IQ**: Verify workflow files exist and are syntactically correct
- **OQ**: Verify deployments execute correctly in each environment
- **PQ**: Verify deployment completes within SLA (dev: 10 min, staging: 15 min, production: 20 min)

**Acceptance Criteria**:
- ✅ Deployment pipeline defined in GitHub Actions
- ✅ Manual approval gates configured for production
- ✅ Automated rollback on failure
- ✅ Deployment audit trail maintained for 7 years
- ✅ Smoke tests execute post-deployment
- ✅ Deployment windows enforced for production

*End* *Automated Deployment Pipeline* | **Hash**: e82a4842
---

# REQ-o00044: Database Migration Automation

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL automate database migrations with the following capabilities:

1. **Migration Execution**:
   - Migrations applied in order (numbered sequentially)
   - Transactional execution (all-or-nothing)
   - Automatic verification after execution
   - Schema validation post-migration

2. **Rollback Capability**:
   - Every migration SHALL have corresponding rollback script
   - Rollback scripts tested before production
   - Automatic rollback on migration failure
   - Manual rollback command available

3. **Safety Checks**:
   - Dry-run mode for validation
   - Database backup before production migrations
   - Lock timeout to prevent hanging migrations
   - Migration duration alerts (>5 minutes)

4. **Audit Trail**:
   - Migration execution logged with timestamp, user, duration
   - Pre/post-migration schema snapshots
   - Rollback events logged
   - FDA 21 CFR Part 11 compliant records

**Validation**:
- **IQ**: Verify migration scripts exist with corresponding rollbacks
- **OQ**: Verify migrations execute correctly and rollback cleanly
- **PQ**: Verify migration performance (< 5 minutes for typical migration)

**Acceptance Criteria**:
- ✅ Migration framework integrated (Supabase migrations)
- ✅ Rollback scripts required for all migrations
- ✅ Automated backup before production migrations
- ✅ Migration audit trail maintained
- ✅ Dry-run capability implemented
- ✅ Alert on migration duration >5 minutes

*End* *Database Migration Automation* | **Hash**: 10291b2e
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
|-----------|-----------|---------|
| **CI/CD Platform** | GitHub Actions | Workflow orchestration |
| **Migration Tool** | Supabase CLI | Database migrations |
| **Secrets Management** | Doppler | Secure credential injection |
| **State Management** | Terraform | Infrastructure provisioning |
| **Container Registry** | GitHub Container Registry | Docker image storage |
| **Approval System** | GitHub Environments | Manual approval gates |

---

## Workflow Definitions

### Development Deployment Workflow

**File**: `.github/workflows/deploy-development.yml`

**Triggers**:
- Push to `main` branch (automatic)

**Steps**:
1. Checkout code
2. Set up environment (Node.js, Dart, Supabase CLI)
3. Inject secrets from Doppler
4. Run linting and type checking
5. Run unit tests
6. Execute database migrations (with rollback on failure)
7. Deploy application to Supabase
8. Run smoke tests
9. Notify team (Slack/email)

**Rollback**: Automatic on any step failure

**SLA**: Complete within 10 minutes

---

### Staging Deployment Workflow

**File**: `.github/workflows/deploy-staging.yml`

**Triggers**:
- Manual workflow dispatch (requires QA Lead approval)

**Steps**:
1. Await manual approval
2. Checkout code
3. Set up environment
4. Inject secrets from Doppler
5. Run full test suite
6. Execute database migrations (with backup and rollback)
7. Deploy application to Supabase
8. Run smoke tests
9. Run integration tests
10. Notify QA team

**Rollback**: Automatic on any step failure

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
4. Set up environment
5. Inject secrets from Doppler
6. Create database backup (7-year retention)
7. Execute database migrations (with rollback plan)
8. Deploy application to Supabase
9. Run smoke tests
10. Run health checks
11. Monitor for 15 minutes post-deployment
12. Notify team

**Rollback**: Automatic on any step failure, triggers incident response

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
- Health check failure within 15 minutes post-deployment

**Procedure**:
1. Identify last known good state (previous deployment)
2. Execute database rollback script
3. Revert application code to previous version
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

**Storage**: Deployment logs stored in S3 Glacier with 7-year retention

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

2. **Set up Secrets**:
   ```bash
   # Add to GitHub repository secrets:
   gh secret set DOPPLER_TOKEN_DEV --body "<dev-token>"
   gh secret set DOPPLER_TOKEN_STAGING --body "<staging-token>"
   gh secret set DOPPLER_TOKEN_PROD --body "<prod-token>"
   gh secret set SUPABASE_ACCESS_TOKEN --body "<access-token>"
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

See `infrastructure/ACTIVATION_GUIDE.md` for complete activation procedures.

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
- spec/ops-infrastructure-as-code.md - IaC specification
- .github/workflows/ - Actual workflow definitions
- tools/testing/smoke-tests/ - Smoke test implementations
- docs/ops/incident-response-runbook.md - Incident response procedures

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-27 | 1.0 | Claude | Initial specification (ready to activate) |
