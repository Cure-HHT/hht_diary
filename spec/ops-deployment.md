# Deployment Operations Guide

**Version**: 1.0
**Audience**: Operations (DevOps, Release Managers, Platform Engineers)
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture overview
> **See**: dev-database.md for database implementation details
> **See**: ops-operations.md for daily monitoring and incident response
> **See**: dev-core-practices.md for development standards

---

## Executive Summary

Comprehensive guide for building, deploying, and releasing the multi-sponsor clinical diary system. Covers build system usage, CI/CD pipelines, environment configuration, and FDA 21 CFR Part 11 compliant release procedures.

**Architecture**: Single public core repository + private sponsor repositories
**Build System**: Dart-based composition of core + sponsor code
**CI/CD**: GitHub Actions with automated validation
**Deployments**:
- Mobile: Single app containing all sponsors (App Store + Google Play)
- Portal: Separate deployment per sponsor (Netlify static site)
- Database: Per-sponsor Supabase instance
- Edge Functions: Per-sponsor Deno runtime on Supabase

---

## Build System Architecture

### Composition at Build Time

The build system combines public core code with private sponsor code to produce deployable artifacts.

**Build Process Flow**:

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: VALIDATE sponsor repository                        │
│   - Repository structure                                   │
│   - Required implementations (SponsorConfig, EdcSync, etc.)│
│   - Contract test compliance                               │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 2: COPY sponsor code into build workspace             │
│   - lib/ (Dart implementation)                             │
│   - assets/ (branding, fonts, images)                      │
│   - config/ (build configuration)                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 3: COMPOSE core + sponsor into unified codebase       │
│   - Merge dependency trees                                 │
│   - Apply sponsor theme overrides                          │
│   - Generate integration glue code                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 4: GENERATE integration code                          │
│   - Dependency injection bindings                          │
│   - Route registrations                                    │
│   - Feature flag configurations                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 5: BUILD Flutter artifacts                            │
│   - Mobile: IPA (iOS) or APK/AAB (Android)                 │
│   - Portal: Static web assets (HTML/JS/CSS)                │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Step 6: PACKAGE for deployment                             │
│   - Sign mobile binaries                                   │
│   - Generate deployment manifests                          │
│   - Create release artifacts                               │
└─────────────────────────────────────────────────────────────┘
```

### Build Scripts

**Location**: `clinical-diary/tools/build_system/`

**Core Scripts**:

1. **validate_sponsor.dart** - Validates sponsor repository structure
2. **build_mobile.dart** - Builds mobile app (iOS/Android)
3. **build_portal.dart** - Builds portal (Flutter Web)
4. **deploy.dart** - Orchestrates deployment to Supabase + hosting

---

## Build Commands

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

**Output**: `build/web/` (static site ready for Netlify deployment)

### Validation

**Command**:

```bash
dart run tools/build_system/validate_sponsor.dart \
  --sponsor-repo <path-to-sponsor-repo>
