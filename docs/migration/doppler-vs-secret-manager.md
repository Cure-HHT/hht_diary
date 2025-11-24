# Doppler vs GCP Secret Manager Comparison

**Version**: 1.0
**Status**: Active
**Created**: 2025-11-24

> **Purpose**: Compare Doppler with GCP Secret Manager for secrets management in a clinical trial platform with HIPAA, GDPR, and FDA 21 CFR Part 11 compliance requirements.

---

## Executive Summary

Both Doppler and GCP Secret Manager are enterprise-grade secrets management solutions. This document compares them specifically for a GCP-hosted clinical trial platform, with focus on developer experience, compliance, and integration patterns.

**Recommendation**: **Hybrid Approach** - Use Doppler for development/CI convenience with Secret Manager for production GCP workloads, or continue using Doppler exclusively if the current workflow is satisfactory.

---

## Feature Comparison

| Feature | Doppler | GCP Secret Manager |
|---------|---------|-------------------|
| **Multi-environment** | Excellent (projects/configs) | Good (versions/labels) |
| **CLI Injection** | `doppler run -- cmd` | `gcloud run services update` |
| **Local Development** | Excellent | Requires setup |
| **CI/CD Integration** | Native GitHub Actions | Native GCP + GitHub Actions |
| **Access Control** | Team-based RBAC | IAM-based |
| **Audit Logging** | Built-in | Cloud Audit Logs |
| **Rotation** | Manual (auto for integrations) | Automatic (with Cloud Functions) |
| **Pricing** | Free tier + paid plans | Pay per access ($0.03/10k) |
| **GCP Native** | No (external) | Yes |
| **SOC 2 Type II** | Yes | Yes (GCP-wide) |
| **HIPAA** | BAA available | BAA available (GCP BAA) |

---

## Doppler Advantages

### 1. Developer Experience

Doppler excels at developer workflow:

```bash
# Run Claude Code with secrets injected
doppler run -- claude

# Run any command with secrets
doppler run -- flutter run

# Multiple environments seamlessly
doppler run --config staging -- flutter test
```

**Current Pattern** (working well):
```bash
# Claude Code with Linear API and Claude API exposed
doppler run -- claude

# CI/CD in GitHub Actions
- uses: dopplerhq/cli-action@v3
  with:
    project: clinical-diary
    config: production
```

### 2. Environment Organization

Doppler's project/config model maps well to multi-sponsor:

```
clinical-diary/
├── development     # Shared dev secrets
├── staging        # Pre-production
└── production     # Production secrets

clinical-diary-sponsor-orion/
├── staging        # Orion staging
└── production     # Orion production
```

### 3. Syncing Features

Doppler can sync to other secret stores:
- AWS Secrets Manager
- GCP Secret Manager (!)
- Kubernetes Secrets
- Vercel, Netlify, etc.

This enables a **Doppler → Secret Manager** sync pattern.

---

## GCP Secret Manager Advantages

### 1. Native GCP Integration

Secret Manager integrates seamlessly with GCP services:

```yaml
# Cloud Run automatic secret injection
spec:
  template:
    spec:
      containers:
      - name: server
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              key: latest
              name: database-url
```

```hcl
# Terraform native support
resource "google_cloud_run_service" "app" {
  template {
    spec {
      containers {
        env {
          name = "DB_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_password.secret_id
              key  = "latest"
            }
          }
        }
      }
    }
  }
}
```

### 2. IAM Integration

Uses standard GCP IAM for access control:

```hcl
resource "google_secret_manager_secret_iam_member" "access" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
```

### 3. Automatic Rotation

Can implement automatic rotation:

```python
# Cloud Function for automatic rotation
def rotate_secret(event, context):
    # Generate new credential
    new_password = generate_password()

    # Update in destination (e.g., Cloud SQL)
    update_database_password(new_password)

    # Add new version to Secret Manager
    client.add_secret_version(
        parent=secret_name,
        payload={'data': new_password.encode()}
    )
```

### 4. Cloud Audit Logs

Native integration with Cloud Audit Logs for compliance:

```sql
-- Query secret access in BigQuery (exported logs)
SELECT
  timestamp,
  protoPayload.authenticationInfo.principalEmail,
  protoPayload.resourceName,
  protoPayload.methodName
FROM `project.dataset.cloudaudit_googleapis_com_data_access`
WHERE protoPayload.serviceName = 'secretmanager.googleapis.com'
```

---

## Workflow Comparison

### Doppler Workflow (Current)

```bash
# Development
doppler setup                     # Interactive project/config selection
doppler run -- flutter run        # Run with secrets injected

# CI/CD (GitHub Actions)
- uses: dopplerhq/cli-action@v3
  env:
    DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}

# Accessing secrets in code
final dbUrl = Platform.environment['DATABASE_URL'];
```

### Secret Manager Workflow (GCP Native)

```bash
# Development (requires gcloud setup)
gcloud auth application-default login
gcloud secrets versions access latest --secret="database-url"

# Or use a wrapper script
./scripts/dev-run.sh flutter run

# CI/CD (Cloud Build or GitHub Actions)
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ vars.WIF_PROVIDER }}
    service_account: ${{ vars.SA_EMAIL }}

# Accessing secrets in Cloud Run (automatic)
# Secrets mounted as env vars by Cloud Run
```

### Hybrid Workflow (Recommended)

```bash
# Development - Doppler (unchanged, excellent DX)
doppler run -- flutter run
doppler run -- claude

# Production - Secret Manager (GCP native)
# Terraform provisions secrets
# Cloud Run accesses via IAM

# Sync Doppler → Secret Manager (optional)
doppler secrets download --no-file | \
  gcloud secrets versions add production-secrets --data-file=-
```

---

## Compliance Considerations

