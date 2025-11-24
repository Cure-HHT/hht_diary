# Artifact Management and Retention Specification

**Audience**: Operations team, Compliance team
**Purpose**: Define artifact retention, archival, and lifecycle management for FDA compliance
**Status**: Active
**Version**: 2.0.0
**Last Updated**: 2025-11-24

---

## Requirements

# REQ-o00049: Artifact Retention and Archival

**Level**: Ops | **Implements**: p00010 | **Status**: Active

**Specification**:

The system SHALL implement artifact retention and archival that:

1. **Retention Period**:
   - **Production artifacts**: 7 years minimum (FDA requirement)
   - **Staging artifacts**: 30 days (pre-production testing)
   - **Development artifacts**: 7 days (workflow testing)
   - **Audit trail records**: 7 years
   - **Deployment logs**: 7 years
   - **Incident records**: 7 years

2. **Artifact Types**:
   - **Source Code**: Git repository with all commits
   - **Build Artifacts**: Compiled binaries, container images
   - **Deployment Records**: Deployment logs, approvals, timestamps
   - **Test Results**: Validation reports (IQ/OQ/PQ), test logs
   - **Audit Trail**: Database audit records, access logs
   - **Incident Records**: Incident tickets, post-mortems, resolutions
   - **Database Backups**: Full backups, migration scripts

3. **Storage Tiers**:
   - **Production Storage** (7-year retention):
     - **Hot Storage** (frequent access): Last 90 days
       - Cloud Storage Standard
       - Immediate retrieval
       - Higher cost (~$0.020/GB/month)
     - **Cold Storage** (infrequent access): 91 days to 7 years
       - Cloud Storage Coldline/Archive
       - Retrieval time: seconds to hours
       - Lower cost (~$0.004/GB/month for Coldline)
   - **Staging Storage** (30-day retention):
     - Cloud Storage Nearline (after 7 days)
     - Automatic deletion after 30 days
     - For pre-production validation
   - **Development Storage** (7-day retention):
     - Cloud Storage Standard
     - Automatic deletion after 7 days
     - For workflow testing only

4. **Lifecycle Management**:
   - **Production**:
     - Automatic transition from hot to cold storage after 90 days
     - Automatic deletion after 7 years
     - Manual retention extension for regulatory holds
     - Object retention policy enabled (immutable)
   - **Staging**:
     - Transition to Nearline after 7 days
     - Automatic deletion after 30 days
     - No retention lock (testing only)
   - **Development**:
     - Automatic deletion after 7 days
     - No lifecycle transitions
     - No retention lock (testing only)
   - **All tiers**: Verification of archival integrity (monthly checksums)

5. **Retrieval Procedures**:
   - Standard retrieval: Immediate to minutes (Coldline)
   - Archive retrieval: Minutes to hours (Archive class)
   - Bulk retrieval: For regulatory audits (all artifacts)

**Validation**:
- **IQ**: Verify Cloud Storage buckets configured with lifecycle policies
- **OQ**: Verify artifacts transition to cold storage after 90 days
- **PQ**: Verify retrieval within SLA for each storage class

**Acceptance Criteria**:
- ✅ Cloud Storage buckets created with encryption
- ✅ Lifecycle policies configured
- ✅ Automated archival workflows deployed
- ✅ Retrieval procedures documented
- ✅ Monthly integrity verification automated

*End* *Artifact Retention and Archival* | **Hash**: 83f459da
---

# REQ-o00050: Environment Parity and Separation

**Level**: Ops | **Implements**: p00008 | **Status**: Active

**Specification**:

The system SHALL maintain environment separation with:

1. **Isolated Environments**:
   - Development: Separate GCP project, separate Cloud SQL instance
   - Staging: Separate GCP project, production-like configuration
   - Production: Isolated GCP project, no cross-environment access

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
- **IQ**: Verify separate GCP projects for each environment
- **OQ**: Verify no data leakage between environments
- **PQ**: Verify deployments are independent

**Acceptance Criteria**:
- ✅ Three separate GCP projects provisioned (per sponsor)
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
   - Terraform state versions retained for 7 years (GCS backend)
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
- ✅ Terraform state versioning enabled (GCS)
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
│  │ (GitHub)     │  │ (GitHub +    │  │ Backups      │          │
│  │              │  │  Cloud Build)│  │ (Cloud SQL)  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                  │
└─────────┼─────────────────┼─────────────────┼──────────────────┘
          │                 │                 │
          └────────┬────────┴────────┬────────┘
                   │                 │
                   ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ Hot Storage (0-90 days) - Cloud Storage Standard                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Bucket: clinical-diary-artifacts-{env}   │                  │