```

**Checks**:
- Repository structure compliance
- Required files present
- SponsorConfig implementation
- Contract test pass rate
- No prohibited content (secrets, PII)

**Exit Codes**:
- `0`: Validation passed
- `1`: Validation failed (build should not proceed)

---

## CI/CD Pipelines

### Sponsor Repository Workflow

**File**: `.github/workflows/deploy_production.yml` (in sponsor repo)

**Trigger**: Push to `main` branch or manual workflow dispatch

**Workflow Steps**:

```yaml
name: Deploy Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
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

      # 4. Validate sponsor repository
      - name: Validate Sponsor Repo
        run: |
          cd core
          dart run tools/build_system/validate_sponsor.dart \
            --sponsor-repo ../sponsor

      # 5. Run contract tests
      - name: Contract Tests
        run: |
          cd sponsor
          flutter test test/contracts/

      # 6. Build mobile app (iOS)
      - name: Build iOS
        run: |
          cd core
          dart run tools/build_system/build_mobile.dart \
            --sponsor-repo ../sponsor \
            --platform ios \
            --environment production
        env:
          APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
          APPLE_PROVISIONING_PROFILE: ${{ secrets.APPLE_PROVISIONING_PROFILE }}

      # 7. Build mobile app (Android)
      - name: Build Android
        run: |
          cd core
          dart run tools/build_system/build_mobile.dart \
            --sponsor-repo ../sponsor \
            --platform android \
            --environment production
        env:
          ANDROID_KEYSTORE: ${{ secrets.ANDROID_KEYSTORE }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}

      # 8. Build portal
      - name: Build Portal
        run: |
          cd core
          dart run tools/build_system/build_portal.dart \
            --sponsor-repo ../sponsor \
            --environment production

      # 9. Deploy portal to Netlify
      - name: Deploy Portal
        uses: nwtgck/actions-netlify@v2
        with:
          publish-dir: './core/build/web'
          production-deploy: true
          github-token: ${{ secrets.GITHUB_TOKEN }}
          deploy-message: "Deploy from GitHub Actions"
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}

      # 10. Deploy database schema to Supabase
      - name: Deploy Database
        run: |
          cd sponsor
          npx supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
          npx supabase db push --include ../core/packages/database/
          npx supabase db push --include ./database/extensions.sql
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      # 11. Deploy Edge Functions
      - name: Deploy Edge Functions
        if: ${{ vars.DEPLOYMENT_MODE == 'proxy' }}
        run: |
          cd sponsor/edge_functions
          npx supabase functions deploy edc_sync \
            --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      # 12. Upload mobile artifacts
      - name: Upload iOS Artifact
        uses: actions/upload-artifact@v3
        with:
          name: ios-production
          path: core/build/ios/ipa/ClinicalDiary.ipa

      - name: Upload Android Artifact
        uses: actions/upload-artifact@v3
        with:
          name: android-production
          path: core/build/android/app/release/app-release.aab
```

### Staging Workflow

**File**: `.github/workflows/deploy_staging.yml`

**Differences from Production**:
- Triggers on push to `develop` branch
- Uses staging Supabase project
- Deploys to Netlify preview URL
- Skips mobile app store submission

---

## Environment Configuration

# REQ-o00001: Separate Supabase Projects Per Sponsor

**Level**: Ops | **Implements**: p00001 | **Status**: Active

Each sponsor SHALL be provisioned with dedicated Supabase projects for staging and production environments, ensuring complete infrastructure isolation.

Each Supabase project SHALL provide:
- Isolated PostgreSQL database (no shared tables or connections)
- Unique API endpoints with sponsor-specific URLs
- Independent authentication configuration and user pools
- Separate storage buckets for file uploads
- Dedicated Edge Functions runtime environment

**Rationale**: Implements multi-sponsor data isolation (p00001) at the infrastructure level using Supabase's project isolation guarantees. Each sponsor's Supabase project is a completely separate deployment with its own resources, ensuring no possibility of cross-sponsor data access.

**Acceptance Criteria**:
- Each sponsor has unique Supabase project URLs for staging and production
- Database connections cannot span projects
- API keys are project-specific and cannot authenticate to other sponsors' projects
- No shared configuration files between sponsors
- Project provisioning documented in runbook

*End* *Separate Supabase Projects Per Sponsor* | **Hash**: 970de2df
---

# REQ-o00002: Environment-Specific Configuration Management

**Level**: Ops | **Implements**: p00001 | **Status**: Active

Configuration files containing environment-specific credentials SHALL be stored securely and SHALL NOT be committed to version control.

Each sponsor repository SHALL maintain:
- `config/supabase.staging.env` - Staging credentials (gitignored)
- `config/supabase.prod.env` - Production credentials (gitignored)
- GitHub Secrets for CI/CD pipelines
- No hardcoded credentials in source code

**Rationale**: Prevents accidental credential sharing between sponsors and ensures proper secret management per security best practices.

**Acceptance Criteria**:
- `.gitignore` includes `*.env` files
- CI/CD pipelines use GitHub Secrets, not committed credentials
- Build scripts validate presence of required environment variables
- No credentials found in git history

*End* *Environment-Specific Configuration Management* | **Hash**: 8786c322
---

### Environment Types

**Environments**:
1. **Local Development**: Developer machine
2. **Staging**: Testing and UAT environment
3. **Production**: Live clinical trial environment

### Configuration Files

**Sponsor Repository**: `config/` directory

```
config/
├── mobile.yaml          # Mobile app build configuration
├── portal.yaml          # Portal build configuration
├── supabase.staging.env # Staging credentials (gitignored)
└── supabase.prod.env    # Production credentials (gitignored)
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
```

**portal.yaml Example**:

```yaml
portal:
  title: "Orion Clinical Trial Portal"
  domain: "orion-portal.clinicaldiary.com"
  theme: "orion"

