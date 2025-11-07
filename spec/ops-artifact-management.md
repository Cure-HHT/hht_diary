# Artifact Management and Retention Specification

**Audience**: Operations team, Compliance team
**Purpose**: Define artifact retention, archival, and lifecycle management for FDA compliance
**Status**: Ready to activate (workflows created, archival configured but not activated)

---

## Requirements

# REQ-o00049: Artifact Retention and Archival

**Level**: Ops | **Implements**: p00010 | **Status**: Active

**Specification**:

The system SHALL implement artifact retention and archival that:

1. **Retention Period**:
   - All production artifacts retained for 7 years minimum (FDA requirement)
   - Development/staging artifacts retained for 1 year
   - Audit trail records retained for 7 years
   - Deployment logs retained for 7 years
   - Incident records retained for 7 years

2. **Artifact Types**:
   - **Source Code**: Git repository with all commits
   - **Build Artifacts**: Compiled binaries, container images
   - **Deployment Records**: Deployment logs, approvals, timestamps
   - **Test Results**: Validation reports (IQ/OQ/PQ), test logs
   - **Audit Trail**: Database audit records, access logs
   - **Incident Records**: Incident tickets, post-mortems, resolutions
   - **Database Backups**: Full backups, migration scripts

3. **Storage Tiers**:
   - **Hot Storage** (frequent access): Last 90 days
     - S3 Standard
     - Immediate retrieval
     - Higher cost (~$0.023/GB/month)
   - **Cold Storage** (infrequent access): 91 days to 7 years
     - S3 Glacier Deep Archive
     - 12-hour retrieval time
     - Lower cost (~$0.00099/GB/month)

4. **Lifecycle Management**:
   - Automatic transition from hot to cold storage after 90 days
   - Automatic deletion after 7 years
   - Manual retention extension for regulatory holds
   - Verification of archival integrity (monthly checksums)

5. **Retrieval Procedures**:
   - Standard retrieval: 12 hours (Glacier Deep Archive)
   - Expedited retrieval: Not available for Deep Archive
   - Bulk retrieval: For regulatory audits (all artifacts)

**Validation**:
- **IQ**: Verify S3 buckets configured with lifecycle policies
- **OQ**: Verify artifacts transition to cold storage after 90 days
- **PQ**: Verify retrieval within 12 hours for cold storage artifacts

**Acceptance Criteria**:
- ✅ S3 buckets created with encryption
- ✅ Lifecycle policies configured
- ✅ Automated archival workflows deployed
- ✅ Retrieval procedures documented
- ✅ Monthly integrity verification automated

*End* *Artifact Retention and Archival* | **Hash**: 159267f6
---

# REQ-o00050: Environment Parity and Separation

**Level**: Ops | **Implements**: p00008 | **Status**: Active

**Specification**:

The system SHALL maintain environment separation with:

1. **Isolated Environments**:
   - Development: Separate Supabase project, separate database
   - Staging: Separate Supabase project, production-like configuration
   - Production: Isolated, no cross-environment access

2. **Configuration Management**:
   - Environment-specific secrets (stored in Doppler)
   - Environment-specific infrastructure (Terraform workspaces)
   - Environment-specific feature flags
   - No hardcoded environment values

3. **Data Segregation**:
   - No production data in development/staging
   - Synthetic test data for development/staging
   - Production data access restricted (audit logged)

4. **Deployment Independence**:
   - Deployments to one environment do not affect others
   - Separate CI/CD workflows per environment
   - Independent rollback capabilities

**Validation**:
- **IQ**: Verify separate Supabase projects for each environment
- **OQ**: Verify no data leakage between environments
- **PQ**: Verify deployments are independent

**Acceptance Criteria**:
- ✅ Three separate Supabase projects provisioned
- ✅ Environment-specific Doppler configurations
- ✅ Terraform workspaces for each environment
- ✅ No production data in non-production environments

*End* *Environment Parity and Separation* | **Hash**: 50e126da
---

# REQ-o00051: Change Control and Audit Trail

**Level**: Ops | **Implements**: p00010 | **Status**: Active

**Specification**:

The system SHALL maintain change control audit trail with:

1. **Infrastructure Changes**:
   - All Terraform changes logged with author, timestamp, reason
   - Terraform state versions retained for 7 years
   - Infrastructure drift detection and alerts
   - Approval required for production changes

