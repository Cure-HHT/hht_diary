# Deployment Operations Guide

**Version**: 2.0
**Audience**: Operations (DevOps, Release Managers, Platform Engineers)
**Last Updated**: 2025-11-24
**Status**: Active

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture overview
> **See**: dev-database.md for database implementation details
> **See**: ops-operations.md for daily monitoring and incident response
> **See**: dev-core-practices.md for development standards

---

## Executive Summary

Comprehensive guide for building, deploying, and releasing the multi-sponsor clinical diary system on Google Cloud Platform. Covers build system usage, CI/CD pipelines, environment configuration, and FDA 21 CFR Part 11 compliant release procedures.

**Architecture**: Single public core repository + private sponsor repositories
**Build System**: Dart-based composition of core + sponsor code
**CI/CD**: GitHub Actions with Cloud Build integration
**Deployments**:
- Mobile: Single app containing all sponsors (App Store + Google Play)
- Portal: Separate deployment per sponsor (Cloud Run static site or Firebase Hosting)
- Backend: Per-sponsor Cloud Run Dart server
- Database: Per-sponsor Cloud SQL instance

---

## GCP Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Per-Sponsor GCP Project                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │ Cloud Run   │    │ Cloud Run   │    │ Cloud SQL   │        │
│  │ (API Server)│───▶│ (Portal Web)│    │ (PostgreSQL)│        │
│  │ Dart Server │    │ Static Site │    │             │        │
│  └──────┬──────┘    └─────────────┘    └──────┬──────┘        │
│         │                                      │               │
│         │         ┌─────────────┐              │               │
│         │         │ Identity    │              │               │
│         └────────▶│ Platform    │◀─────────────┘               │
│                   │ (Auth)      │                              │
│                   └─────────────┘                              │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │ Artifact    │    │ Cloud       │    │ Secret      │        │
│  │ Registry    │    │ Storage     │    │ Manager     │        │
│  │ (Images)    │    │ (Backups)   │    │ (Secrets)   │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Build System Architecture

### Composition at Build Time

The build system combines public core code with private sponsor code to produce deployable artifacts.

**Build Process Flow**:

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: VALIDATE sponsor repository                             │
│   - Repository structure                                        │
│   - Required implementations (SponsorConfig, EdcSync, etc.)     │
│   - Contract test compliance                                    │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: COPY sponsor code into build workspace                  │
│   - lib/ (Dart implementation)                                  │
│   - assets/ (branding, fonts, images)                           │
│   - config/ (build configuration)                               │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: COMPOSE core + sponsor into unified codebase            │
│   - Merge dependency trees                                      │
│   - Apply sponsor theme overrides                               │
│   - Generate integration glue code                              │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: BUILD artifacts                                         │
│   - Mobile: IPA (iOS) or APK/AAB (Android)                      │
│   - Portal: Static web assets (HTML/JS/CSS)                     │
│   - Backend: Docker container (Dart server)                     │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 5: PACKAGE for deployment                                  │
│   - Sign mobile binaries                                        │
│   - Push container to Artifact Registry                         │
│   - Generate deployment manifests                               │
└─────────────────────────────────────────────────────────────────┘
```

### Build Scripts

**Location**: `clinical-diary/tools/build_system/`

**Core Scripts**:

1. **validate_sponsor.dart** - Validates sponsor repository structure
2. **build_mobile.dart** - Builds mobile app (iOS/Android)
3. **build_portal.dart** - Builds portal (Flutter Web)
4. **build_server.dart** - Builds Dart server Docker image
5. **deploy.dart** - Orchestrates deployment to GCP

---

## Build Commands

### Backend Server Build

**Command Structure**:

```bash
dart run tools/build_system/build_server.dart \
  --sponsor-repo <path-to-sponsor-repo> \
  --environment <staging|production>
```

**Docker Build**:

```bash
# Build Dart server container
docker build -t clinical-diary-api:latest \
  -f apps/server/Dockerfile .

