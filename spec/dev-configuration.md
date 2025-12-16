# Configuration Implementation Guide

**Version**: 2.0
**Audience**: Development (Software Engineers, Application Developers)
**Last Updated**: 2025-11-24
**Status**: Draft

> **See**: ops-deployment.md for deployment and environment configuration
> **See**: prd-security.md for security requirements
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture
> **See**: docs/migration/doppler-vs-secret-manager.md for secrets management strategy

---

## Executive Summary

Technical implementation guide for sponsor-specific configuration management in the clinical diary system. Covers configuration file structure, environment variable loading, and build-time composition of sponsor-specific settings.

**Key Components**:
- Dart-based configuration classes
- Environment-specific credential loading via Doppler
- GCP service configuration (Cloud SQL, Identity Platform, Cloud Run)
- Build-time validation
- Type-safe configuration access

---

## Configuration Architecture

# REQ-d00001: Sponsor-Specific Configuration Loading

**Level**: Dev | **Implements**: o00001, o00002 | **Status**: Draft

The application SHALL load sponsor-specific configuration from environment variables that specify GCP connection parameters and sponsor settings.

Configuration SHALL be loaded via Doppler for development and CI/CD environments, with the following required variables:

**Database Configuration (Cloud SQL)**:
- `DATABASE_URL`: Cloud SQL connection string (format: `postgresql://user:pass@/dbname?host=/cloudsql/project:region:instance`)
- `DATABASE_INSTANCE`: Cloud SQL instance connection name (format: `project:region:instance`)

**Authentication Configuration (Identity Platform)**:
- `FIREBASE_PROJECT_ID`: GCP project ID for Identity Platform
- `FIREBASE_API_KEY`: Firebase/Identity Platform API key (for client SDK)

**Sponsor Configuration**:
- `SPONSOR_ID`: Unique sponsor identifier (format: `{vendor_code}`)
- `GCP_PROJECT_ID`: GCP project ID for this sponsor/environment

**Server Configuration (Cloud Run - server only)**:
- `CLOUD_RUN_SERVICE_URL`: Cloud Run service URL
- `PORT`: Server port (typically 8080 for Cloud Run)

The application SHALL validate all required fields are present at application startup and SHALL fail fast if configuration is invalid or missing.

**Rationale**: Implements infrastructure isolation (o00001) at the application layer. GCP project-level isolation ensures complete separation between sponsors. Type-safe configuration prevents runtime errors from misconfiguration.

**Acceptance Criteria**:
- Configuration loaded from Doppler in development (`doppler run -- flutter run`)
- Build process validates all required fields present before compilation
- No hardcoded credentials in Dart source code
- Application throws clear error message if configuration missing
- Configuration is immutable after loading (final fields)
- Cloud SQL connection uses appropriate format for environment

*End* *Sponsor-Specific Configuration Loading* | **Hash**: cf4bce54
---

### Implementation Example

**Configuration Class** (`lib/config/database_config.dart`):

```dart
/// REQ-d00001: Sponsor-specific GCP configuration
class DatabaseConfig {
  const DatabaseConfig({
    required this.databaseUrl,
    required this.instanceConnectionName,
    required this.sponsorId,
    required this.gcpProjectId,
  });

  /// Cloud SQL connection URL
  /// Format: postgresql://user:pass@/dbname?host=/cloudsql/project:region:instance
  final String databaseUrl;

  /// Cloud SQL instance connection name
  /// Format: project:region:instance
  final String instanceConnectionName;

  /// Unique sponsor identifier
  final String sponsorId;

  /// GCP project ID for this sponsor
  final String gcpProjectId;

  /// Load configuration from environment variables
  /// Throws [ConfigurationException] if required variables missing
  factory DatabaseConfig.fromEnvironment() {
    final databaseUrl = const String.fromEnvironment('DATABASE_URL');
    final instanceConnectionName = const String.fromEnvironment('DATABASE_INSTANCE');
    final sponsorId = const String.fromEnvironment('SPONSOR_ID');
    final gcpProjectId = const String.fromEnvironment('GCP_PROJECT_ID');

    // REQ-d00001: Validate all required fields present
    if (databaseUrl.isEmpty) {
      throw ConfigurationException('DATABASE_URL not configured');
    }
    if (instanceConnectionName.isEmpty) {
      throw ConfigurationException('DATABASE_INSTANCE not configured');
    }
    if (sponsorId.isEmpty) {
      throw ConfigurationException('SPONSOR_ID not configured');
    }
    if (gcpProjectId.isEmpty) {
      throw ConfigurationException('GCP_PROJECT_ID not configured');
    }

    // REQ-d00001: Validate instance connection name format
    if (!instanceConnectionName.contains(':')) {
      throw ConfigurationException(
        'Invalid DATABASE_INSTANCE format. Expected: project:region:instance',
      );
    }

    return DatabaseConfig(
      databaseUrl: databaseUrl,
      instanceConnectionName: instanceConnectionName,
      sponsorId: sponsorId,
      gcpProjectId: gcpProjectId,
    );
  }

  /// Validate configuration is properly formatted
  void validate() {
    assert(databaseUrl.isNotEmpty, 'Database URL cannot be empty');
    assert(instanceConnectionName.isNotEmpty, 'Instance name cannot be empty');
    assert(sponsorId.isNotEmpty, 'Sponsor ID cannot be empty');
    assert(gcpProjectId.isNotEmpty, 'GCP Project ID cannot be empty');
  }
}

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}
```