│  │ • Source code snapshots                  │                  │
│  │ • Build artifacts (APK, iOS bundles)     │                  │
│  │ • Container images (Artifact Registry)   │                  │
│  │ • Deployment logs                        │                  │
│  │ • Test results                           │                  │
│  │ • Database backups                       │                  │
│  │                                           │                  │
│  │ Encryption: Google-managed or CMEK       │                  │
│  │ Versioning: Enabled                      │                  │
│  │ Access: IAM roles only                   │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
│          │                                                      │
│          │ Automatic after 90 days                             │
│          ▼                                                      │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Cold Storage (91 days - 7 years) - Cloud Storage Coldline       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Bucket: clinical-diary-archive-{env}     │                  │
│  │ • All artifacts automatically transitioned                  │
│  │ • Retention policy enabled (immutable)   │                  │
│  │ • Retrieval time: seconds to minutes     │                  │
│  │ • Cost: ~$4/TB/month                     │                  │
│  │                                           │                  │
│  │ Lifecycle:                               │                  │
│  │ • 0-90 days: Standard                    │                  │
│  │ • 91 days - 7 years: Coldline            │                  │
│  │ • After 7 years: Automatic deletion      │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Container Registry - Artifact Registry                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Repository: clinical-diary               │                  │
│  │ • Docker images for Cloud Run            │                  │
│  │ • Vulnerability scanning enabled         │                  │
│  │ • Cleanup policies configured            │                  │
│  │ • Signed images (optional)               │                  │
│  │                                           │                  │
│  │ Retention:                               │                  │
│  │ • Keep last 10 versions per tag          │                  │
│  │ • Delete untagged after 30 days          │                  │
│  │ • Production tags: 7 year retention      │                  │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Audit Trail (7-year retention) - PostgreSQL + Cloud Storage     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Primary: Cloud SQL PostgreSQL            │                  │
│  │ • Real-time audit records                │                  │
│  │ • Last 90 days online                    │                  │
│  │ • Daily backup to Cloud Storage          │                  │
│  └────────────┬─────────────────────────────┘                  │
│               │                                                 │
│               │ Daily export                                    │
│               ▼                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Backup: Cloud Storage Coldline           │                  │
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
| --- | --- | --- | --- |
| **Hot Storage** | Cloud Storage Standard | ~$20/TB | Recent artifacts (0-90 days) |
| **Cold Storage** | Cloud Storage Coldline | ~$4/TB | Long-term retention (7 years) |
| **Container Registry** | Artifact Registry | ~$0.10/GB | Docker images |
| **Version Control** | GitHub (included) | $0 | Source code retention |
| **CI/CD Artifacts** | GitHub Actions + Cloud Build | Varies | Build logs, test results |
| **Database Backups** | Cloud SQL + Cloud Storage | ~$2 | Daily backups archived |
| **Audit Trail** | PostgreSQL + Cloud Storage | ~$1 | 7-year audit compliance |

**Total Cost**: ~$10-30/month (varies by volume)

---

## GCP Artifact Registry

### Why Artifact Registry over GitHub Packages?

| Feature | GitHub Packages | GCP Artifact Registry |
|---------|-----------------|----------------------|
| **GCP Integration** | Manual setup | Native (IAM, Cloud Build, Cloud Run) |
| **Vulnerability Scanning** | Dependabot (limited) | Container Analysis API |
| **Compliance** | Standard | Healthcare-specific certifications |
| **Access Control** | GitHub tokens | GCP IAM |
| **Cost** | Included in GitHub | ~$0.10/GB stored |
| **Region Control** | Limited | Full control |
| **Audit Logging** | Limited | Cloud Audit Logs |

**Recommendation**: Use Artifact Registry for GCP-deployed containers.

### Create Artifact Registry Repository

```bash
# Create repository
gcloud artifacts repositories create clinical-diary \
  --repository-format=docker \
  --location=$REGION \
  --description="Clinical Diary container images"

# Configure Docker auth
gcloud auth configure-docker $REGION-docker.pkg.dev

# Tag and push image
docker tag clinical-diary:latest \
  $REGION-docker.pkg.dev/$PROJECT_ID/clinical-diary/api:v1.0.0

docker push $REGION-docker.pkg.dev/$PROJECT_ID/clinical-diary/api:v1.0.0
```

### Vulnerability Scanning

```bash
# Enable vulnerability scanning
gcloud services enable containerscanning.googleapis.com

# View vulnerabilities
gcloud artifacts docker images list-vulnerabilities \
  $REGION-docker.pkg.dev/$PROJECT_ID/clinical-diary/api:v1.0.0
```

### Cleanup Policies

```bash
# Via Terraform (recommended)
resource "google_artifact_registry_repository" "clinical_diary" {
  repository_id = "clinical-diary"
  format        = "DOCKER"
  location      = var.region

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"
    condition {
      older_than = "2592000s"  # 30 days
      tag_state  = "UNTAGGED"
    }
  }
}
```

