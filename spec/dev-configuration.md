# Configuration Implementation Guide

**Version**: 1.0
**Audience**: Development (Software Engineers, Application Developers)
**Last Updated**: 2025-01-25
**Status**: Draft

> **See**: ops-deployment.md for deployment and environment configuration
> **See**: prd-security.md for security requirements
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture

---

## Executive Summary

Technical implementation guide for sponsor-specific configuration management in the clinical diary system. Covers configuration file structure, environment variable loading, and build-time composition of sponsor-specific settings.

**Key Components**:
- Dart-based configuration classes
- Environment-specific credential loading
- Build-time validation
- Type-safe configuration access

---

## Configuration Architecture

### REQ-d00001: Sponsor-Specific Configuration Loading

**Level**: Dev | **Implements**: o00001, o00002 | **Status**: Active

The application SHALL load sponsor-specific configuration from environment files that specify Supabase connection parameters and sponsor settings.

Configuration files SHALL follow the naming pattern:
- `config/supabase.{environment}.env` where environment is `staging` or `prod`

Each configuration file MUST contain:
- `SUPABASE_URL`: Unique project URL (format: `https://{project-ref}.supabase.co`)
- `SUPABASE_ANON_KEY`: Project-specific anonymous key (JWT format)
- `SUPABASE_PROJECT_REF`: Project reference ID
- `SPONSOR_ID`: Unique sponsor identifier (format: `{vendor_code}`)

The application SHALL validate all required fields are present at application startup and SHALL fail fast if configuration is invalid or missing.

**Rationale**: Implements infrastructure isolation (o00001) at the application layer. Enables build-time composition while maintaining runtime isolation. Type-safe configuration prevents runtime errors from misconfiguration.

**Acceptance Criteria**:
- Configuration files exist for each sponsor in version control (template files)
- Build process validates all required fields present before compilation
- No hardcoded credentials in Dart source code
- URL patterns match expected Supabase format (`https://*.supabase.co`)
- Application throws clear error message if configuration missing
- Configuration is immutable after loading (final fields)

---

### Implementation Example

**Configuration Class** (`lib/config/supabase_config.dart`):

```dart
/// REQ-d00001: Sponsor-specific Supabase configuration
class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    required this.projectRef,
    required this.sponsorId,
  });

  /// Supabase project URL (e.g., https://abc123.supabase.co)
  final String url;

  /// Anonymous/public API key for client-side operations
  final String anonKey;

  /// Project reference identifier
  final String projectRef;

  /// Unique sponsor identifier
  final String sponsorId;

  /// Load configuration from environment variables
  /// Throws [ConfigurationException] if required variables missing
  factory SupabaseConfig.fromEnvironment() {
    final url = const String.fromEnvironment('SUPABASE_URL');
    final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
    final projectRef = const String.fromEnvironment('SUPABASE_PROJECT_REF');
    final sponsorId = const String.fromEnvironment('SPONSOR_ID');

    // REQ-d00001: Validate all required fields present
    if (url.isEmpty) {
      throw ConfigurationException('SUPABASE_URL not configured');
    }
    if (anonKey.isEmpty) {
      throw ConfigurationException('SUPABASE_ANON_KEY not configured');
    }
    if (projectRef.isEmpty) {
      throw ConfigurationException('SUPABASE_PROJECT_REF not configured');
    }
    if (sponsorId.isEmpty) {
      throw ConfigurationException('SPONSOR_ID not configured');
    }

    // REQ-d00001: Validate URL format
    if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
      throw ConfigurationException(
        'Invalid SUPABASE_URL format. Expected: https://*.supabase.co',
      );
    }

    return SupabaseConfig(
      url: url,
      anonKey: anonKey,
      projectRef: projectRef,
      sponsorId: sponsorId,
    );
  }

  /// Validate configuration is properly formatted
  void validate() {
    assert(url.isNotEmpty, 'URL cannot be empty');
    assert(anonKey.isNotEmpty, 'Anon key cannot be empty');
    assert(projectRef.isNotEmpty, 'Project ref cannot be empty');
    assert(sponsorId.isNotEmpty, 'Sponsor ID cannot be empty');
  }
}

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}
```