features:
  custom_reports: true
  data_export: true
  real_time_dashboard: true
```

**supabase.prod.env Example** (gitignored):

```bash
SUPABASE_PROJECT_REF=abcd1234efgh5678
SUPABASE_URL=https://abcd1234efgh5678.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# EDC Integration (proxy mode only)
EDC_API_URL=https://rave.mdsol.com/api/v1
EDC_API_KEY=secret-key-here
```

### GitHub Secrets

**Required Secrets** (per sponsor repository):

**Supabase**:
- `SUPABASE_PROJECT_REF` - Project reference ID
- `SUPABASE_ACCESS_TOKEN` - Service account token
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for migrations

**Netlify**:
- `NETLIFY_AUTH_TOKEN` - Netlify authentication token
- `NETLIFY_SITE_ID` - Portal site ID

**Apple (iOS)**:
- `APPLE_CERTIFICATE` - Code signing certificate (base64 encoded)
- `APPLE_PROVISIONING_PROFILE` - Provisioning profile (base64 encoded)
- `APPLE_TEAM_ID` - Apple Developer Team ID
- `APP_STORE_CONNECT_KEY` - API key for App Store submission

**Google (Android)**:
- `ANDROID_KEYSTORE` - Keystore file (base64 encoded)
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password
- `ANDROID_STORE_PASSWORD` - Keystore password
- `GOOGLE_PLAY_SERVICE_ACCOUNT` - Service account JSON (base64 encoded)

**EDC (Proxy Mode)**:
- `EDC_API_URL` - EDC system API endpoint
- `EDC_API_KEY` - EDC authentication key

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
# Or manually:
cd sponsor-repo
git checkout release/1.2.3

# Build and deploy staging
cd ../clinical-diary
dart run tools/build_system/build_portal.dart \
  --sponsor-repo ../sponsor-repo \
  --environment staging
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

**Bug Fixes**: Apply fixes directly to release branch

```bash
git checkout release/1.2.3
# ... make fixes ...
git commit -m "Fix: [description]"
git push origin release/1.2.3
```

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

**Tag naming convention**: `v<major>.<minor>.<patch>`

#### Step 5: Deploy to Production

**Automatic deployment via GitHub Actions**:
- Triggered by tag push
- Builds from tagged commit
- Deploys portal to production Netlify site
- Publishes mobile artifacts for app store submission

**Manual deployment** (if needed):

```bash
cd clinical-diary
dart run tools/build_system/deploy.dart \
  --sponsor-repo ../sponsor-repo \
  --tag v1.2.3 \
  --environment production