2. **Code Changes**:
   - All commits linked to requirements via pre-commit hook
   - All commits signed with GPG keys
   - Pull request approvals required (2 reviewers for production)
   - Merge commits retained indefinitely (Git history)

3. **Configuration Changes**:
   - Doppler secrets changes logged with audit trail
   - Feature flag changes logged
   - Environment configuration changes require approval

4. **Deployment Audit**:
   - Every deployment logged with:
     - Deployer identity
     - Timestamp (UTC)
     - Version deployed
     - Approval records
     - Deployment outcome (success/failure/rollback)

**Validation**:
- **IQ**: Verify audit logging configured for all systems
- **OQ**: Verify audit records captured correctly
- **PQ**: Verify 7-year retention for audit records

**Acceptance Criteria**:
- ✅ Terraform state versioning enabled
- ✅ Git commit signing enforced
- ✅ Doppler audit trail enabled
- ✅ Deployment logs archived for 7 years

*End* *Change Control and Audit Trail* | **Hash**: abb65c22
---

## Architecture

### Artifact Retention Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Artifact Sources                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Git Commits  │  │ CI/CD Runs   │  │ Database     │          │
│  │ (GitHub)     │  │ (GitHub)     │  │ Backups      │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                  │
│         │                 │                 │                  │
└─────────┼─────────────────┼─────────────────┼──────────────────┘
          │                 │                 │
          └────────┬────────┴────────┬────────┘
                   │                 │
                   ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ Hot Storage (0-90 days) - S3 Standard                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Bucket: clinical-diary-artifacts         │                  │
│  │ • Source code snapshots                  │                  │
│  │ • Build artifacts (APK, iOS bundles)     │                  │
│  │ • Deployment logs                        │                  │
│  │ • Test results                           │                  │
│  │ • Database backups                       │                  │
│  │                                           │                  │
│  │ Encryption: AES-256                      │                  │
│  │ Versioning: Enabled                      │                  │
│  │ Access: IAM roles only                   │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
│          │                                                      │
│          │ Automatic after 90 days                             │
│          ▼                                                      │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Cold Storage (91 days - 7 years) - S3 Glacier Deep Archive     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Bucket: clinical-diary-archive-cold      │                  │
│  │ • All artifacts automatically transitioned                  │
│  │ • Immutable (delete protection enabled) │                  │
│  │ • Retrieval time: 12 hours standard      │                  │
│  │ • Cost: ~$1/TB/month                     │                  │
│  │                                           │                  │
│  │ Lifecycle:                               │                  │
│  │ • 0-90 days: S3 Standard                 │                  │
│  │ • 91 days - 7 years: Glacier Deep Archive│                  │
│  │ • After 7 years: Automatic deletion      │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Audit Trail (7-year retention) - PostgreSQL + S3 Glacier       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Primary: PostgreSQL (Supabase)           │                  │
│  │ • Real-time audit records                │                  │
│  │ • Last 90 days online                    │                  │
│  │ • Daily backup to S3                     │                  │
│  └────────────┬─────────────────────────────┘                  │
│               │                                                 │
│               │ Daily export                                    │
│               ▼                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Backup: S3 Glacier                       │                  │
│  │ • Daily audit trail snapshots            │                  │
│  │ • Compressed and encrypted               │                  │
│  │ • 7-year retention                       │                  │
│  │ • Cryptographic hash verification        │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Component | Technology | Cost (monthly) | Purpose |
|-----------|-----------|----------------|---------|
| **Hot Storage** | AWS S3 Standard | ~$5 | Recent artifacts (0-90 days) |
| **Cold Storage** | AWS S3 Glacier Deep Archive | ~$1 | Long-term retention (7 years) |
| **Version Control** | GitHub (included) | $0 | Source code retention |
| **CI/CD Artifacts** | GitHub Actions | $0 | Build logs, test results |
| **Database Backups** | Supabase + S3 | ~$2 | Daily backups archived |
| **Audit Trail** | PostgreSQL + S3 Glacier | ~$1 | 7-year audit compliance |

**Total Cost**: ~$9/month

---

## S3 Bucket Configuration

### Create S3 Buckets (One-Time Setup)