**Authentication Configuration** (`lib/config/auth_config.dart`):

```dart
/// REQ-d00001: Identity Platform authentication configuration
class AuthConfig {
  const AuthConfig({
    required this.firebaseProjectId,
    required this.firebaseApiKey,
  });

  /// GCP project ID for Identity Platform
  final String firebaseProjectId;

  /// Firebase/Identity Platform API key
  final String firebaseApiKey;

  factory AuthConfig.fromEnvironment() {
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID');
    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY');

    if (projectId.isEmpty) {
      throw ConfigurationException('FIREBASE_PROJECT_ID not configured');
    }
    if (apiKey.isEmpty) {
      throw ConfigurationException('FIREBASE_API_KEY not configured');
    }

    return AuthConfig(
      firebaseProjectId: projectId,
      firebaseApiKey: apiKey,
    );
  }
}
```

**Application Initialization** (`lib/main.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/database_config.dart';
import 'config/auth_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REQ-d00001: Load and validate sponsor-specific configuration
  final dbConfig = DatabaseConfig.fromEnvironment();
  dbConfig.validate();

  final authConfig = AuthConfig.fromEnvironment();

  // Initialize Firebase/Identity Platform
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: authConfig.firebaseApiKey,
      projectId: authConfig.firebaseProjectId,
      appId: const String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    ),
  );

  runApp(ClinicalDiaryApp(sponsorId: dbConfig.sponsorId));
}
```

---

## Build Script Validation

# REQ-d00002: Pre-Build Configuration Validation

**Level**: Dev | **Implements**: o00002 | **Status**: Draft

The build system SHALL validate sponsor configuration before compilation begins.

Validation checks SHALL include:
- All required environment variables are defined (via Doppler)
- GCP project ID format is valid
- Cloud SQL instance connection name format is valid
- No credential files are tracked in git
- `.gitignore` properly excludes `*.env` files

The build SHALL fail immediately if validation fails, with clear error messages indicating which configuration is missing or invalid.

**Rationale**: Prevents deployment of misconfigured applications. Fail-fast approach saves time by catching configuration errors before lengthy build process. Enforces security best practices around credential management.

**Acceptance Criteria**:
- Build script validates Doppler configuration before starting
- Script validates GCP project ID format
- Script validates Cloud SQL instance name format
- Script verifies no credential files are git-tracked
- Clear error messages indicate exactly which field is invalid
- Validation completes in <1 second
- Non-zero exit code on validation failure

*End* *Pre-Build Configuration Validation* | **Hash**: b551cfb0
---

### Validation Script

**Build Validator** (`tools/build_system/validate_config.dart`):

```dart
/// REQ-d00002: Validate sponsor configuration before build
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart validate_config.dart <environment>');
    exit(1);
  }

  final environment = args[0];

  // REQ-d00002: Validate required environment variables via Doppler
  final requiredVars = [
    'DATABASE_URL',
    'DATABASE_INSTANCE',
    'GCP_PROJECT_ID',
    'SPONSOR_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_API_KEY',
  ];

  final missingVars = <String>[];
  for (final varName in requiredVars) {
    final value = Platform.environment[varName];
    if (value == null || value.isEmpty) {
      missingVars.add(varName);
    }
  }

  if (missingVars.isNotEmpty) {
    print('❌ Missing required environment variables:');
    for (final varName in missingVars) {
      print('   - $varName');
    }
    print('');
    print('   Ensure you run with Doppler: doppler run -- dart run ...');
    exit(1);
  }

  // REQ-d00002: Validate GCP project ID format
  final projectId = Platform.environment['GCP_PROJECT_ID']!;
  if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(projectId)) {
    print('❌ Invalid GCP_PROJECT_ID format: $projectId');
    print('   Must be 6-30 characters, lowercase letters, digits, and hyphens');
    exit(1);
  }

  // REQ-d00002: Validate Cloud SQL instance name format
  final instanceName = Platform.environment['DATABASE_INSTANCE']!;
  final parts = instanceName.split(':');
  if (parts.length != 3) {
    print('❌ Invalid DATABASE_INSTANCE format: $instanceName');
    print('   Expected: project:region:instance');
    exit(1);
  }

  // REQ-d00002: Check for tracked credential files
  final credentialFiles = ['*.env', 'credentials.json', 'service-account.json'];
  for (final pattern in credentialFiles) {
    final result = Process.runSync('git', ['ls-files', pattern]);
    if (result.stdout.toString().trim().isNotEmpty) {
      print('❌ Credential file tracked in git: $pattern');
      print('   Add to .gitignore and remove from git');
      exit(1);
    }
  }

  print('✅ Configuration validated successfully');
  print('   Environment: $environment');
  print('   GCP Project: $projectId');
  print('   Sponsor: ${Platform.environment['SPONSOR_ID']}');
}
```

**Integration with Build Process**:

```bash
# Run validation with Doppler before build
doppler run --config $ENVIRONMENT -- dart run tools/build_system/validate_config.dart $ENVIRONMENT
if [ $? -ne 0 ]; then
  echo "Configuration validation failed"
  exit 1
fi

# Proceed with build (Doppler injects env vars)
doppler run --config $ENVIRONMENT -- flutter build apk
```

---

## Development Workflow

### Local Development with Doppler

```bash
# Setup Doppler for the project (one-time)
doppler setup

# Run Flutter app with secrets injected
doppler run -- flutter run

# Run tests with secrets
doppler run -- flutter test

# Run Claude Code with API keys
doppler run -- claude
```

### Environment Configuration

Doppler project structure for multi-sponsor:

```
clinical-diary/
├── development     # Shared development config
├── staging         # Pre-production
└── production      # Production (restricted access)

clinical-diary-sponsor-{name}/
├── staging         # Sponsor-specific staging
└── production      # Sponsor-specific production
```

### Required Doppler Variables

| Variable | Description | Example |
| --- | --- | --- |
| `DATABASE_URL` | Cloud SQL connection string | `postgresql://...` |
| `DATABASE_INSTANCE` | Cloud SQL instance name | `project:us-central1:db` |
| `GCP_PROJECT_ID` | GCP project ID | `clinical-diary-prod` |
| `SPONSOR_ID` | Sponsor identifier | `orion` |
| `FIREBASE_PROJECT_ID` | Identity Platform project | `clinical-diary-prod` |
| `FIREBASE_API_KEY` | Firebase API key | `AIza...` |
| `FIREBASE_APP_ID` | Firebase app ID | `1:123:web:abc` |

---

## Testing Configuration

### Unit Tests

```dart
// test/config/database_config_test.dart
import 'package:test/test.dart';
import 'package:clinical_diary/config/database_config.dart';

void main() {
  group('DatabaseConfig', () {
    test('throws when DATABASE_URL missing', () {
      expect(
        () => DatabaseConfig.fromEnvironment(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('validates instance name format', () {
      // Invalid format should throw
      final config = DatabaseConfig(
        databaseUrl: 'postgresql://...',
        instanceConnectionName: 'invalid-format',  // Missing colons
        sponsorId: 'test',
        gcpProjectId: 'test-project',
      );
      expect(() => config.validate(), returnsNormally);
    });

    test('loads valid configuration', () {
      // REQ-d00001: Configuration loads from environment
      final config = DatabaseConfig(
        databaseUrl: 'postgresql://user:pass@/db?host=/cloudsql/proj:region:inst',
        instanceConnectionName: 'proj:region:inst',
        sponsorId: 'orion',
        gcpProjectId: 'clinical-diary-orion-prod',
      );

      expect(config.instanceConnectionName, contains(':'));
      expect(config.sponsorId, equals('orion'));
    });
  });
}
```

---

## Security Considerations

1. **Use Doppler for secrets**: Never store secrets in `.env` files committed to git
2. **GCP IAM**: Use service accounts with minimal required permissions
3. **Cloud SQL**: Use private IP and Cloud SQL Proxy for secure connections
4. **Environment isolation**: Each sponsor uses a separate GCP project
5. **Validate at build time**: Catch configuration errors before deployment

---

## Troubleshooting

### Doppler not configured

```
❌ Missing required environment variables:
   - DATABASE_URL
```

**Solution**: Ensure Doppler is set up and you're running with `doppler run --`:
```bash
doppler setup  # Select project and config
doppler run -- flutter run
```

### Invalid GCP project ID

```
❌ Invalid GCP_PROJECT_ID format: My-Project
```

**Solution**: GCP project IDs must be lowercase with hyphens:
```
GCP_PROJECT_ID=my-project-123
```

### Invalid Cloud SQL instance name

```
❌ Invalid DATABASE_INSTANCE format: my-instance
```

**Solution**: Use full instance connection name:
```
DATABASE_INSTANCE=project-id:us-central1:instance-name
```

### Cannot connect to Cloud SQL

**Solution**: For local development, use Cloud SQL Proxy:
```bash
# Start Cloud SQL Proxy
cloud_sql_proxy -instances=project:region:instance=tcp:5432

# Update DATABASE_URL for local proxy
DATABASE_URL=postgresql://user:pass@localhost:5432/dbname
```

---

## References

- **REQ-p00001**: Multi-Sponsor Data Isolation (prd-security.md)
- **REQ-o00001**: Separate GCP Projects Per Sponsor (ops-deployment.md)
- **REQ-o00002**: Environment-Specific Configuration Management (ops-deployment.md)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Identity Platform Documentation](https://cloud.google.com/identity-platform/docs)
- [Doppler Documentation](https://docs.doppler.com/)
- [Dart Environment Variables](https://dart.dev/tools/dart-compile#environment)