```

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

**Rationale**: Implements single mobile app requirement (p00008) through operational release procedures. Coordinated release ensures all sponsors benefit from updates simultaneously while maintaining single app approach.

**Acceptance Criteria**:
- One app package serves all sponsors
- iOS and Android versions synchronized
- All sponsor configurations tested before release
- App store listings reference single app for all sponsors
- Update deployment automated via CI/CD

*End* *Mobile App Release Process* | **Hash**: 34b8dd28
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

**Note**: Mobile app contains ALL sponsors. Single release includes all sponsor configurations.

---

## Database Deployment

### Schema Deployment to Supabase

**Prerequisites**:
- Supabase CLI installed: `npm install -g supabase`
- Supabase project created
- Service role key available

**Deployment Steps**:

#### 1. Link to Supabase Project

```bash
cd sponsor-repo
supabase link --project-ref abcd1234efgh5678
```

**Configuration**: Creates `.supabase/config.toml`

#### 2. Deploy Core Schema

```bash
# Deploy from core repository
supabase db push --include ../clinical-diary/packages/database/schema.sql
supabase db push --include ../clinical-diary/packages/database/rls_policies.sql
supabase db push --include ../clinical-diary/packages/database/functions.sql
supabase db push --include ../clinical-diary/packages/database/triggers.sql
```

**Alternatively**, use package from GitHub Package Registry:

```bash
npm install @clinical-diary/database@1.2.3

supabase db push --include node_modules/@clinical-diary/database/schema.sql
```

#### 3. Deploy Sponsor Extensions

```bash
# Deploy sponsor-specific tables/functions
supabase db push --include ./database/extensions.sql
```

#### 4. Verify Deployment

```bash
# Run migrations check
supabase db diff --schema public

# Run integration tests against database
flutter test integration_test/database_test.dart
```

#### 5. Create Backup Before Production

```bash
# Backup before production deployment
supabase db dump --data-only > backup-$(date +%Y%m%d-%H%M%S).sql
```

---

## Edge Functions Deployment

**Applicable to**: Proxy mode sponsors only

### Deploy Edge Functions to Supabase

#### 1. Prepare Edge Function

**Structure**: `sponsor-repo/edge_functions/edc_sync/index.ts`

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // EDC sync logic
  // ...

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
```

#### 2. Deploy Function

```bash
cd sponsor-repo/edge_functions

# Deploy to Supabase
supabase functions deploy edc_sync \
  --project-ref abcd1234efgh5678
```

#### 3. Set Function Secrets

```bash
# Set EDC API credentials
supabase secrets set EDC_API_URL=https://rave.mdsol.com/api/v1
supabase secrets set EDC_API_KEY=secret-key-here
```

#### 4. Configure Database Webhook

```sql
-- Trigger Edge Function on INSERT to record_audit
CREATE OR REPLACE FUNCTION trigger_edc_sync()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://abcd1234efgh5678.supabase.co/functions/v1/edc_sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := jsonb_build_object(
      'audit_id', NEW.audit_id,
      'event_uuid', NEW.event_uuid,
      'patient_id', NEW.patient_id,
      'data', NEW.data
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_record_audit_insert
  AFTER INSERT ON record_audit
  FOR EACH ROW
  EXECUTE FUNCTION trigger_edc_sync();
```

#### 5. Test Edge Function

```bash
# Test invocation
curl -i --location --request POST \
  'https://abcd1234efgh5678.supabase.co/functions/v1/edc_sync' \
  --header 'Authorization: Bearer SERVICE_ROLE_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"audit_id": 123, "event_uuid": "test-uuid"}'
```

---

## Portal Deployment

# REQ-o00009: Portal Deployment Per Sponsor

**Level**: Ops | **Implements**: p00009 | **Status**: Active

Each sponsor SHALL have their web portal deployed to a unique URL with sponsor-specific configuration, ensuring complete portal isolation between sponsors.

Portal deployment SHALL include:
- Static site build from core + sponsor customizations
- Deployment to unique domain or subdomain per sponsor
- Sponsor-specific Supabase connection configuration
- Independent deployment pipeline per sponsor
- Separate hosting account or project per sponsor

**Rationale**: Implements sponsor-specific portals requirement (p00009) through operational deployment procedures. Each sponsor's portal deployed independently ensures no cross-sponsor access or configuration leakage.