```bash
# Create hot storage bucket
aws s3 mb s3://clinical-diary-artifacts --region us-west-1

# Create cold storage bucket
aws s3 mb s3://clinical-diary-archive-cold --region us-west-1

# Enable versioning (hot storage)
aws s3api put-bucket-versioning \
  --bucket clinical-diary-artifacts \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket clinical-diary-artifacts \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws s3api put-bucket-encryption \
  --bucket clinical-diary-archive-cold \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Enable object lock (immutability) for cold storage
aws s3api put-object-lock-configuration \
  --bucket clinical-diary-archive-cold \
  --object-lock-configuration '{
    "ObjectLockEnabled": "Enabled",
    "Rule": {
      "DefaultRetention": {
        "Mode": "GOVERNANCE",
        "Years": 7
      }
    }
  }'
```

---

## Lifecycle Policies

### Hot Storage Lifecycle Policy

Create file `lifecycle-hot.json`:

```json
{
  "Rules": [
    {
      "Id": "TransitionToColdStorage",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 90,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ]
    }
  ]
}
```

Apply lifecycle policy:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket clinical-diary-artifacts \
  --lifecycle-configuration file://lifecycle-hot.json
```

---

### Cold Storage Lifecycle Policy

Create file `lifecycle-cold.json`:

```json
{
  "Rules": [
    {
      "Id": "DeleteAfter7Years",
      "Status": "Enabled",
      "Expiration": {
        "Days": 2555
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 2555
      }
    }
  ]
}
```

Apply lifecycle policy:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket clinical-diary-archive-cold \
  --lifecycle-configuration file://lifecycle-cold.json
```

**Note**: 2555 days = ~7 years

---

## Automated Archival Workflows

### GitHub Actions: Archive Build Artifacts

File: `.github/workflows/archive-artifacts.yml`

```yaml
name: Archive Build Artifacts

on:
  workflow_run:
    workflows: ["Deploy to Production"]
    types: [completed]

jobs:
  archive:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download artifacts
        uses: actions/download-artifact@v3
        with:
          name: build-artifacts
          path: ./artifacts

      - name: Create archive metadata
        run: |
          cat > metadata.json <<EOF
          {
            "build_id": "${{ github.run_id }}",
            "commit_sha": "${{ github.sha }}",
            "version": "$(git describe --tags --always)",
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "deployer": "${{ github.actor }}",
            "environment": "production"
          }
          EOF

      - name: Package artifacts
        run: |
          ARCHIVE_NAME="artifacts-prod-$(date +%Y%m%d-%H%M%S).tar.gz"
          tar -czf $ARCHIVE_NAME artifacts/ metadata.json

      - name: Upload to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 cp $ARCHIVE_NAME s3://clinical-diary-artifacts/builds/ \
            --metadata "version=$(git describe --tags --always),environment=production"

      - name: Generate checksum
        run: |
          sha256sum $ARCHIVE_NAME > $ARCHIVE_NAME.sha256
          aws s3 cp $ARCHIVE_NAME.sha256 s3://clinical-diary-artifacts/builds/

      - name: Log archival
        run: |
          echo "✅ Artifacts archived to S3"
          echo "Archive: $ARCHIVE_NAME"
          echo "Location: s3://clinical-diary-artifacts/builds/$ARCHIVE_NAME"
```

---

### GitHub Actions: Archive Deployment Logs

File: `.github/workflows/archive-deployment-logs.yml`

```yaml
name: Archive Deployment Logs

on:
  workflow_run:
    workflows: ["Deploy to Production", "Rollback Deployment"]
    types: [completed]

jobs:
  archive-logs:
    runs-on: ubuntu-latest

    steps:
      - name: Fetch deployment logs
        run: |
          # Get workflow run logs
          gh run view ${{ github.event.workflow_run.id }} --log > deployment-log.txt

      - name: Create deployment record
        run: |
          cat > deployment-record.json <<EOF
          {
            "workflow_id": "${{ github.event.workflow_run.id }}",
            "workflow_name": "${{ github.event.workflow_run.name }}",
            "commit_sha": "${{ github.event.workflow_run.head_sha }}",
            "timestamp": "${{ github.event.workflow_run.created_at }}",
            "outcome": "${{ github.event.workflow_run.conclusion }}",
            "deployer": "${{ github.event.workflow_run.actor.login }}"
          }
          EOF

      - name: Package deployment record
        run: |
          RECORD_NAME="deployment-${{ github.event.workflow_run.id }}.tar.gz"
          tar -czf $RECORD_NAME deployment-log.txt deployment-record.json

      - name: Upload to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 cp $RECORD_NAME s3://clinical-diary-artifacts/deployments/ \
            --metadata "workflow_id=${{ github.event.workflow_run.id }},environment=production"

      - name: Generate checksum
        run: |
          sha256sum $RECORD_NAME > $RECORD_NAME.sha256
          aws s3 cp $RECORD_NAME.sha256 s3://clinical-diary-artifacts/deployments/
```

