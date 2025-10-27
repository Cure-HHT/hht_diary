# CI/CD Pipeline Specification

**Document Version**: 1.0
**Date**: 2025-10-27
**Audience**: DevOps Engineers, Developers
**Status**: Specification (Not Yet Deployed)

**IMPLEMENTS REQUIREMENTS**:
- REQ-d00006: Mobile App Build and Release Process
- REQ-o00010: Mobile App Store Deployment

---

## Executive Summary

This document specifies the CI/CD pipeline for the Clinical Trial Diary system, covering automated builds, testing, deployment, and release processes for the Flutter mobile application and supporting infrastructure.

**Pipeline Objectives**:
- Automated build process for iOS and Android
- Continuous testing (unit, integration, compliance)
- Automated compliance validation (requirement traceability)
- Secure release to App Store and Google Play
- Deployment of database schemas to Supabase instances
- Multi-sponsor configuration management

**Status**: ⚠️ **Specification Only** - Pipeline not yet deployed (requires GitHub Actions configuration)

---

## 1. Pipeline Architecture

### 1.1 Pipeline Stages

```
┌─────────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐    ┌────────────┐
│   Trigger   │───>│  Build   │───>│    Test    │───>│ Validate │───>│   Deploy   │
│ (Push/PR)   │    │ (Compile)│    │ (Automated)│    │ (Comply) │    │ (Release)  │
└─────────────┘    └──────────┘    └────────────┘    └──────────┘    └────────────┘
       │                 │                 │                │                 │
       v                 v                 v                v                 v
   Git Event      Flutter Build       Unit Tests     Req Validation     App Stores
   (main/PR)      iOS & Android      Integration     Lint & Format      Supabase
                                      E2E Tests        Security
```

---

## 2. GitHub Actions Workflows

### 2.1 Pull Request Validation Workflow

**File**: `.github/workflows/pr-validation.yml`

**Triggers**: Pull request to `main` branch

**Steps**:
1. Checkout code
2. Validate requirement traceability
3. Lint code (Dart, SQL, Markdown)
4. Run unit tests
5. Check for secrets in commits
6. Verify commit message format
7. Post results to PR

**Template**:
```yaml
name: PR Validation

on:
  pull_request:
    branches: [ main ]

jobs:
  validate-requirements:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install dependencies
        run: |
          cd tools/requirements
          pip install -r requirements.txt || echo "No requirements.txt"

      - name: Validate requirement traceability
        run: python3 tools/requirements/validate_requirements.py

      - name: Generate traceability matrix
        run: python3 tools/requirements/generate_traceability.py --format markdown

  lint-code:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Run Flutter linter
        run: |
          cd mobile-app
          flutter analyze

      - name: Check formatting
        run: |
          cd mobile-app
          flutter format --set-exit-if-changed .

  check-secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  verify-commit-messages:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Check commit message format
        run: |
          # Verify format: [TICKET-XXX] Message
          git log --format=%s origin/main..HEAD | \
            grep -E '^\[(CUR|TICKET)-[0-9]+\]' || \
            (echo "Commit messages must start with [TICKET-XXX]" && exit 1)
```

---

### 2.2 Build and Test Workflow

**File**: `.github/workflows/build-test.yml`

**Triggers**: Push to `main` or release branches

**Steps**:
1. Build Flutter app (iOS & Android)
2. Run unit tests
3. Run integration tests
4. Upload build artifacts
5. Cache dependencies

**Template**:
```yaml
name: Build and Test

on:
  push:
    branches: [ main, release/** ]
  pull_request:
    branches: [ main ]

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: |
          cd mobile-app
          flutter pub get

      - name: Run tests
        run: |
          cd mobile-app
          flutter test --coverage

      - name: Build APK (debug)
        run: |
          cd mobile-app
          flutter build apk --debug

      - name: Upload APK artifact
        uses: actions/upload-artifact@v3
        with:
          name: app-debug.apk
          path: mobile-app/build/app/outputs/flutter-apk/app-debug.apk

      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          files: mobile-app/coverage/lcov.info

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: |
          cd mobile-app
          flutter pub get

      - name: Run tests
        run: |
          cd mobile-app
          flutter test

      - name: Build iOS app (unsigned)
        run: |
          cd mobile-app
          flutter build ios --no-codesign --debug

      - name: Upload IPA artifact
        uses: actions/upload-artifact@v3
        with:
          name: Runner.app
          path: mobile-app/build/ios/iphoneos/Runner.app
```