**Acceptance Criteria**:
- Each sponsor portal has unique URL
- Portal configuration includes only that sponsor's Supabase credentials
- Deployment process automated via CI/CD
- Portal cannot access other sponsors' databases
- Rollback capability per sponsor portal

*End* *Portal Deployment Per Sponsor* | **Hash**: 06ad75fd
---

### Netlify Static Site Deployment

**Prerequisites**:
- Netlify account
- Netlify CLI installed: `npm install -g netlify-cli`

#### 1. Build Portal

```bash
cd clinical-diary
dart run tools/build_system/build_portal.dart \
  --sponsor-repo ../sponsor-repo \
  --environment production
```

**Output**: `build/web/` directory

#### 2. Configure Netlify

**netlify.toml** (in sponsor repo):

```toml
[build]
  publish = "build/web"
  command = "echo 'Build completed via GitHub Actions'"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

[context.production]
  environment = { SUPABASE_URL = "https://abcd1234efgh5678.supabase.co", SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }

[context.staging]
  environment = { SUPABASE_URL = "https://staging-xyz.supabase.co", SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

#### 3. Deploy to Netlify

**Via CLI**:

```bash
cd sponsor-repo

# First time: Link site
netlify link --name orion-clinical-diary-portal

# Deploy production
netlify deploy --prod --dir=../clinical-diary/build/web
```

**Via GitHub Actions** (recommended):
- Automatic deployment on tag push
- See CI/CD pipeline section above

#### 4. Configure Custom Domain

```bash
# Add custom domain
netlify domains:add orion-portal.clinicaldiary.com

# Configure DNS (in domain registrar):
# CNAME orion-portal -> orion-clinical-diary-portal.netlify.app
```

#### 5. Enable HTTPS

**Automatic via Netlify**:
- SSL certificate provisioned automatically
- Enforce HTTPS: `netlify sites:update --enforce-https`

---

## Build Reports and Traceability

### Multi-Sponsor Build Reports Architecture

All build and validation reports are centralized in the `build-reports/` directory with per-sponsor isolation. This architecture supports FDA 21 CFR Part 11 compliance requirements for complete traceability and 7-year retention.

**See**: [ADR-007: Multi-Sponsor Build Reports Architecture](../docs/adr/ADR-007-multi-sponsor-build-reports.md) for complete architectural decision rationale.

### Directory Structure

```
build-reports/
├── README.md              # Documentation
├── templates/            # Template files (version controlled)
│   ├── jenkins/          # JUnit XML format templates
│   └── requirement_test_mapping.template.json
├── combined/             # Cross-sponsor aggregated reports
│   ├── traceability/     # Combined requirement traceability
│   ├── test-results/     # Aggregated test results
│   └── validation/       # Cross-sponsor validation
├── callisto/             # Callisto sponsor reports
│   ├── traceability/
│   ├── test-results/
│   └── validation/
└── titan/                # Titan sponsor reports
    ├── traceability/
    ├── test-results/
    └── validation/
```

### Report Categories

**Traceability Reports**:
- Requirement-to-code mapping (REQ-xxxxx to source files)
- Test coverage by requirement
- Compliance validation matrices
- Generated from git history and source annotations

**Test Results**:
- Unit test execution results (JUnit XML format)
- Integration test results
- End-to-end test results
- Test coverage reports (line, branch, function coverage)

**Validation Reports**:
- Spec compliance validation (spec/ directory structure)
- Git hook validation (requirement traceability enforcement)
- FDA 21 CFR Part 11 compliance checks
- ALCOA+ principles validation

### CI/CD Report Generation

Reports are automatically generated during:

**Pull Request Validation**:
```yaml
# In GitHub Actions workflow
- name: Generate Validation Reports
  run: |
    python3 tools/requirements/validate_requirements.py \
      --output build-reports/combined/validation/
    python3 tools/requirements/generate_traceability.py \
      --output build-reports/combined/traceability/