---

### Nightly: Archive Audit Trail

File: `.github/workflows/archive-audit-trail.yml`

```yaml
name: Archive Audit Trail (Nightly)

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:  # Allow manual trigger

jobs:
  archive-audit-trail:
    runs-on: ubuntu-latest

    steps:
      - name: Install Supabase CLI
        run: brew install supabase/tap/supabase

      - name: Load secrets from Doppler
        uses: dopplerhq/cli-action@v3
        env:
          DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN_PROD }}

      - name: Export audit trail
        run: |
          EXPORT_DATE=$(date +%Y-%m-%d)
          EXPORT_FILE="audit-trail-$EXPORT_DATE.sql"

          # Export yesterday's audit records
          doppler run -- psql $DATABASE_URL -c "
            COPY (
              SELECT * FROM audit_trail
              WHERE created_at >= CURRENT_DATE - INTERVAL '1 day'
                AND created_at < CURRENT_DATE
              ORDER BY created_at
            ) TO STDOUT WITH CSV HEADER
          " > $EXPORT_FILE

          # Compress
          gzip $EXPORT_FILE

      - name: Verify integrity
        run: |
          # Generate checksum
          sha256sum $EXPORT_FILE.gz > $EXPORT_FILE.gz.sha256

          # Verify audit trail hashes
          doppler run -- psql $DATABASE_URL -c "
            SELECT check_audit_trail_integrity();
          "

      - name: Upload to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 cp $EXPORT_FILE.gz s3://clinical-diary-artifacts/audit-trail/ \
            --metadata "date=$(date +%Y-%m-%d),environment=production"

          aws s3 cp $EXPORT_FILE.gz.sha256 s3://clinical-diary-artifacts/audit-trail/

      - name: Verify upload
        run: |
          aws s3 ls s3://clinical-diary-artifacts/audit-trail/$EXPORT_FILE.gz
          echo "✅ Audit trail archived successfully"

      - name: Notify on failure
        if: failure()
        run: |
          echo "❌ Audit trail archival failed"
          # TODO: Send alert to ops team
```

---

## Retrieval Procedures

### Retrieve from Hot Storage (0-90 days)

Immediate access:

```bash
# List artifacts
aws s3 ls s3://clinical-diary-artifacts/builds/ --recursive

# Download specific artifact
aws s3 cp s3://clinical-diary-artifacts/builds/artifacts-prod-20250127-120000.tar.gz .

# Verify checksum
aws s3 cp s3://clinical-diary-artifacts/builds/artifacts-prod-20250127-120000.tar.gz.sha256 .
sha256sum -c artifacts-prod-20250127-120000.tar.gz.sha256
```

---

### Retrieve from Cold Storage (91 days - 7 years)

Requires 12-hour retrieval:

```bash
# Step 1: Initiate retrieval
aws s3api restore-object \
  --bucket clinical-diary-archive-cold \
  --key builds/artifacts-prod-20240501-120000.tar.gz \
  --restore-request Days=7,GlacierJobParameters={Tier=Standard}

# Step 2: Check restoration status
aws s3api head-object \
  --bucket clinical-diary-archive-cold \
  --key builds/artifacts-prod-20240501-120000.tar.gz

# Step 3: Download after restoration complete (12 hours)
aws s3 cp s3://clinical-diary-archive-cold/builds/artifacts-prod-20240501-120000.tar.gz .
```

**Bulk Retrieval** (for audits):