### FDA 21 CFR Part 11

Both solutions provide:
- **Audit trail**: Complete access logging
- **Access control**: Role-based permissions
- **Data integrity**: Encrypted storage

### HIPAA

Both solutions:
- Offer Business Associate Agreements (BAA)
- Encrypt data at rest and in transit
- Provide access logging for audit

### Multi-Sponsor Isolation

| Aspect | Doppler | Secret Manager |
|--------|---------|----------------|
| Project isolation | Separate Doppler projects | Separate GCP projects |
| Access control | Team/service tokens | IAM bindings |
| Cross-sponsor risk | Token management | IAM inheritance |

---

## Implementation Patterns

### Pattern 1: Doppler Only (Keep Current)

Pros:
- No migration effort
- Excellent developer experience
- Works with any cloud

Cons:
- External dependency
- Additional cost at scale
- Not GCP-native

```bash
# Production Cloud Run with Doppler
# Inject at deploy time
doppler run --config production -- gcloud run deploy
```

### Pattern 2: Secret Manager Only

Pros:
- GCP native
- No external dependencies
- Unified IAM

Cons:
- Worse developer experience
- More setup for local dev
- Separate per-project secrets

```hcl
# All secrets in Terraform
resource "google_secret_manager_secret" "all" {
  for_each  = var.secrets
  secret_id = each.key
  # ...
}
```

### Pattern 3: Hybrid (Recommended)

Pros:
- Best of both worlds
- Excellent local DX (Doppler)
- GCP-native production (Secret Manager)

Cons:
- Two systems to manage
- Sync process needed

```yaml
# .github/workflows/deploy.yml
jobs:
  sync-secrets:
    steps:
      - name: Sync Doppler to Secret Manager
        run: |
          doppler secrets download --format json | \
          gcloud secrets versions add app-secrets --data-file=-

  deploy:
    needs: sync-secrets
    steps:
      - name: Deploy to Cloud Run
        # Cloud Run reads from Secret Manager
```

---

## Migration Path

If migrating from Doppler-only to Hybrid:

### Step 1: Create Secret Manager Secrets

```bash
# Export from Doppler
doppler secrets download --format json > secrets.json

# Create in Secret Manager
for secret in $(jq -r 'keys[]' secrets.json); do
  gcloud secrets create $secret
  jq -r ".$secret" secrets.json | \
    gcloud secrets versions add $secret --data-file=-
done
```

### Step 2: Update Terraform

```hcl
# Reference existing secrets
data "google_secret_manager_secret_version" "db_password" {
  secret  = "DATABASE_PASSWORD"
  version = "latest"
}

# Use in Cloud Run
resource "google_cloud_run_service" "app" {
  template {
    spec {
      containers {
        env {
          name = "DATABASE_PASSWORD"
          value_from {
            secret_key_ref {
              name = "DATABASE_PASSWORD"
              key  = "latest"
            }
          }
        }
      }
    }
  }
}
```

### Step 3: Keep Doppler for Development

```bash
# No changes needed for local dev
doppler run -- flutter run

# Doppler syncs to Secret Manager (optional automation)
```

---

## Cost Comparison

### Doppler

| Plan | Cost | Secrets | Team |
|------|------|---------|------|
| Free | $0 | Unlimited | 5 users |
| Team | $6/user/mo | Unlimited | Unlimited |
| Enterprise | Custom | Unlimited | SSO, audit |

### Secret Manager

| Usage | Cost |
|-------|------|
| Active secrets | $0.06/secret/month |
| Access operations | $0.03 per 10,000 |
| Versions | $0.06/version/month |

**Example** (100 secrets, 1M accesses/month):
- Doppler Team (10 users): ~$60/month
- Secret Manager: ~$6 + $3 = ~$9/month

---

## Recommendation

### For This Project: Hybrid Approach

**Development/CI**:
- Continue using Doppler
- Excellent `doppler run -- claude` workflow
- No changes to developer experience

**Production (Cloud Run)**:
- Use Secret Manager
- GCP-native integration
- IAM-based access control
- Unified audit logging

**Implementation**:
```yaml
# CI/CD syncs Doppler → Secret Manager
# Cloud Run reads from Secret Manager
# Developers use Doppler locally
```

### Alternative: Keep Doppler Only

If the current Doppler workflow is satisfactory:
- Deploy Cloud Run with Doppler secrets at deploy time
- Use Doppler service tokens in CI/CD
- Skip Secret Manager entirely

```bash
# Deploy pattern
doppler run --config production -- \
  gcloud run deploy app \
    --set-env-vars="DATABASE_URL=$DATABASE_URL,..."
```

---

## Decision Matrix

| If you value... | Choose... |
|-----------------|-----------|
| Developer experience | Doppler (or Hybrid) |
| GCP-native only | Secret Manager only |
| Cost optimization | Secret Manager only |
| Minimal migration | Keep Doppler only |
| Compliance documentation | Either (both compliant) |
| Best of both worlds | Hybrid |

---

## Implementation Timeline

If choosing Hybrid approach:

| Task | Duration |
|------|----------|
| Create Secret Manager secrets | 1 hour |
| Update Terraform for Cloud Run | 2-4 hours |
| Add sync step to CI/CD | 1-2 hours |
| Test production deployment | 2-4 hours |
| Update documentation | 1-2 hours |
| **Total** | **1 day** |

---

## References

- [Doppler Documentation](https://docs.doppler.com/)
- [Doppler GCP Sync](https://docs.doppler.com/docs/gcp-secret-manager)
- [GCP Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Cloud Run Secrets](https://cloud.google.com/run/docs/configuring/secrets)
- [Terraform google_secret_manager_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret)

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-24 | 1.0 | Initial comparison document | Claude |