**Application Initialization** (`lib/main.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REQ-d00001: Load and validate sponsor-specific configuration
  final config = SupabaseConfig.fromEnvironment();
  config.validate();

  // Initialize Supabase with sponsor-specific credentials
  await Supabase.initialize(
    url: config.url,
    anonKey: config.anonKey,
  );

  runApp(ClinicalDiaryApp(sponsorId: config.sponsorId));
}
```

**Build-Time Configuration** (`build.yaml`):

```yaml
# Build configuration for sponsor-specific compilation
targets:
  $default:
    builders:
      # Load environment-specific configuration during build
      environment_config:
        enabled: true
        options:
          env_file: "config/supabase.${ENVIRONMENT}.env"
          required_vars:
            - SUPABASE_URL
            - SUPABASE_ANON_KEY
            - SUPABASE_PROJECT_REF
            - SPONSOR_ID
```

---

## Build Script Validation

### REQ-d00002: Pre-Build Configuration Validation

**Level**: Dev | **Implements**: o00002 | **Status**: Active

The build system SHALL validate sponsor configuration before compilation begins.

Validation checks SHALL include:
- All required environment variables are defined
- Environment file exists for target environment
- Supabase URL format is valid
- No credential files are tracked in git
- `.gitignore` properly excludes `*.env` files

The build SHALL fail immediately if validation fails, with clear error messages indicating which configuration is missing or invalid.

**Rationale**: Prevents deployment of misconfigured applications. Fail-fast approach saves time by catching configuration errors before lengthy build process. Enforces security best practices around credential management.

**Acceptance Criteria**:
- Build script checks environment file exists before starting
- Script validates URL format matches `https://*.supabase.co`
- Script verifies no `*.env` files are git-tracked
- Clear error messages indicate exactly which field is invalid
- Validation completes in <1 second
- Non-zero exit code on validation failure

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
  final envFile = File('config/supabase.$environment.env');

  // REQ-d00002: Check environment file exists
  if (!envFile.existsSync()) {
    print('❌ Configuration file not found: ${envFile.path}');
    print('   Create this file with required Supabase credentials.');
    exit(1);
  }

  // REQ-d00002: Validate required variables present
  final contents = envFile.readAsStringSync();
  final requiredVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_PROJECT_REF',
    'SPONSOR_ID',
  ];

  for (final varName in requiredVars) {
    if (!contents.contains('$varName=')) {
      print('❌ Missing required variable: $varName');
      print('   Add to ${envFile.path}');
      exit(1);
    }
  }

  // REQ-d00002: Validate URL format
  final urlMatch = RegExp(r'SUPABASE_URL=(.+)').firstMatch(contents);
  if (urlMatch != null) {
    final url = urlMatch.group(1)!.trim();
    if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
      print('❌ Invalid SUPABASE_URL format: $url');
      print('   Expected: https://*.supabase.co');
      exit(1);
    }
  }

  // REQ-d00002: Check git tracking
  final result = Process.runSync('git', ['ls-files', envFile.path]);
  if (result.stdout.toString().trim().isNotEmpty) {
    print('❌ Credential file is tracked in git: ${envFile.path}');
    print('   Add *.env to .gitignore and remove from git');
    exit(1);
  }

  print('✅ Configuration validated successfully');
  print('   Environment: $environment');
  print('   Config file: ${envFile.path}');
}
```

**Integration with Build Process**:

```bash
# Run validation before build
dart run tools/build_system/validate_config.dart production
if [ $? -ne 0 ]; then
  echo "Configuration validation failed"
  exit 1
fi

# Proceed with build
flutter build apk --dart-define-from-file=config/supabase.prod.env
```

---

## Testing Configuration

### Unit Tests

```dart
// test/config/supabase_config_test.dart
import 'package:test/test.dart';
import 'package:clinical_diary/config/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    test('throws when SUPABASE_URL missing', () {
      expect(
        () => SupabaseConfig.fromEnvironment(),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('validates URL format', () {
      // Test with invalid URL should throw
      // Implementation depends on test environment setup
    });

    test('loads valid configuration', () {
      // REQ-d00001: Configuration loads from environment
      final config = SupabaseConfig(
        url: 'https://test123.supabase.co',
        anonKey: 'test-key',
        projectRef: 'test123',
        sponsorId: 'orion',
      );

      expect(config.url, contains('.supabase.co'));
      expect(config.sponsorId, equals('orion'));
    });
  });
}
```

---

## Security Considerations

1. **Never commit `.env` files**: Always in `.gitignore`
2. **Rotate keys regularly**: Supabase allows key rotation without downtime
3. **Use service role keys only in backend**: Never expose in mobile app
4. **Environment-specific keys**: Staging and production use different keys
5. **Validate at build time**: Catch configuration errors before deployment

---

## Troubleshooting

### Configuration file not found

```
❌ Configuration file not found: config/supabase.prod.env
```

**Solution**: Create the configuration file from template:
```bash
cp config/supabase.template.env config/supabase.prod.env
# Edit with actual credentials
```

### Invalid URL format

```
❌ Invalid SUPABASE_URL format: http://localhost:54321
```

**Solution**: Ensure URL matches production Supabase format:
```
SUPABASE_URL=https://your-project-ref.supabase.co
```

### Credential file tracked in git

```
❌ Credential file is tracked in git: config/supabase.prod.env
```

**Solution**: Remove from git and add to `.gitignore`:
```bash
git rm --cached config/supabase.prod.env
echo "*.env" >> .gitignore
git commit -m "Remove credentials from git"
```

---

## References

- **REQ-p00001**: Multi-Sponsor Data Isolation (prd-security.md)
- **REQ-o00001**: Separate Supabase Projects Per Sponsor (ops-deployment.md)
- **REQ-o00002**: Environment-Specific Configuration Management (ops-deployment.md)
- Supabase Documentation: https://supabase.com/docs
- Dart Environment Variables: https://dart.dev/tools/dart-compile#environment