---

### 2.3 Database Migration Workflow

**File**: `.github/workflows/database-migration.yml`

**Triggers**: Manual dispatch or push to `database/` directory

**Steps**:
1. Validate SQL syntax
2. Test migrations on local database
3. Generate migration report
4. (Manual approval required for production)

**Template**:
```yaml
name: Database Migration Validation

on:
  push:
    paths:
      - 'database/**/*.sql'
  workflow_dispatch:

jobs:
  validate-migrations:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3

      - name: Install PostgreSQL client
        run: sudo apt-get install -y postgresql-client

      - name: Test schema deployment
        env:
          PGHOST: localhost
          PGPORT: 5432
          PGUSER: postgres
          PGPASSWORD: postgres
          PGDATABASE: test_db
        run: |
          psql -f database/schema.sql
          psql -f database/triggers.sql
          psql -f database/rls_policies.sql
          psql -f database/indexes.sql

      - name: Run database tests
        env:
          PGHOST: localhost
          PGPORT: 5432
          PGUSER: postgres
          PGPASSWORD: postgres
          PGDATABASE: test_db
        run: |
          psql -f database/tests/test_audit_trail.sql
          psql -f database/tests/test_compliance_functions.sql

      - name: Validate migration scripts
        run: |
          # Check that all migrations have corresponding rollbacks
          for migration in database/migrations/*.sql; do
            filename=$(basename "$migration")
            rollback="database/migrations/rollback/${filename//.sql/_rollback.sql}"
            if [ ! -f "$rollback" ]; then
              echo "Missing rollback for $migration"
              exit 1
            fi
          done
```

---

### 2.4 Release Workflow

**File**: `.github/workflows/release.yml`

**Triggers**: Git tag creation (`v*.*.*`)

**Steps**:
1. Build production artifacts (iOS & Android)
2. Sign with production certificates
3. Upload to App Store Connect (iOS)
4. Upload to Google Play Console (Android)
5. Create GitHub release
6. Update release notes

**Template**:
```yaml
name: Release to App Stores

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build-and-release-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: |
          echo $KEYSTORE_BASE64 | base64 -d > android/app/keystore.jks

      - name: Create key.properties
        env:
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          cat > android/key.properties <<EOF
          storePassword=$KEYSTORE_PASSWORD
          keyPassword=$KEY_PASSWORD
          keyAlias=$KEY_ALIAS
          storeFile=keystore.jks
          EOF

      - name: Install dependencies
        run: |
          cd mobile-app
          flutter pub get

      - name: Build App Bundle
        run: |
          cd mobile-app
          flutter build appbundle --release

      - name: Upload to Google Play
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: org.anspar.clinicaltrialdiary
          releaseFiles: mobile-app/build/app/outputs/bundle/release/app-release.aab
          track: internal
          status: draft

  build-and-release-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          channel: 'stable'

      - name: Install dependencies
        run: |
          cd mobile-app
          flutter pub get

      - name: Install CocoaPods
        run: |
          cd mobile-app/ios
          pod install

      - name: Import signing certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.IOS_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
        run: |
          # Create temporary keychain
          security create-keychain -p "" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "" build.keychain

          # Import certificate
          echo $CERTIFICATE_BASE64 | base64 -d > certificate.p12
          security import certificate.p12 -k build.keychain -P $CERTIFICATE_PASSWORD -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain

          # Clean up
          rm certificate.p12

      - name: Import provisioning profile
        env:
          PROVISIONING_PROFILE_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
        run: |
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo $PROVISIONING_PROFILE_BASE64 | base64 -d > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Build iOS app
        run: |
          cd mobile-app
          flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

      - name: Upload to App Store Connect
        env:
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
        run: |
          xcrun altool --upload-app \
            --type ios \
            --file mobile-app/build/ios/ipa/*.ipa \
            --apiKey $APP_STORE_CONNECT_API_KEY \
            --apiIssuer ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}

  create-github-release:
    needs: [build-and-release-android, build-and-release-ios]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Create GitHub Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          draft: false
          prerelease: false
```

---

## 3. Environment Configuration

### 3.1 GitHub Secrets

**Required Secrets**:

**Android**:
- `ANDROID_KEYSTORE_BASE64` - Base64-encoded Android keystore file
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password
- `GOOGLE_PLAY_SERVICE_ACCOUNT` - Google Play service account JSON

**iOS**:
- `IOS_CERTIFICATE_BASE64` - Base64-encoded .p12 certificate
- `IOS_CERTIFICATE_PASSWORD` - Certificate password
- `IOS_PROVISIONING_PROFILE_BASE64` - Base64-encoded provisioning profile
- `APP_STORE_CONNECT_API_KEY` - App Store Connect API key
- `APP_STORE_CONNECT_ISSUER_ID` - App Store Connect issuer ID

**General**:
- `LINEAR_API_TOKEN` - Linear API token (for ticket updates)
- `SLACK_WEBHOOK_URL` - Slack notifications (optional)

---

### 3.2 Environment Variables

**Build Environments**:
- `development` - Local development, CI testing
- `staging` - Pre-production testing
- `production` - App Store releases

**Configuration per Environment**:
```dart
// lib/config/environment.dart
class Environment {
  static const String current = String.fromEnvironment('ENV', defaultValue: 'development');

  static bool get isDevelopment => current == 'development';
  static bool get isStaging => current == 'staging';
  static bool get isProduction => current == 'production';

  // Environment-specific configs
  static String get apiBaseUrl => {
    'development': 'http://localhost:54321',
    'staging': 'https://staging.supabase.co',
    'production': 'https://YOUR_PROJECT.supabase.co',
  }[current]!;
}
```

---

## 4. Deployment Checklist

### 4.1 Pre-Deployment Setup

- [ ] GitHub repository configured
- [ ] GitHub Actions enabled
- [ ] All secrets configured in GitHub
- [ ] Android keystore generated and stored securely
- [ ] iOS certificates and provisioning profiles created
- [ ] Google Play Developer account created (D-U-N-S number required)
- [ ] Apple Developer account created
- [ ] App Store Connect app created
- [ ] Google Play Console app created

---

### 4.2 First Deployment

**Step 1: Configure Repository**
```bash
# Create .github/workflows directory
mkdir -p .github/workflows

# Copy workflow templates from this document
# (pr-validation.yml, build-test.yml, etc.)

# Commit and push
git add .github/workflows
git commit -m "[CUR-186] Add CI/CD workflows"
git push
```

**Step 2: Configure Secrets**
```bash
# Navigate to GitHub repo settings > Secrets and variables > Actions
# Add each required secret listed in Section 3.1
```

**Step 3: Test Workflows**
```bash
# Create test PR to trigger PR validation
git checkout -b test/cicd-validation
# Make a small change
git commit -m "[TEST] Test CI/CD pipeline"
git push
gh pr create --title "Test CI/CD pipeline" --body "Testing workflows"

# Check GitHub Actions tab for results
```

**Step 4: First Release**
```bash
# After all tests pass, create first release
git checkout main
git tag -a v0.1.0 -m "Initial release"
git push origin v0.1.0

# Monitor release workflow in GitHub Actions
# Manual review required in app stores before publishing
```

---

## 5. Monitoring and Alerts

### 5.1 Build Monitoring

**Metrics to Track**:
- Build success rate (target: >95%)
- Build duration (target: <15 minutes)
- Test pass rate (target: 100%)
- Code coverage (target: >80%)
- Deployment success rate (target: >90%)

**Tools**:
- GitHub Actions built-in metrics
- Codecov for coverage tracking
- Slack notifications for failures

---

### 5.2 Alert Configuration

**Slack Integration** (optional):
```yaml
# Add to workflow files
- name: Notify Slack on failure
  if: failure()
  uses: rtCamp/action-slack-notify@v2
  env:
    SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
    SLACK_TITLE: 'Build Failed'
    SLACK_MESSAGE: 'Build ${{ github.run_number }} failed on ${{ github.ref }}'
    SLACK_COLOR: 'danger'
```

---

## 6. Compliance Integration

### 6.1 Requirement Traceability in CI/CD

**Pre-Commit Validation**: Already configured via git hooks

**CI Validation**: Enforced in `pr-validation.yml` workflow
- Runs requirement validation on every PR
- Generates traceability matrix
- Fails PR if validation errors found

**Audit Trail**:
- All builds logged in GitHub Actions
- Requirement validation results archived
- Traceability matrix committed to repository

