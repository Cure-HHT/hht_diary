# Sentry Integration Setup Guide

**Purpose**: Step-by-step guide to integrate Sentry error tracking
**Audience**: Operations team, DevOps engineers
**Status**: Ready to activate (follow steps when ready)

---

## Overview

Sentry provides real-time error tracking and performance monitoring for the Clinical Diary application. This guide covers setup for all environments (development, staging, production).

**Benefits**:
- Automatic error capture and grouping
- Stack traces with source mapping
- Performance transaction tracing
- PII/PHI scrubbing for HIPAA compliance
- Real-time alerting

**Cost**: $26/month (Team plan with 50K errors/month)

---

## Prerequisites

- [ ] Sentry account (create at https://sentry.io)
- [ ] Access to Doppler for secrets management
- [ ] Flutter SDK installed (for mobile app integration)
- [ ] Node.js installed (for backend integration)

---

## Step 1: Create Sentry Organization and Projects

### 1.1 Create Organization

1. Sign up at https://sentry.io
2. Create organization: `clinical-diary`
3. Select **Team plan** ($26/month)
   - 50,000 errors/month
   - 100,000 performance units/month
   - 90-day retention
   - Team collaboration features

### 1.2 Create Projects

Create three projects (one per environment):

**Development Project**:
- Name: `clinical-diary-dev`
- Platform: Flutter
- Alert frequency: Low (digest only)
- Sample rate: 100% (capture all errors for testing)

**Staging Project**:
- Name: `clinical-diary-staging`
- Platform: Flutter
- Alert frequency: Medium (real-time for new issues)
- Sample rate: 100%

**Production Project**:
- Name: `clinical-diary-prod`
- Platform: Flutter
- Alert frequency: High (immediate alerts for all issues)
- Sample rate: 10% (reduce noise, capture representative sample)

### 1.3 Get DSN Keys

For each project, copy the DSN (Data Source Name):

1. Go to **Settings** > **Projects** > **[project-name]** > **Client Keys (DSN)**
2. Copy the DSN URL (format: `https://xxx@o123456.ingest.sentry.io/7654321`)

---

## Step 2: Store DSNs in Doppler

Store Sentry DSNs securely in Doppler:

```bash
# Development
doppler secrets set SENTRY_DSN="https://xxx@o123456.ingest.sentry.io/dev-id" \
  --project clinical-diary --config dev

# Staging
doppler secrets set SENTRY_DSN="https://xxx@o123456.ingest.sentry.io/staging-id" \
  --project clinical-diary --config stg

# Production
doppler secrets set SENTRY_DSN="https://xxx@o123456.ingest.sentry.io/prod-id" \
  --project clinical-diary --config prd
```

Verify secrets stored:

```bash
doppler secrets get SENTRY_DSN --project clinical-diary --config dev
```

---

## Step 3: Integrate Sentry SDK in Flutter App

### 3.1 Add Dependency

Add Sentry Flutter SDK to `pubspec.yaml`:

```yaml
dependencies:
  sentry_flutter: ^7.14.0
```

Install dependencies:

```bash
flutter pub get
```

### 3.2 Initialize Sentry in main.dart

Update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      // Load DSN from environment
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: '',  // Empty = disabled if not set
      );

      // Environment (dev/staging/production)
      options.environment = const String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: 'development',
      );

      // Release version for tracking
      options.release = const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: 'unknown',
      );

      // Sample rates
      options.tracesSampleRate = _getTracesSampleRate();
      options.sampleRate = _getSampleRate();

      // Enable performance monitoring
      options.enableAutoPerformanceTracing = true;

      // PII/PHI scrubbing
      options.beforeSend = _scrubbingSentryEvent;

      // Breadcrumbs (user actions leading to error)
      options.maxBreadcrumbs = 50;

      // Attach screenshots on errors (useful for UI bugs)
      options.attachScreenshot = true;
      options.screenshotQuality = SentryScreenshotQuality.medium;

      // Debug mode (only in development)
      options.debug = const bool.fromEnvironment('DEBUG', defaultValue: false);
    },
    appRunner: () => runApp(const ClinicalDiaryApp()),
  );
}

double _getTracesSampleRate() {
  const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  switch (environment) {
    case 'production':
      return 0.1;  // 10% sampling in production
    case 'staging':
      return 0.5;  // 50% sampling in staging
    default:
      return 1.0;  // 100% sampling in development
  }
}

double _getSampleRate() {
  const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  switch (environment) {
    case 'production':
      return 0.1;  // 10% of errors in production
    default:
      return 1.0;  // 100% of errors in dev/staging
  }
}

