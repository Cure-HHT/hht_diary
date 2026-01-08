# Artifact Management and Retention Specification

**Audience**: Operations team, Compliance team
**Purpose**: Define artifact retention, archival, and lifecycle management for FDA compliance
**Status**: Draft
**Version**: 2.0.0
**Last Updated**: 2025-11-24

---

## Requirements

# REQ-o00049: Artifact Retention and Archival

**Level**: Ops | **Status**: Draft | **Implements**: p00010

## Rationale

This requirement establishes the operational framework for artifact retention and archival to ensure FDA 21 CFR Part 11 compliance. The FDA mandates a minimum 7-year retention period for production artifacts to support regulatory audits and inspection readiness. The requirement defines a tiered storage strategy optimizing cost versus access requirements, with hot storage for recent artifacts requiring frequent access and cold storage for long-term retention. Different retention periods for production, staging, and development environments reflect the regulatory significance of each environment. Lifecycle management policies automate the transition between storage tiers and enforce deletion schedules, reducing operational overhead while maintaining compliance. Integrity verification and immutability protections ensure that archived artifacts remain tamper-evident throughout their retention period.

## Assertions

A. The system SHALL retain production artifacts for a minimum of 7 years.
B. The system SHALL retain staging artifacts for a minimum of 30 days.
C. The system SHALL retain development artifacts for a minimum of 7 days.
D. The system SHALL retain audit trail records for a minimum of 7 years.
E. The system SHALL retain deployment logs for a minimum of 7 years.
F. The system SHALL retain incident records for a minimum of 7 years.
G. The system SHALL archive source code artifacts including all Git repository commits.
H. The system SHALL archive build artifacts including compiled binaries and container images.
I. The system SHALL archive deployment records including deployment logs, approvals, and timestamps.
J. The system SHALL archive test results including validation reports (IQ/OQ/PQ) and test logs.
K. The system SHALL archive audit trail artifacts including database audit records and access logs.
L. The system SHALL archive incident records including incident tickets, post-mortems, and resolutions.
M. The system SHALL archive database backups including full backups and migration scripts.
N. The system SHALL store production artifacts from the last 90 days in hot storage with immediate retrieval capability.
O. The system SHALL store production artifacts from 91 days to 7 years in cold storage.
P. The system SHALL transition production artifacts from hot storage to cold storage automatically after 90 days.
Q. The system SHALL delete production artifacts automatically after 7 years unless subject to manual retention extension.
R. The system SHALL enable object retention policy (immutable) for production artifacts.
S. The system SHALL transition staging artifacts to Nearline storage after 7 days.
T. The system SHALL delete staging artifacts automatically after 30 days.
U. The system SHALL delete development artifacts automatically after 7 days.
V. The system SHALL verify archival integrity through monthly checksum validation for all storage tiers.
W. The system SHALL support manual retention extension for production artifacts subject to regulatory holds.
X. Cloud Storage buckets SHALL be created with encryption enabled.
Y. Lifecycle policies SHALL be configured for all storage buckets.
Z. Retrieval procedures SHALL be documented for all storage classes.

*End* *Artifact Retention and Archival* | **Hash**: 657b1be8
---

# REQ-o00050: Environment Parity and Separation

**Level**: Ops | **Status**: Draft | **Implements**: p00008

## Rationale

This requirement ensures proper isolation and separation between development, staging, and production environments to prevent unauthorized access, data leakage, and unintended impacts from deployments. Environment parity requirements support FDA 21 CFR Part 11 compliance by maintaining controlled conditions that mirror production while protecting sensitive clinical trial data. The separation of infrastructure, configuration, and deployment workflows reduces risk of production incidents and enables safe testing and validation activities. This implements the broader system architecture requirement for environment management defined in REQ-p00008.

## Assertions

A. The system SHALL maintain three isolated environments: development, staging, and production.
B. The development environment SHALL use a separate GCP project from staging and production.
C. The development environment SHALL use a separate Cloud SQL instance from staging and production.
D. The staging environment SHALL use a separate GCP project from development and production.
E. The staging environment SHALL use production-like configuration.
F. The production environment SHALL use a GCP project isolated from development and staging.
G. The production environment SHALL NOT allow cross-environment access from development or staging.
H. The system SHALL store environment-specific secrets in Doppler.
I. The system SHALL use environment-specific infrastructure managed through Terraform workspaces.
J. The system SHALL support environment-specific feature flags.
K. The system SHALL NOT use hardcoded environment values in configuration.
L. Development environments SHALL NOT contain production data.
M. Staging environments SHALL NOT contain production data.
N. Development environments SHALL use synthetic test data.
O. Staging environments SHALL use synthetic test data.
P. The system SHALL restrict production data access with audit logging.
Q. Deployments to one environment SHALL NOT affect other environments.
R. The system SHALL provide separate CI/CD workflows per environment.
S. The system SHALL support independent rollback capabilities for each environment.
T. The system SHALL provision three separate GCP projects per sponsor.
U. The system SHALL provide environment-specific Doppler configurations for each environment.
V. The system SHALL create Terraform workspaces for each environment.

*End* *Environment Parity and Separation* | **Hash**: 6e251c7f
---

# REQ-o00051: Change Control and Audit Trail

**Level**: Ops | **Status**: Draft | **Implements**: p00010

## Rationale

This requirement ensures comprehensive change control and audit trails across all layers of the clinical trial system to meet FDA 21 CFR Part 11 compliance. The requirement addresses infrastructure changes, code modifications, configuration updates, and deployment activities. The 7-year retention period aligns with FDA regulatory requirements for clinical trial record retention. Audit trails enable investigation of system changes, support regulatory inspections, and provide tamper-evident evidence of who made what changes and when. The requirement implements parent requirement p00010 which establishes overall audit trail and data integrity obligations.

## Assertions

A. The system SHALL maintain a change control audit trail for all infrastructure, code, configuration, and deployment changes.
B. The system SHALL log all Terraform changes with author identity, timestamp, and reason for change.
C. The system SHALL retain Terraform state versions for a minimum of 7 years using GCS backend storage.
D. The system SHALL implement infrastructure drift detection and generate alerts when drift is detected.
E. The system SHALL require approval before applying Terraform changes to production environments.
F. The system SHALL link all code commits to requirements via pre-commit hook enforcement.
G. The system SHALL require all code commits to be signed with GPG keys.
H. The system SHALL require pull request approvals from 2 reviewers before merging to production branches.
I. The system SHALL retain merge commit history indefinitely in Git repositories.
J. The system SHALL log all Doppler secrets changes with audit trail information.
K. The system SHALL log all feature flag changes.
L. The system SHALL require approval for environment configuration changes.
M. The system SHALL log every deployment with deployer identity, timestamp in UTC, version deployed, approval records, and deployment outcome.
N. Deployment outcome records SHALL indicate success, failure, or rollback status.
O. The system SHALL archive deployment logs for a minimum of 7 years.
P. Audit logging SHALL be configured and verified during Installation Qualification (IQ).
Q. Audit record capture SHALL be verified during Operational Qualification (OQ).
R. Seven-year retention of audit records SHALL be verified during Performance Qualification (PQ).
S. Terraform state versioning SHALL be enabled on GCS backend.
T. Git commit signing SHALL be enforced for all commits.
U. Doppler audit trail SHALL be enabled for all secret management operations.

*End* *Change Control and Audit Trail* | **Hash**: 245582fc
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
| --- | --- | --- |
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