---

## Cloud Storage Configuration

### Create Storage Buckets

```bash
# Create hot storage bucket
gsutil mb -l $REGION -c STANDARD gs://${PROJECT_ID}-artifacts

# Create cold storage bucket
gsutil mb -l $REGION -c COLDLINE gs://${PROJECT_ID}-archive

# Enable versioning (hot storage)
gsutil versioning set on gs://${PROJECT_ID}-artifacts

# Enable uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://${PROJECT_ID}-artifacts
gsutil uniformbucketlevelaccess set on gs://${PROJECT_ID}-archive

# Set retention policy (7 years) on archive bucket
gsutil retention set 7y gs://${PROJECT_ID}-archive
```

---

## Lifecycle Policies

### Hot Storage Lifecycle Policy

```bash
# Create lifecycle configuration
cat > lifecycle-hot.json << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "COLDLINE"
        },
        "condition": {
          "age": 90
        }
      },
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 2555
        }
      }
    ]
  }
}
EOF

# Apply lifecycle policy
gsutil lifecycle set lifecycle-hot.json gs://${PROJECT_ID}-artifacts
```

### Terraform Configuration (Recommended)

```hcl
resource "google_storage_bucket" "artifacts" {
  name     = "${var.project_id}-artifacts"
  location = var.region

  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 2555  # 7 years
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_storage_bucket" "archive" {
  name     = "${var.project_id}-archive"
  location = var.region
  storage_class = "COLDLINE"

  uniform_bucket_level_access = true

  retention_policy {
    retention_period = 220752000  # 7 years in seconds
    is_locked        = true       # Immutable after lock
  }

  labels = {
    environment = var.environment
    compliance  = "fda-7year"
    managed_by  = "terraform"
  }
}
```

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

    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.ARCHIVE_SA }}

      - name: Download artifacts
        uses: actions/download-artifact@v4
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
          echo "ARCHIVE_NAME=$ARCHIVE_NAME" >> $GITHUB_ENV

      - name: Upload to Cloud Storage
        run: |
          gcloud storage cp ${{ env.ARCHIVE_NAME }} \
            gs://${{ vars.ARTIFACTS_BUCKET }}/builds/ \
            --content-type="application/gzip"

      - name: Generate checksum
        run: |
          sha256sum ${{ env.ARCHIVE_NAME }} > ${{ env.ARCHIVE_NAME }}.sha256
          gcloud storage cp ${{ env.ARCHIVE_NAME }}.sha256 \
            gs://${{ vars.ARTIFACTS_BUCKET }}/builds/

      - name: Log archival
        run: |
          echo "✅ Artifacts archived to Cloud Storage"
          echo "Archive: ${{ env.ARCHIVE_NAME }}"
          echo "Location: gs://${{ vars.ARTIFACTS_BUCKET }}/builds/${{ env.ARCHIVE_NAME }}"
```

---

### Cloud Build: Container Image Archive

File: `cloudbuild.yaml`

```yaml
steps:
  # Build container
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:${TAG_NAME}'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:latest'
      - '.'

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api'

  # Scan for vulnerabilities
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'artifacts'
      - 'docker'
      - 'images'
      - 'scan'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:${TAG_NAME}'

images:
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:${TAG_NAME}'
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:latest'

substitutions:
  _REGION: us-central1

options:
  logging: CLOUD_LOGGING_ONLY
```

---

### Nightly: Archive Audit Trail

File: `.github/workflows/archive-audit-trail.yml`

```yaml
name: Archive Audit Trail (Nightly)

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:

jobs:
  archive-audit-trail:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.ARCHIVE_SA }}

      - name: Load secrets from Doppler
        uses: dopplerhq/cli-action@v3
        env:
          DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN_PROD }}

      - name: Start Cloud SQL Proxy
        run: |
          wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
          chmod +x cloud_sql_proxy
          ./cloud_sql_proxy -instances=${{ vars.CLOUD_SQL_INSTANCE }}=tcp:5432 &
          sleep 5

      - name: Export audit trail
        run: |
          EXPORT_DATE=$(date +%Y-%m-%d)
          EXPORT_FILE="audit-trail-$EXPORT_DATE.csv"

          # Export yesterday's audit records
          PGPASSWORD=$DATABASE_PASSWORD psql \
            -h 127.0.0.1 -p 5432 \
            -U $DATABASE_USER -d $DATABASE_NAME \
            -c "COPY (
              SELECT * FROM record_audit
              WHERE server_timestamp >= CURRENT_DATE - INTERVAL '1 day'
                AND server_timestamp < CURRENT_DATE
              ORDER BY audit_id
            ) TO STDOUT WITH CSV HEADER" > $EXPORT_FILE

          # Compress
          gzip $EXPORT_FILE
          echo "EXPORT_FILE=$EXPORT_FILE.gz" >> $GITHUB_ENV

      - name: Generate checksum
        run: |
          sha256sum ${{ env.EXPORT_FILE }} > ${{ env.EXPORT_FILE }}.sha256

      - name: Upload to Cloud Storage
        run: |
          gcloud storage cp ${{ env.EXPORT_FILE }} \
            gs://${{ vars.ARCHIVE_BUCKET }}/audit-trail/

          gcloud storage cp ${{ env.EXPORT_FILE }}.sha256 \
            gs://${{ vars.ARCHIVE_BUCKET }}/audit-trail/

      - name: Verify upload
        run: |
          gcloud storage ls gs://${{ vars.ARCHIVE_BUCKET }}/audit-trail/${{ env.EXPORT_FILE }}
          echo "✅ Audit trail archived successfully"