```

**Main Branch Builds**:
- Full test suite execution
- Comprehensive traceability matrix
- Per-sponsor report generation

**Release Builds**:
- Complete validation bundle
- Archival package creation
- S3 upload for long-term retention

### S3 Archival

Long-term archival follows FDA 21 CFR Part 11 requirements (7-year minimum retention):

**S3 Structure**:
```
s3://clinical-diary-build-reports/
├── core/
│   └── {git-tag}/              # e.g., v2025.11.12.a
│       └── {timestamp}/        # e.g., 20251112-143022
│           ├── combined/
│           │   ├── traceability/
│           │   ├── test-results/
│           │   └── validation/
│           ├── callisto/
│           └── titan/
└── sponsors/
    ├── callisto/
    │   └── {git-tag}/
    └── titan/
        └── {git-tag}/
```

**Upload Command**:
```bash
# Automated in GitHub Actions
aws s3 sync build-reports/ \
  s3://clinical-diary-build-reports/core/${GIT_TAG}/${TIMESTAMP}/ \
  --metadata "commit-sha=${COMMIT_SHA},build-user=${BUILD_USER}" \
  --storage-class STANDARD
```

**Lifecycle Policy**:
- First 90 days: S3 Standard (fast access)
- After 90 days: Glacier Deep Archive (long-term retention)
- Minimum retention: 7 years
- No automatic deletion

### Access Control

**GitHub Actions Artifacts**:
- 90-day retention for recent builds
- Accessible via GitHub Actions UI
- Requires repository access

**S3 Long-Term Archive**:
- IAM role-based access
- Read-only for most users
- Write access only for CI/CD service accounts
- Audit logging via AWS CloudTrail

**Access Commands**:
```bash
# List recent builds
aws s3 ls s3://clinical-diary-build-reports/core/

# Download specific report bundle
aws s3 cp s3://clinical-diary-build-reports/core/v2025.11.12.a/20251112-143022/ \
  ./reports/ --recursive

# Search for specific requirement traceability
aws s3 cp s3://clinical-diary-build-reports/core/v2025.11.12.a/20251112-143022/combined/traceability/REQ-p00001.json \
  ./reports/
```

### Local Report Generation

Developers can generate reports locally for debugging:

```bash
# Generate traceability matrix
python3 tools/requirements/generate_traceability.py \
  --output build-reports/combined/traceability/

# Run validation checks
python3 tools/requirements/validate_requirements.py \
  --output build-reports/combined/validation/

# Generate test coverage report
flutter test --coverage
genhtml coverage/lcov.info -o build-reports/combined/test-results/coverage/
```

**Note**: Locally generated reports are gitignored and not uploaded to S3.

### Tamper Evidence

**Integrity Verification**:
- Each report includes SHA-256 checksum
- S3 object versioning enabled
- Checksums verified on download

**Generate Checksum**:
```bash
# During report generation
sha256sum build-reports/combined/traceability/matrix.json > \
  build-reports/combined/traceability/matrix.json.sha256
```

**Verify Checksum**:
```bash
# After downloading from S3
sha256sum -c matrix.json.sha256
```

### Report Retention Policy

| Location | Retention | Purpose |
|----------|-----------|---------|
| **Local (build-reports/)** | Until cleaned | Development/debugging |
| **GitHub Actions** | 90 days | Recent build validation |
| **S3 Standard** | 90 days | Fast access to recent reports |
| **S3 Glacier** | 7+ years | FDA compliance archive |

### Troubleshooting

**Missing Reports**:
```bash
# Check if reports generated
ls -la build-reports/combined/

# Check CI/CD logs for generation failures
gh run view <run-id> --log
```

**S3 Access Issues**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check bucket permissions
aws s3api get-bucket-policy --bucket clinical-diary-build-reports

# List accessible reports
aws s3 ls s3://clinical-diary-build-reports/core/ --recursive | head -n 20
```