```bash
# List all artifacts in cold storage
aws s3api list-objects-v2 --bucket clinical-diary-archive-cold --query 'Contents[*].[Key]' --output text > cold-storage-list.txt

# Restore all (scripted)
while read key; do
  aws s3api restore-object \
    --bucket clinical-diary-archive-cold \
    --key "$key" \
    --restore-request Days=30,GlacierJobParameters={Tier=Bulk}
done < cold-storage-list.txt
```

**Note**: Bulk retrieval is cheaper but slower (12-48 hours)

---

## Monthly Integrity Verification

### Verify Checksums (Automated)

File: `.github/workflows/verify-archive-integrity.yml`

```yaml
name: Verify Archive Integrity (Monthly)

on:
  schedule:
    - cron: '0 3 1 * *'  # 3 AM UTC on 1st of each month
  workflow_dispatch:

jobs:
  verify-integrity:
    runs-on: ubuntu-latest

    steps:
      - name: List hot storage artifacts
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          # Get list of all artifacts with checksums
          aws s3 ls s3://clinical-diary-artifacts/ --recursive | grep '.sha256$' > checksums.txt

      - name: Verify checksums
        run: |
          FAILED=0

          while read line; do
            CHECKSUM_FILE=$(echo $line | awk '{print $4}')
            ARTIFACT_FILE="${CHECKSUM_FILE%.sha256}"

            echo "Verifying: $ARTIFACT_FILE"

            # Download artifact and checksum
            aws s3 cp "s3://clinical-diary-artifacts/$ARTIFACT_FILE" .
            aws s3 cp "s3://clinical-diary-artifacts/$CHECKSUM_FILE" .

            # Verify
            if sha256sum -c "$(basename $CHECKSUM_FILE)"; then
              echo "✅ Verified: $ARTIFACT_FILE"
            else
              echo "❌ FAILED: $ARTIFACT_FILE"
              FAILED=$((FAILED + 1))
            fi

            # Cleanup
            rm "$(basename $ARTIFACT_FILE)" "$(basename $CHECKSUM_FILE)"
          done < checksums.txt

          if [ $FAILED -gt 0 ]; then
            echo "❌ $FAILED artifacts failed verification"
            exit 1
          fi

          echo "✅ All artifacts verified successfully"

      - name: Report results
        run: |
          echo "Integrity verification complete"
          echo "Date: $(date -u +%Y-%m-%d)"
          # TODO: Log to compliance dashboard
```

---

## Activation Instructions

To activate artifact management:

1. **Create S3 buckets**:
   ```bash
   # Run bucket creation commands (see above)
   ```

2. **Configure lifecycle policies**:
   ```bash
   # Apply lifecycle policies (see above)
   ```

3. **Set up GitHub secrets**:
   ```bash
   gh secret set AWS_ACCESS_KEY_ID --body "<key-id>"
   gh secret set AWS_SECRET_ACCESS_KEY --body "<secret-key>"
   ```

4. **Enable workflows**:
   - Workflows are ready but won't run until S3 buckets exist
   - Test archival workflow manually first:
     ```bash
     gh workflow run archive-artifacts.yml
     ```

5. **Verify archival**:
   ```bash
   # Check artifacts in S3
   aws s3 ls s3://clinical-diary-artifacts/ --recursive
   ```

See `infrastructure/ACTIVATION_GUIDE.md` for complete activation procedures.

---

## Cost Estimation

### Monthly Storage Costs

**Assumptions**:
- 500 MB artifacts per deployment
- 8 production deployments per month
- 7-year retention

**Calculation**:

| Storage Type | Size | Duration | Cost/GB/month | Total |
|--------------|------|----------|---------------|-------|
| Hot (0-90 days) | 12 GB | 90 days | $0.023 | $0.28 |
| Cold (7 years) | 336 GB | 7 years | $0.00099 | $0.33 |
| **Total** | | | | **~$9/month** |

**Note**: Costs scale linearly with artifact size and deployment frequency.

---

## References

- [AWS S3 Lifecycle Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [AWS Glacier Deep Archive](https://aws.amazon.com/s3/storage-classes/glacier/)
- spec/ops-monitoring-observability.md - Monitoring specification
- INFRASTRUCTURE_GAP_ANALYSIS.md - Phase 1 implementation plan

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-27 | 1.0 | Claude | Initial specification (ready to activate) |