```

---

## Retrieval Procedures

### Retrieve from Hot Storage (0-90 days)

Immediate access:

```bash
# List artifacts
gcloud storage ls gs://${PROJECT_ID}-artifacts/builds/ --recursive

# Download specific artifact
gcloud storage cp gs://${PROJECT_ID}-artifacts/builds/artifacts-prod-20250127-120000.tar.gz .

# Verify checksum
gcloud storage cp gs://${PROJECT_ID}-artifacts/builds/artifacts-prod-20250127-120000.tar.gz.sha256 .
sha256sum -c artifacts-prod-20250127-120000.tar.gz.sha256
```

---

### Retrieve from Cold Storage (91 days - 7 years)

Cloud Storage Coldline provides immediate access (no restore required):

```bash
# Download from Coldline (same as Standard)
gcloud storage cp gs://${PROJECT_ID}-archive/builds/artifacts-prod-20240501-120000.tar.gz .

# Note: First-byte retrieval may take slightly longer than Standard
# but no explicit restore operation needed
```

**Archive Class** (if using for very old data):

```bash
# Check object storage class
gcloud storage objects describe gs://${PROJECT_ID}-archive/builds/old-artifact.tar.gz \
  --format="get(storageClass)"

# If Archive class, there may be retrieval latency but no restore needed
```

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

    permissions:
      contents: read
      id-token: write

    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.ARCHIVE_SA }}

      - name: List artifacts with checksums
        run: |
          gcloud storage ls gs://${PROJECT_ID}-artifacts/ --recursive \
            | grep '.sha256$' > checksums.txt

      - name: Verify checksums
        run: |
          FAILED=0

          while read checksum_path; do
            ARTIFACT_PATH="${checksum_path%.sha256}"

            echo "Verifying: $ARTIFACT_PATH"

            # Download artifact and checksum
            gcloud storage cp "$ARTIFACT_PATH" .
            gcloud storage cp "$checksum_path" .

            ARTIFACT_NAME=$(basename "$ARTIFACT_PATH")
            CHECKSUM_NAME=$(basename "$checksum_path")

            # Verify
            if sha256sum -c "$CHECKSUM_NAME"; then
              echo "✅ Verified: $ARTIFACT_NAME"
            else
              echo "❌ FAILED: $ARTIFACT_NAME"
              FAILED=$((FAILED + 1))
            fi

            # Cleanup
            rm "$ARTIFACT_NAME" "$CHECKSUM_NAME"
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
```

---

## Cost Estimation

### Monthly Storage Costs

**Assumptions**:
- 500 MB artifacts per deployment
- 8 production deployments per month
- 7-year retention

**Calculation**:

| Storage Type | Size | Duration | Cost/GB/month | Total |
| --- | --- | --- | --- | --- |
| Hot (0-90 days) | 12 GB | 90 days | $0.020 | $0.24 |
| Cold (7 years) | 336 GB | 7 years | $0.004 | $1.34 |
| Artifact Registry | 10 GB | Ongoing | $0.10 | $1.00 |
| **Total** | | | | **~$10/month** |

**Note**: Costs scale linearly with artifact size and deployment frequency.

---

## References

- [Cloud Storage Documentation](https://cloud.google.com/storage/docs)
- [Cloud Storage Lifecycle](https://cloud.google.com/storage/docs/lifecycle)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Cloud Build Documentation](https://cloud.google.com/build/docs)
- spec/ops-monitoring-observability.md - Monitoring specification
- spec/ops-infrastructure-as-code.md - Terraform configuration

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-27 | 1.0 | Claude | Initial specification (AWS S3) |
| 2025-11-24 | 2.0 | Claude | Migration to GCP (Cloud Storage, Artifact Registry) |