/// Scrub PII/PHI from Sentry events before sending
SentryEvent? _scrubPiiSentryEvent(SentryEvent event, {Hint? hint}) {
  // Scrub user email (but keep user ID for tracking)
  if (event.user != null) {
    event = event.copyWith(
      user: event.user!.copyWith(
        email: null,  // Remove email
        username: null,  // Remove username
        ipAddress: '0.0.0.0',  // Anonymize IP
      ),
    );
  }

  // Scrub sensitive data from breadcrumbs
  if (event.breadcrumbs != null) {
    event = event.copyWith(
      breadcrumbs: event.breadcrumbs!.map((breadcrumb) {
        // Remove data that might contain PHI
        if (breadcrumb.data != null) {
          final scrubbedData = Map<String, dynamic>.from(breadcrumb.data!);

          // Remove known sensitive fields
          scrubbedData.remove('patientId');
          scrubbedData.remove('diaryContent');
          scrubbedData.remove('symptoms');

          return breadcrumb.copyWith(data: scrubbedData);
        }
        return breadcrumb;
      }).toList(),
    );
  }

  // Scrub sensitive data from exception extra fields
  if (event.extra != null) {
    final scrubbedExtra = Map<String, dynamic>.from(event.extra!);

    scrubbedExtra.remove('password');
    scrubbedExtra.remove('token');
    scrubbedExtra.remove('apiKey');

    event = event.copyWith(extra: scrubbedExtra);
  }

  return event;
}
```

### 3.3 Run with Sentry Enabled

```bash
# Development
doppler run -- flutter run \
  --dart-define=ENVIRONMENT=development \
  --dart-define=SENTRY_DSN="$(doppler secrets get SENTRY_DSN --plain)" \
  --dart-define=APP_VERSION="$(git describe --tags --always)"

# Production build
doppler run -- flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SENTRY_DSN="$(doppler secrets get SENTRY_DSN --plain --config prd)" \
  --dart-define=APP_VERSION="$(git describe --tags --always)"
```

---

## Step 4: Capture Errors Manually

### 4.1 Capture Exceptions

```dart
try {
  // Risky operation
  await performDatabaseOperation();
} catch (exception, stackTrace) {
  // Capture in Sentry
  await Sentry.captureException(
    exception,
    stackTrace: stackTrace,
    hint: Hint.withMap({
      'operation': 'database_write',
      'user_action': 'create_diary_entry',
    }),
  );

  // Re-throw or handle
  rethrow;
}
```

### 4.2 Add Custom Breadcrumbs

```dart
// Record user actions
Sentry.addBreadcrumb(
  Breadcrumb(
    message: 'User navigated to diary entry screen',
    category: 'navigation',
    level: SentryLevel.info,
    data: {
      'screen': 'diary_entry',
      'timestamp': DateTime.now().toIso8601String(),
    },
  ),
);
```

### 4.3 Set User Context

```dart
// After successful authentication
Sentry.configureScope((scope) {
  scope.setUser(
    SentryUser(
      id: user.id,  // Keep ID for tracking
      // Do NOT include email, name, or other PII
    ),
  );
});

// On logout
Sentry.configureScope((scope) {
  scope.setUser(null);
});
```

---

## Step 5: Configure Alerts

### 5.1 Email Alerts

1. Go to **Settings** > **Projects** > **clinical-diary-prod** > **Alerts**
2. Create alert rule:
   - **Name**: Critical Errors in Production
   - **Conditions**:
     - Event level: Error or Fatal
     - Event first seen: Yes (alert on new errors)
   - **Actions**:
     - Send email to: ops-team@clinical-diary.com
   - **Frequency**: Immediately

### 5.2 Slack Integration

1. Go to **Settings** > **Integrations** > **Slack**
2. Click **Add Workspace**
3. Authorize Sentry to access Slack
4. Configure channel: `#engineering-alerts`
5. Create alert rule:
   - Send Slack notification on critical errors

### 5.3 PagerDuty Integration (Production Only)

1. Go to **Settings** > **Integrations** > **PagerDuty**
2. Enter PagerDuty API key
3. Map Sentry projects to PagerDuty services
4. Create alert rule:
   - **Name**: Production Downtime Incidents
   - **Conditions**:
     - Error rate exceeds 50 events in 5 minutes
     - OR critical errors affecting >10 users
   - **Actions**:
     - Trigger PagerDuty incident
     - Severity: High

---

## Step 6: Enable Performance Monitoring

### 6.1 Automatic Transaction Tracking

Performance transactions are automatically tracked for:
- Screen navigation
- HTTP requests
- Database queries (via Supabase integration)

No additional code required if `enableAutoPerformanceTracing: true` is set.

### 6.2 Manual Transaction Tracking

For custom operations:

```dart
import 'package:sentry/sentry.dart';

Future<void> complexOperation() async {
  final transaction = Sentry.startTransaction(
    'complex_operation',
    'task',
  );

  try {
    // Step 1
    final span1 = transaction.startChild('database_query');
    await queryDatabase();
    span1.finish(status: SpanStatus.ok());

    // Step 2
    final span2 = transaction.startChild('api_call');
    await callExternalApi();
    span2.finish(status: SpanStatus.ok());

    transaction.finish(status: SpanStatus.ok());
  } catch (e) {
    transaction.finish(status: SpanStatus.internalError());
    rethrow;
  }
}
```