---

### 6.2 FDA 21 CFR Part 11 Compliance

**Software Validation**:
- CI/CD pipeline serves as automated validation
- Each build includes test execution
- Build artifacts versioned and traceable
- Deployment requires manual approval for production

**Audit Trail**:
- GitHub Actions logs provide complete audit trail
- Build artifacts stored with SHA-256 checksums
- Release notes link to requirements and tickets

---

## 7. Rollback Procedures

### 7.1 App Store Rollback

**iOS**:
1. Login to App Store Connect
2. Navigate to app > App Store tab
3. Select previous version
4. Submit for review (if needed) or make available immediately

**Android**:
1. Login to Google Play Console
2. Navigate to Production track
3. Select previous release
4. Rollback to previous version

**Automated Rollback** (future enhancement):
```yaml
# Workflow to rollback to previous version
name: Rollback Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to (e.g., v1.0.0)'
        required: true

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Rollback on Google Play
        # Use fastlane or Google Play API to promote previous version

      - name: Rollback on App Store
        # Use App Store Connect API to promote previous version
```

---

### 7.2 Database Migration Rollback

**Automatic Rollback**:
Each migration includes a rollback script in `database/migrations/rollback/`.

**Procedure**:
```bash
# Identify migration to rollback
ls database/migrations/rollback/

# Run rollback script
psql -h YOUR_SUPABASE_HOST -U postgres -d postgres -f database/migrations/rollback/XXX_rollback.sql

# Verify rollback
psql -h YOUR_SUPABASE_HOST -U postgres -d postgres -c "\d record_audit"
```

---

## 8. Cost Optimization

### 8.1 GitHub Actions Costs

**Free Tier**: 2,000 minutes/month (Linux runners)

**Optimization Strategies**:
- Cache dependencies (Flutter, npm, CocoaPods)
- Run tests in parallel
- Only build on specific paths (e.g., `mobile-app/**`)
- Use self-hosted runners for private repos (if needed)

**Estimated Usage**:
- PR validation: ~5 minutes per PR
- Build and test: ~10 minutes per push
- Release: ~20 minutes per release
- Monthly estimate: ~50 PRs × 5 min + ~100 pushes × 10 min = ~1,250 minutes

**Under free tier**: ✅

---

## 9. Future Enhancements

### 9.1 Planned Improvements

**Phase 2** (After initial deployment):
- [ ] E2E testing with Appium/Detox
- [ ] Automated screenshot generation for app stores
- [ ] Automated release notes generation
- [ ] Blue-green deployments for backend services
- [ ] Canary releases (staged rollout)
- [ ] Automated security scanning (OWASP, Snyk)

**Phase 3** (Production optimization):
- [ ] Performance regression testing
- [ ] Load testing (backend APIs)
- [ ] Automated accessibility testing
- [ ] Multi-region deployment
- [ ] Disaster recovery automation

---

## 10. Blocker Dependencies

**Before CI/CD can be deployed**:
- [ ] GitHub repository created and configured
- [ ] Google Play Developer account created (requires D-U-N-S number - CUR-84)
- [ ] Apple Developer account created (requires D-U-N-S number - CUR-84)
- [ ] Flutter mobile app codebase created
- [ ] Android keystore generated
- [ ] iOS certificates and provisioning profiles created
- [ ] Supabase projects created per sponsor

**Status**: ⚠️ **BLOCKED by CUR-84** (D-U-N-S number required for app store accounts)

---

## 11. References

**GitHub Actions Documentation**:
- https://docs.github.com/en/actions

**Flutter CI/CD**:
- https://docs.flutter.dev/deployment/cd

**App Store Deployment**:
- iOS: https://developer.apple.com/app-store-connect/
- Android: https://play.google.com/console/

**Security Best Practices**:
- https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions

**Project Requirements**:
- `spec/dev-app.md:REQ-d00006` - Mobile App Build and Release Process
- `spec/ops-deployment.md:REQ-o00010` - Mobile App Store Deployment

---

**Document Control**:
- **Version**: 1.0
- **Effective Date**: 2025-10-27 (Specification)
- **Deployment Date**: TBD (After blocker resolution)
- **Next Review**: Upon deployment
- **Owner**: DevOps Lead

---

**Change Log**:
- 2025-10-27 v1.0: Initial specification (CUR-186)