**Report Format Errors**:
- Verify generation script versions match expected format
- Check report metadata for format version
- Consult build-reports/templates/ for expected structure

---

## Package Publishing

### GitHub Package Registry

**Publishing Core Packages** (automated via GitHub Actions):

#### 1. Create Release Tag

```bash
cd clinical-diary
git tag v2025.10.24.a
git push --tags
```

#### 2. GitHub Action Publishes Packages

**Workflow**: `.github/workflows/publish.yml`

```yaml
name: Publish Packages

on:
  push:
    tags:
      - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Dart
        uses: dart-lang/setup-dart@v1

      - name: Publish to GitHub Packages
        run: |
          cd packages/core
          dart pub publish --server https://pub.pkg.github.com/yourorg
        env:
          PUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### 3. Sponsors Consume Packages

**pubspec.yaml** (in sponsor repo):

```yaml
dependencies:
  clinical_diary_core:
    hosted:
      name: clinical_diary_core
      url: https://pub.pkg.github.com/yourorg
    version: ^1.2.0
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
- [ ] `npm audit` shows no critical vulnerabilities
- [ ] Secrets not committed to repository
- [ ] All dependencies up to date
- [ ] Security scan passes (Snyk/Dependabot)

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
- [ ] EDC sync functional (proxy mode)

#### Release
- [ ] Release notes prepared
- [ ] Version number incremented
- [ ] Git tag created and pushed
- [ ] Rollback plan documented

---

## Rollback Procedures

### Portal Rollback

**Netlify**:

```bash
# List recent deploys
netlify deploy:list

# Rollback to previous deploy
netlify deploy:restore <deploy-id>
```

### Database Rollback

**Supabase**:

```bash
# Restore from backup
supabase db restore backup-20251024-120000.sql

# Or use point-in-time recovery (within 30 days)
supabase db restore --timestamp "2025-10-24 12:00:00"
```

### Edge Function Rollback

```bash
# Deploy previous version
cd edge_functions
git checkout v1.2.2
supabase functions deploy edc_sync
```

### Mobile App Rollback

**iOS**: Use App Store Connect to remove new version from release
**Android**: Use Google Play Console to halt rollout or revert to previous version

**Note**: Mobile rollback impacts ALL sponsors (single app). Coordinate carefully.

---

## Monitoring Deployment Health

**Post-Deployment Checks** (first 24 hours):

- [ ] Portal accessible (check uptime)
- [ ] Mobile app syncs successfully
- [ ] Database connections healthy
- [ ] Edge Functions invoked without errors
- [ ] Error rates within normal range
- [ ] API response times <500ms (p95)
- [ ] No security alerts
- [ ] Audit trail capturing events

**See**: ops-operations.md for ongoing monitoring procedures

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

### Database Deployment Failures

**Migration Conflicts**:
```bash
# View pending migrations
supabase migration list

# Reset database (staging only!)
supabase db reset
```

**Connection Errors**:
- Verify `SUPABASE_PROJECT_REF` is correct
- Check service role key has not expired
- Confirm network connectivity

### Portal Deployment Failures

**Netlify Build Errors**:
- Check build logs: `netlify logs`
- Verify environment variables set correctly
- Ensure `build/web/` directory contains `index.html`

**CORS Errors**:
- Configure Supabase CORS settings in dashboard
- Add portal domain to allowed origins

### Edge Function Errors

**View Logs**:
```bash
supabase functions logs edc_sync
```

**Common Issues**:
- Missing environment variables (secrets)
- EDC API connection failures
- Timeout errors (increase function timeout in dashboard)

---

## References

- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Implementation**: dev-database.md
- **Development Practices**: dev-core-practices.md
- **Compliance Practices**: dev-compliance-practices.md
- **Daily Operations**: ops-operations.md
- **Security Operations**: ops-security.md

---

**Document Status**: Active operations guide
**Review Cycle**: After each deployment or quarterly
**Owner**: DevOps Team / Release Manager