---

## Step 7: Configure Retention and Archival

### 7.1 Standard Retention

Sentry Team plan includes:
- 90 days retention for all errors
- Automatic cleanup after 90 days

### 7.2 Critical Error Archival (7-Year Retention)

For FDA compliance, critical errors must be archived for 7 years:

1. Enable Sentry Data Forwarding:
   - Go to **Settings** > **Data Forwarding**
   - Enable **Amazon SQS** integration

2. Create SQS queue and S3 bucket:
   ```bash
   # Create SQS queue
   aws sqs create-queue --queue-name sentry-critical-errors

   # Create S3 bucket for archival
   aws s3 mb s3://clinical-diary-error-archive

   # Create Lambda function to process SQS → S3 Glacier
   # (See infrastructure/lambda/sentry-archival/ for code)
   ```

3. Configure data forwarding:
   - Forward events with level: `error` or `fatal`
   - Send to SQS queue
   - Lambda processes and archives to S3 Glacier

---

## Step 8: Validation

### 8.1 Test Error Capture

Trigger a test error:

```dart
// Add to your app (remove after testing)
FloatingActionButton(
  onPressed: () {
    throw Exception('Test Sentry error capture');
  },
  child: const Icon(Icons.bug_report),
)
```

Verify in Sentry dashboard:
1. Go to **Issues**
2. Find "Test Sentry error capture"
3. Verify stack trace, breadcrumbs, and context

### 8.2 Test PII Scrubbing

Trigger an error with sensitive data:

```dart
try {
  throw Exception('Error for user@example.com');
} catch (e, stack) {
  Sentry.captureException(e, stackTrace: stack);
}
```

Verify in Sentry:
- Email should NOT appear in error details
- User ID should be present (if set)
- IP address should be 0.0.0.0

### 8.3 Test Alerting

1. Trigger 5 errors quickly
2. Verify email received within 1 minute
3. Verify Slack notification in `#engineering-alerts`

---

## Step 9: Dashboard Configuration

### 9.1 Create Custom Dashboard

1. Go to **Dashboards** > **Create Dashboard**
2. Add widgets:
   - **Errors by Environment**: Bar chart grouped by environment
   - **Error Rate Trend**: Line chart (last 7 days)
   - **Top Errors**: Table of most frequent errors
   - **Performance (p95)**: Line chart of transaction durations
   - **Affected Users**: Count of users encountering errors

### 9.2 Share Dashboard

1. Click **Share**
2. Enable **Public Dashboard** (for compliance team)
3. Copy URL

---

## Troubleshooting

### Errors Not Appearing in Sentry

**Symptoms**: App crashes but no errors in Sentry dashboard

**Diagnosis**:
1. Verify DSN is correct: `print(SentryFlutter.options.dsn);`
2. Check network connectivity: Try manually sending test event
3. Verify Sentry initialized: Should happen before `runApp()`

**Resolution**:
1. Check Doppler secrets: `doppler secrets get SENTRY_DSN`
2. Test connectivity: `curl https://sentry.io/api/`
3. Move `SentryFlutter.init()` before any other code

---

### Too Many Errors (Quota Exceeded)

**Symptoms**: Sentry stops accepting events mid-month

**Diagnosis**:
1. Check quota usage: **Settings** > **Subscription** > **Usage**
2. Identify error spike: **Dashboards** > **Error Rate Trend**

**Resolution**:
1. Fix underlying issue causing error spike
2. Increase sampling rate to reduce volume (change `sampleRate` to 0.05)
3. Upgrade Sentry plan if needed

---

### PII Leaking into Errors

**Symptoms**: Sensitive data visible in Sentry dashboard

**Diagnosis**:
1. Review error details for PII/PHI
2. Check breadcrumbs and context data

**Resolution**:
1. Update `_scrubPiiSentryEvent()` function to remove additional fields
2. Test with sample data
3. Document fields to scrub in runbook

---

## Maintenance

### Monthly Tasks

- [ ] Review error trends and address recurring issues
- [ ] Verify PII scrubbing is working correctly
- [ ] Check quota usage and adjust sampling if needed
- [ ] Archive critical errors to S3 Glacier (automatic)

### Quarterly Tasks

- [ ] Review alert rules and adjust thresholds
- [ ] Audit dashboard access (remove inactive users)
- [ ] Update PII scrubbing logic if data model changes
- [ ] Verify 7-year archival is working correctly

---

## References

- [Sentry Flutter Documentation](https://docs.sentry.io/platforms/flutter/)
- [Sentry Performance Monitoring](https://docs.sentry.io/product/performance/)
- [Sentry Data Scrubbing](https://docs.sentry.io/platforms/flutter/data-management/sensitive-data/)
- spec/ops-monitoring-observability.md - Monitoring specification

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-27 | 1.0 | Claude | Initial setup guide (ready to activate) |