# Tag for Artifact Registry
docker tag clinical-diary-api:latest \
  ${REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:${VERSION}

# Push to Artifact Registry
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:${VERSION}
```

**Dockerfile Example** (`apps/server/Dockerfile`):

```dockerfile
# Build stage
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/bin/server /app/bin/server

# Cloud Run expects PORT environment variable
ENV PORT=8080
EXPOSE 8080

CMD ["/app/bin/server"]
```

### Mobile App Build

**Command Structure**:

```bash
dart run tools/build_system/build_mobile.dart \
  --sponsor-repo <path-to-sponsor-repo> \
  --platform <ios|android> \
  --environment <staging|production>
```

**Examples**:

```bash
# Build Orion iOS app for production
dart run tools/build_system/build_mobile.dart \
  --sponsor-repo ../clinical-diary-orion \
  --platform ios \
  --environment production

# Build Andromeda Android app for staging
dart run tools/build_system/build_mobile.dart \
  --sponsor-repo ../clinical-diary-andromeda \
  --platform android \
  --environment staging
```

**Output**:
- iOS: `build/ios/ipa/ClinicalDiary.ipa`
- Android: `build/android/app/release/app-release.aab` (or `.apk`)

### Portal Build

**Command Structure**:

```bash
dart run tools/build_system/build_portal.dart \
  --sponsor-repo <path-to-sponsor-repo> \
  --environment <staging|production>
```

**Example**:

```bash
# Build Orion portal for production
dart run tools/build_system/build_portal.dart \
  --sponsor-repo ../clinical-diary-orion \
  --environment production
```

**Output**: `build/web/` (static site ready for Cloud Run or Firebase Hosting)

---

## CI/CD Pipelines

### Sponsor Repository Workflow

**File**: `.github/workflows/deploy_production.yml` (in sponsor repo)

**Trigger**: Push to `main` branch or manual workflow dispatch

```yaml
name: Deploy Production

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  REGION: us-central1
  PROJECT_ID: clinical-diary-${{ vars.SPONSOR }}-prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      # 1. Checkout sponsor repository
      - uses: actions/checkout@v4
        with:
          path: sponsor

      # 2. Clone public core repository
      - uses: actions/checkout@v4
        with:
          repository: yourorg/clinical-diary
          ref: v1.2.0  # Pinned version
          path: core

      # 3. Setup Dart/Flutter
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'

      # 4. Authenticate to GCP
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ vars.DEPLOY_SA }}

      # 5. Setup gcloud CLI
      - uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: ${{ env.PROJECT_ID }}

      # 6. Validate sponsor repository
      - name: Validate Sponsor Repo
        run: |
          cd core
          dart run tools/build_system/validate_sponsor.dart \
            --sponsor-repo ../sponsor

      # 7. Run contract tests
      - name: Contract Tests
        run: |
          cd sponsor
          flutter test test/contracts/

      # 8. Build and push Docker image
      - name: Build Server Container
        run: |
          cd core
          docker build -t ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/clinical-diary/api:${{ github.sha }} \
            -f apps/server/Dockerfile .

      - name: Push to Artifact Registry
        run: |
          gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev
          docker push ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/clinical-diary/api:${{ github.sha }}

      # 9. Deploy to Cloud Run
      - name: Deploy API to Cloud Run
        uses: google-github-actions/deploy-cloudrun@v2
        with:
          service: clinical-diary-api
          region: ${{ env.REGION }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/clinical-diary/api:${{ github.sha }}
          flags: |
            --service-account=${{ vars.CLOUD_RUN_SA }}
            --vpc-connector=${{ vars.VPC_CONNECTOR }}
            --vpc-egress=private-ranges-only
            --add-cloudsql-instances=${{ vars.CLOUD_SQL_INSTANCE }}
            --set-env-vars=ENVIRONMENT=production,SPONSOR_ID=${{ vars.SPONSOR }},GCP_PROJECT_ID=${{ env.PROJECT_ID }}
            --set-secrets=DATABASE_URL=database-url:latest

      # 10. Build portal
      - name: Build Portal
        run: |
          cd core
          dart run tools/build_system/build_portal.dart \
            --sponsor-repo ../sponsor \
            --environment production

      # 11. Deploy portal to Cloud Run (static site)
      - name: Deploy Portal
        run: |
          cd core/build/web
          gcloud run deploy clinical-diary-portal \
            --source . \
            --region ${{ env.REGION }} \
            --allow-unauthenticated

      # 12. Run database migrations
      - name: Run Database Migrations
        run: |
          # Start Cloud SQL Proxy
          wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
          chmod +x cloud_sql_proxy
          ./cloud_sql_proxy -instances=${{ vars.CLOUD_SQL_INSTANCE }}=tcp:5432 &
          sleep 5

          # Run migrations
          cd core/packages/database
          doppler run --config production -- dbmate up

      # 13. Build mobile apps
      - name: Build iOS
        run: |
          cd core
          dart run tools/build_system/build_mobile.dart \
            --sponsor-repo ../sponsor \
            --platform ios \
            --environment production

      - name: Build Android
        run: |
          cd core
          dart run tools/build_system/build_mobile.dart \
            --sponsor-repo ../sponsor \
            --platform android \
            --environment production

      # 14. Upload mobile artifacts
      - name: Upload iOS Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ios-production
          path: core/build/ios/ipa/ClinicalDiary.ipa

      - name: Upload Android Artifact
        uses: actions/upload-artifact@v4
        with:
          name: android-production
          path: core/build/android/app/release/app-release.aab

      # 15. Verify deployment
      - name: Verify Deployment
        run: |
          API_URL=$(gcloud run services describe clinical-diary-api --region=${{ env.REGION }} --format='value(status.url)')
          curl -f "$API_URL/health" || exit 1
          echo "✅ API deployment verified"
```

---

## Environment Configuration

# REQ-o00001: Separate GCP Projects Per Sponsor

**Level**: Ops | **Implements**: p00001 | **Status**: Active

Each sponsor SHALL be provisioned with dedicated GCP projects for staging and production environments, ensuring complete infrastructure isolation.

Each GCP project SHALL provide:
- Isolated Cloud SQL PostgreSQL database
- Unique Cloud Run services with sponsor-specific URLs
- Independent Identity Platform configuration and user pools
- Separate Cloud Storage buckets for file uploads
- Dedicated service accounts and IAM roles

**Rationale**: Implements multi-sponsor data isolation (p00001) at the infrastructure level using GCP's project isolation guarantees. Each sponsor's GCP project is a completely separate deployment with its own resources.

**Acceptance Criteria**:
- Each sponsor has unique GCP project for staging and production
- Database connections cannot span projects
- Service accounts are project-specific
- No shared configuration between sponsors
- Project provisioning documented in runbook

*End* *Separate GCP Projects Per Sponsor* | **Hash**: 6d281a2e
---

# REQ-o00002: Environment-Specific Configuration Management

**Level**: Ops | **Implements**: p00001 | **Status**: Active

Configuration containing environment-specific credentials SHALL be stored securely via Doppler and GCP Secret Manager, and SHALL NOT be committed to version control.

Each sponsor environment SHALL maintain:
- Doppler project/config for secrets management
- GCP Secret Manager for Cloud Run secrets
- GitHub Secrets for CI/CD pipelines
- No hardcoded credentials in source code

**Rationale**: Prevents accidental credential sharing between sponsors and ensures proper secret management per security best practices.

**Acceptance Criteria**:
- `.gitignore` includes `*.env` files
- CI/CD pipelines use Workload Identity Federation
- Secrets accessed via Secret Manager in Cloud Run
- No credentials found in git history

*End* *Environment-Specific Configuration Management* | **Hash**: c6ed3379
---

### Environment Types

**Environments**:
1. **Local Development**: Developer machine with Cloud SQL Proxy
2. **Staging**: Testing and UAT environment (separate GCP project)
3. **Production**: Live clinical trial environment (separate GCP project)

### Configuration Files

**Sponsor Repository**: `config/` directory

```
config/
├── mobile.yaml          # Mobile app build configuration
├── portal.yaml          # Portal build configuration
├── server.yaml          # Server configuration
└── cloudbuild.yaml      # Cloud Build configuration (optional)
```

**mobile.yaml Example**:

```yaml
app:
  name: "Clinical Diary"
  bundle_id: "com.clinicaldiary.orion"
  version: "1.2.3"
  build_number: 42

branding:
  primary_color: "#0066CC"
  logo: "assets/logo.png"
  icon: "assets/icon.png"

features:
  offline_mode: true
  biometric_auth: true
  push_notifications: true

# GCP Configuration (environment-specific values from Doppler)
gcp:
  firebase_project_id: "${FIREBASE_PROJECT_ID}"
```

**server.yaml Example**:

```yaml
server:
  port: 8080
  host: "0.0.0.0"

database:
  pool_size: 10
  timeout_seconds: 30

# Cloud SQL connection (via Unix socket in Cloud Run)
cloud_sql:
  instance_connection_name: "${DATABASE_INSTANCE}"
```

### Doppler Configuration

**Project Structure**:

```
clinical-diary-{sponsor}/
├── development     # Local development
├── staging         # Staging environment
└── production      # Production environment
```

**Required Variables**:

| Variable | Description | Example |
| --- | --- | --- |
| `DATABASE_URL` | Cloud SQL connection string | `postgresql://...` |
| `DATABASE_INSTANCE` | Cloud SQL instance name | `project:region:instance` |
| `GCP_PROJECT_ID` | GCP project ID | `clinical-diary-orion-prod` |
| `SPONSOR_ID` | Sponsor identifier | `orion` |
| `FIREBASE_PROJECT_ID` | Identity Platform project | `clinical-diary-orion-prod` |
| `FIREBASE_API_KEY` | Firebase API key | `AIza...` |

### GitHub Variables and Secrets

**Variables** (per sponsor repository):

| Variable | Description |
| --- | --- |
| `SPONSOR` | Sponsor identifier |
| `WIF_PROVIDER` | Workload Identity Federation provider |
| `DEPLOY_SA` | Deployment service account email |
| `CLOUD_RUN_SA` | Cloud Run service account email |
| `VPC_CONNECTOR` | VPC connector name |
| `CLOUD_SQL_INSTANCE` | Cloud SQL instance connection name |

**Secrets**:

| Secret | Description |
| --- | --- |
| `DOPPLER_TOKEN_PROD` | Doppler service token (production) |
| `DOPPLER_TOKEN_STAGING` | Doppler service token (staging) |
| `APPLE_CERTIFICATE` | iOS code signing certificate |
| `ANDROID_KEYSTORE` | Android keystore file |

---

## Cloud Run Deployment

### Deploy API Server

```bash
# Deploy to Cloud Run
gcloud run deploy clinical-diary-api \
  --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/clinical-diary/api:${VERSION} \
  --region=${REGION} \
  --platform=managed \
  --service-account=${CLOUD_RUN_SA} \
  --vpc-connector=${VPC_CONNECTOR} \
  --vpc-egress=private-ranges-only \
  --add-cloudsql-instances=${CLOUD_SQL_INSTANCE} \
  --set-env-vars="ENVIRONMENT=production,SPONSOR_ID=${SPONSOR},GCP_PROJECT_ID=${PROJECT_ID}" \
  --set-secrets="DATABASE_URL=database-url:latest,FIREBASE_API_KEY=firebase-api-key:latest" \
  --min-instances=1 \
  --max-instances=10 \
  --memory=512Mi \
  --cpu=1 \
  --timeout=60s \
  --allow-unauthenticated
```

### Deploy Portal (Static Site)

**Option 1: Cloud Run (recommended for consistency)**

```bash
# From build/web directory
gcloud run deploy clinical-diary-portal \
  --source . \
  --region=${REGION} \
  --allow-unauthenticated
```

**Option 2: Firebase Hosting**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize (one-time)
firebase init hosting

# Deploy
firebase deploy --only hosting
```

### Health Check Endpoint

**Server Implementation** (`bin/server.dart`):

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final router = Router()
  ..get('/health', (Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'healthy',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'version': Platform.environment['K_REVISION'] ?? 'unknown',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });
```

---

## Database Deployment

### Schema Deployment to Cloud SQL

**Prerequisites**:
- Cloud SQL Proxy for local access
- Database migration tool (dbmate recommended)
- Doppler for credentials

**Deployment Steps**:

#### 1. Start Cloud SQL Proxy

```bash
# Download Cloud SQL Proxy
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
chmod +x cloud_sql_proxy

# Start proxy
./cloud_sql_proxy -instances=${PROJECT_ID}:${REGION}:${INSTANCE_NAME}=tcp:5432 &
```

#### 2. Run Migrations

```bash
# Set database URL for local proxy
export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@127.0.0.1:5432/${DB_NAME}?sslmode=disable"

# Run migrations with dbmate
dbmate up

# Or with Doppler
doppler run --config production -- dbmate up
```

#### 3. Deploy Core Schema

```bash
# Deploy from core repository
psql $DATABASE_URL -f packages/database/schema.sql
psql $DATABASE_URL -f packages/database/triggers.sql
psql $DATABASE_URL -f packages/database/functions.sql
psql $DATABASE_URL -f packages/database/rls_policies.sql
psql $DATABASE_URL -f packages/database/indexes.sql
```

#### 4. Deploy Sponsor Extensions

```bash
# Deploy sponsor-specific tables/functions
psql $DATABASE_URL -f sponsor/database/extensions.sql
```

#### 5. Verify Deployment

```bash
# Verify tables
psql $DATABASE_URL -c "\dt"

# Run integration tests
flutter test integration_test/database_test.dart
```

---

## Release Procedures

### FDA 21 CFR Part 11 Compliant Workflow

**Developer Workflow**:

```
develop branch
    │
    │ (feature branches merge here)
    │
    ▼
release/1.2.3 branch ← Create from develop
    │
    │ (deploy to staging)
    │
    ▼
  UAT / Validation
    │
    │ (bug fixes applied to release branch)
    │
    ▼
git tag v1.2.3 ← Apply tag (immutable record)
    │
    │ (deploy to production)
    │
    ▼
merge to main ← Official release record
    │
    └─→ merge back to develop
```

**Step-by-Step Release Process**:

#### Step 1: Create Release Branch

```bash
# From develop branch
git checkout develop
git pull origin develop

# Create release branch
git checkout -b release/1.2.3

# Push to remote
git push -u origin release/1.2.3
```

#### Step 2: Deploy to Staging

```bash
# Trigger staging deployment (automatic via GitHub Actions)
# Or manually deploy to staging GCP project
gcloud config set project ${STAGING_PROJECT_ID}

gcloud run deploy clinical-diary-api \
  --image=${REGION}-docker.pkg.dev/${STAGING_PROJECT_ID}/clinical-diary/api:${COMMIT_SHA} \
  --region=${REGION} \
  # ... other flags
```

#### Step 3: User Acceptance Testing (UAT)

**Validation Protocol**:
- [ ] All contract tests pass
- [ ] Integration tests pass against staging database
- [ ] Portal loads without errors
- [ ] Mobile app syncs correctly
- [ ] Audit trail captures all changes
- [ ] RLS policies enforce access control
- [ ] EDC sync functional (if proxy mode)
- [ ] Backup/restore tested
- [ ] Performance benchmarks met
- [ ] Security scan passes
- [ ] Compliance checklist complete

#### Step 4: Tag Release

**After UAT passes**:

```bash
git checkout release/1.2.3
git pull origin release/1.2.3

# Create annotated tag
git tag -a v1.2.3 -m "Release 1.2.3 - Production validated $(date -I)"

# Push tag (triggers production deployment)
git push origin v1.2.3
```

#### Step 5: Deploy to Production

**Automatic deployment via GitHub Actions**:
- Triggered by tag push
- Builds from tagged commit
- Deploys to production GCP project
- Publishes mobile artifacts for app store submission

#### Step 6: Merge Release Branch

```bash
# Merge to main (official record)
git checkout main
git merge --no-ff release/1.2.3 -m "Merge release 1.2.3"
git push origin main

# Merge back to develop
git checkout develop
git merge --no-ff release/1.2.3 -m "Merge release 1.2.3 to develop"
git push origin develop

# Delete release branch (optional)
git branch -d release/1.2.3
git push origin --delete release/1.2.3
```

# REQ-o00010: Mobile App Release Process

**Level**: Ops | **Implements**: p00008 | **Status**: Active

The mobile application SHALL be released as a single app package containing all sponsor configurations, with releases coordinated across iOS App Store and Google Play Store.

Mobile app release SHALL include:
- Single app build containing all active sponsor configurations
- Coordinated release to both iOS and Google Play stores
- Version number incremented consistently across platforms
- Release notes covering all sponsor-relevant changes
- Testing across all sponsor configurations before release

**Rationale**: Implements single mobile app requirement (p00008) through operational release procedures.

**Acceptance Criteria**:
- One app package serves all sponsors
- iOS and Android versions synchronized
- All sponsor configurations tested before release
- Update deployment automated via CI/CD

*End* *Mobile App Release Process* | **Hash**: 6985c040
---

#### Step 7: Mobile App Store Submission

**iOS (App Store Connect)**:

```bash
# Upload IPA to App Store Connect
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/ClinicalDiary.ipa \
  --apiKey $APP_STORE_CONNECT_KEY \
  --apiIssuer $APP_STORE_CONNECT_ISSUER
```

**Android (Google Play Console)**:

```bash
# Upload AAB to Google Play (internal track for testing)
fastlane supply \
  --aab build/android/app/release/app-release.aab \
  --track internal \
  --json_key google-play-service-account.json
```

---

## Portal Deployment

# REQ-o00009: Portal Deployment Per Sponsor

**Level**: Ops | **Implements**: p00009 | **Status**: Active

Each sponsor SHALL have their web portal deployed to a unique URL with sponsor-specific configuration, ensuring complete portal isolation between sponsors.

Portal deployment SHALL include:
- Static site build from core + sponsor customizations
- Deployment to Cloud Run or Firebase Hosting per sponsor
- Sponsor-specific API endpoint configuration
- Independent deployment pipeline per sponsor
- Separate GCP project per sponsor

**Rationale**: Implements sponsor-specific portals requirement (p00009) through operational deployment procedures.

**Acceptance Criteria**:
- Each sponsor portal has unique URL
- Portal configuration includes only that sponsor's API endpoint
- Deployment process automated via CI/CD
- Portal cannot access other sponsors' APIs
- Rollback capability per sponsor portal

*End* *Portal Deployment Per Sponsor* | **Hash**: d0b93523
---

### Cloud Run Static Site Deployment

```bash
# Build portal
dart run tools/build_system/build_portal.dart \
  --sponsor-repo ../sponsor-repo \
  --environment production

# Deploy to Cloud Run
cd build/web
gcloud run deploy clinical-diary-portal \
  --source . \
  --region=${REGION} \
  --allow-unauthenticated \
  --set-env-vars="API_URL=https://clinical-diary-api-xxxxx.run.app"
```

### Custom Domain Configuration

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service=clinical-diary-portal \
  --domain=portal.orion.clinical-diary.com \
  --region=${REGION}

# Get DNS records to configure
gcloud run domain-mappings describe \
  --domain=portal.orion.clinical-diary.com \
  --region=${REGION}
```

---

## Validation Checklist

### Pre-Deployment Validation

**Before each production deployment**:

#### Code Quality
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Contract tests pass (sponsor implements all interfaces)
- [ ] No linting errors
- [ ] Code coverage >80%

#### Security
- [ ] `dart pub audit` shows no critical vulnerabilities
- [ ] Container vulnerability scan passes
- [ ] Secrets not committed to repository
- [ ] All dependencies up to date

#### Database
- [ ] Migration scripts tested on staging
- [ ] Backup created before deployment
- [ ] RLS policies enforced
- [ ] Audit trail functional

#### Compliance
- [ ] 21 CFR Part 11 checklist complete
- [ ] Audit trail captures all changes
- [ ] ALCOA+ validation passes
- [ ] Change control documentation complete

#### Functionality
- [ ] UAT sign-off received
- [ ] Performance benchmarks met
- [ ] Mobile app syncs correctly
- [ ] Portal accessible and functional

#### Release
- [ ] Release notes prepared
- [ ] Version number incremented
- [ ] Git tag created and pushed
- [ ] Rollback plan documented

---

## Rollback Procedures

### Cloud Run Rollback

```bash
# List revisions
gcloud run revisions list --service=clinical-diary-api --region=${REGION}

# Rollback to previous revision
gcloud run services update-traffic clinical-diary-api \
  --region=${REGION} \
  --to-revisions=clinical-diary-api-00005-xxx=100
```

### Database Rollback

```bash
# Rollback migration
doppler run --config production -- dbmate down

# Or restore from Cloud SQL backup
gcloud sql backups list --instance=${INSTANCE_NAME}
gcloud sql backups restore ${BACKUP_ID} \
  --restore-instance=${INSTANCE_NAME}

# Or use point-in-time recovery
gcloud sql instances clone ${INSTANCE_NAME} ${NEW_INSTANCE_NAME} \
  --point-in-time='2025-01-24T12:00:00Z'
```

### Mobile App Rollback

**iOS**: Use App Store Connect to remove new version from release
**Android**: Use Google Play Console to halt rollout or revert to previous version

**Note**: Mobile rollback impacts ALL sponsors (single app). Coordinate carefully.

---

## Monitoring Deployment Health

**Post-Deployment Checks** (first 24 hours):

- [ ] API accessible (check Cloud Run logs)
- [ ] Mobile app syncs successfully
- [ ] Database connections healthy (Cloud SQL metrics)
- [ ] Error rates within normal range (Cloud Error Reporting)
- [ ] API response times <500ms (p95)
- [ ] No security alerts
- [ ] Audit trail capturing events

**See**: ops-monitoring-observability.md for detailed monitoring procedures

---

## Troubleshooting

### Build Failures

**Validation Errors**:
```bash
# Check detailed validation output
dart run tools/build_system/validate_sponsor.dart \
  --sponsor-repo ../sponsor-repo \
  --verbose
```

**Contract Test Failures**:
```bash
# Run contract tests locally
cd sponsor-repo
flutter test test/contracts/ --reporter expanded
```

### Cloud Run Deployment Failures

**Check Logs**:
```bash
gcloud run services logs read clinical-diary-api --region=${REGION}
```

**Common Issues**:
- Container fails to start: Check Dockerfile and health endpoint
- Permission denied: Verify service account roles
- Cannot connect to Cloud SQL: Check VPC connector and Cloud SQL instance

### Database Deployment Failures

**Migration Conflicts**:
```bash
# View pending migrations
dbmate status

# Reset database (staging only!)
dbmate drop && dbmate up
```

**Connection Errors**:
- Verify Cloud SQL Proxy is running
- Check VPC connector configuration
- Confirm service account has Cloud SQL Client role

---

## References

- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Implementation**: dev-database.md
- **Development Practices**: dev-core-practices.md
- **Compliance Practices**: dev-compliance-practices.md
- **Daily Operations**: ops-operations.md
- **Security Operations**: ops-security.md
- **Monitoring**: ops-monitoring-observability.md

---

**Document Status**: Active operations guide
**Review Cycle**: After each deployment or quarterly
**Owner**: DevOps Team / Release Manager

---

## Change History

 | Version | Date | Changes | Author |
 | --- | --- | --- | --- |
 | 1.0 | 2025-01-24 | Initial guide (Supabase) | Development Team |
 | 2.0 | 2025-11-24 | Migration to GCP (Cloud Run, Cloud SQL, Artifact Registry) | Claude |
