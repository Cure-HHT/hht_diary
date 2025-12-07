# Clinical Diary

Flutter application for FDA-compliant clinical trial data collection, focusing on nosebleed incident tracking for HHT (Hereditary Hemorrhagic Telangiectasia) patients.

## Features

- ✅ Offline-first data entry
- ✅ Encrypted local storage
- ✅ Automatic cloud synchronization
- ✅ FDA 21 CFR Part 11 compliance
- ✅ Multi-device support
- ✅ Real-time sync status
- ✅ Conflict resolution

## Quick Start

### Prerequisites

- Flutter SDK 3.10.1 or higher
- Doppler CLI (for secrets management)
- lcov (for coverage reports)

### Installation

1. **Clone the repository**
2. **Install Doppler**:
   ```bash
   # Mac
   brew install dopplerhq/cli/doppler
   
   # Linux
   curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh | sh
   ```

3. **Setup Doppler**:
   ```bash
   cd apps/clinical_diary
   doppler login
   doppler setup
   ```

4. **Install dependencies**:
   ```bash
   flutter pub get
   ```

### Running the App

```bash
# With Doppler (recommended)
doppler run -- flutter run

# Or set environment variables manually
export DATASTORE_ENCRYPTION_KEY="your-key-here"
export SYNC_SERVER_URL="https://api.example.com"
flutter run
```

## 🎨 Environment Flavors

The app uses [flutter_flavorizr](https://pub.dev/packages/flutter_flavorizr) to support four environments with distinct app identities:

| Flavor | App Name       | Bundle ID                     | Banner | Dev Tools |
| ------ | -------------- | ----------------------------- | ------ | --------- |
| `dev`  | Diary DEV      | org.curehht.clinicaldiary.dev | Orange | Yes       |
| `qa`   | Diary QA       | org.curehht.clinicaldiary.qa  | Purple | Yes       |
| `uat`  | Clinical Diary | org.curehht.clinicaldiary.uat | None   | No        |
| `prod` | Clinical Diary | org.curehht.clinicaldiary     | None   | No        |

Each flavor has:
- **Distinct bundle ID** - Allows side-by-side installation on the same device
- **Unique app icon** - DEV/TEST have labeled icons for easy identification
- **Separate Firebase project** - Isolated data per environment
- **Environment-specific API base URL**

### Running with Flavors

```bash
# Development
flutter run --flavor dev

# Test environment
flutter run --flavor qa

# UAT (looks like production)
flutter run --flavor uat

# Production
flutter run --flavor prod
```

### Building for Release

```bash
# Build APK for production
flutter build apk --release --flavor prod

# Build iOS for production
flutter build ios --release --flavor prod

# Build for UAT testing
flutter build apk --release --flavor uat
flutter build ios --release --flavor uat
```

### Regenerating Flavor Configs

If you modify `flavorizr.yaml`, regenerate the native configurations:

```bash
flutter pub get
dart run flutter_flavorizr
```

This will regenerate:
- Android: `android/app/build.gradle.kts` productFlavors
- iOS: Xcode schemes and xcconfig files
- VS Code: Launch configurations

### Environment Features

**Dev/Test environments (`showDevTools: true`):**
- "Reset All Data" menu option - clears local database for testing
- "Add Example Data" menu option - populates sample records
- Corner ribbon banner showing environment name

**UAT/Prod environments (`showDevTools: false`):**
- Dev menu items are hidden
- No environment banner
- UI mirrors production exactly
- FDA-compliant append-only datastore (no data deletion)

### Using in Code

```dart
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/config/app_config.dart';

// Check current flavor
if (F.appFlavor == Flavor.prod) {
  // Production-specific logic
}

// Check if dev tools should be shown
if (F.showDevTools) {
  // Show debug menu items
}

// Or use AppConfig (delegates to F)
if (AppConfig.showDevTools) {
  // Show debug menu items
}

// Get app title for current flavor
print(F.title); // "Diary DEV", "Diary QA", or "Clinical Diary"
```

### CI/CD Integration

In GitHub Actions workflows:

```yaml
# Build for UAT
- name: Build UAT APK
  run: flutter build apk --release --flavor uat

# Build for Production
- name: Build Production APK
  run: flutter build apk --release --flavor prod

# Build iOS
- name: Build Production iOS
  run: flutter build ios --release --flavor prod --no-codesign
```

### Firebase Configuration

Each flavor uses its own Firebase project. Config files are located at:

```
.firebase/
├── dev/
│   ├── google-services.json      # Android
│   └── GoogleService-Info.plist  # iOS
├── test/
│   ├── google-services.json
│   └── GoogleService-Info.plist
├── uat/
│   ├── google-services.json
│   └── GoogleService-Info.plist
└── prod/
    ├── google-services.json
    └── GoogleService-Info.plist
```

Run `dart run flutter_flavorizr` to copy these to the correct platform-specific locations.

## 🔐 Configuration with Doppler

### Required Secrets

Set these in Doppler for your environment:

```bash
# Database encryption (required)
doppler secrets set DATASTORE_ENCRYPTION_KEY="$(openssl rand -base64 32)"

# Sync server (required)
doppler secrets set SYNC_SERVER_URL="https://api.example.com"
doppler secrets set SYNC_API_KEY="your-api-key"

# User authentication (required)
doppler secrets set AUTH_CLIENT_ID="your-client-id"
doppler secrets set AUTH_CLIENT_SECRET="your-client-secret"

# OpenTelemetry (optional)
doppler secrets set OTEL_ENDPOINT="https://otel.example.com"
doppler secrets set OTEL_API_KEY="your-otel-key"
```

### Environment-Specific Configs

**Development**:
```bash
doppler setup --config dev
doppler secrets set DATASTORE_ENCRYPTION_KEY="dev-key-not-for-production" --config dev
```

**Staging**:
```bash
doppler setup --config stg
doppler secrets set DATASTORE_ENCRYPTION_KEY="$(openssl rand -base64 32)" --config stg
```

**Production**:
```bash
doppler setup --config prd
doppler secrets set DATASTORE_ENCRYPTION_KEY="$(openssl rand -base64 32)" --config prd
```

### Accessing Secrets in Code

```dart
// In main.dart or config
final config = DatastoreConfig.production(
  deviceId: await getDeviceId(),
  userId: currentUser.id,
  syncServerUrl: Platform.environment['SYNC_SERVER_URL']!,
  encryptionKey: Platform.environment['DATASTORE_ENCRYPTION_KEY']!,
);
```

## 🧪 Testing

This project uses a comprehensive testing strategy covering both Flutter (Dart) and Firebase Functions (TypeScript).

### Test Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Testing Strategy                          │
├─────────────────────────────────────────────────────────────┤
│  Flutter (Dart)              │  Functions (TypeScript)       │
│  ─────────────────           │  ────────────────────────     │
│  • Unit tests (models,       │  • Unit tests (helpers,       │
│    services, config)         │    validators, JWT)           │
│  • Widget tests              │  • Integration tests          │
│  • Integration tests         │    (API endpoints)            │
│                              │  • Mocked Firestore           │
├─────────────────────────────────────────────────────────────┤
│  Coverage: Combined lcov report from both Dart & TypeScript │
└─────────────────────────────────────────────────────────────┘
```

### Quick Start

```bash
# Run all tests (Flutter + Functions)
./tool/test.sh

# Run only Flutter tests
./tool/test.sh --flutter

# Run only TypeScript/Functions tests
./tool/test.sh --typescript

# Run with coverage
./tool/coverage.sh

# Run coverage for specific platform
./tool/coverage.sh --flutter
./tool/coverage.sh --typescript
```

### Flutter Tests

```bash
# Run Flutter tests only
./tool/test.sh -f

# With custom concurrency
./tool/test.sh -f --concurrency 20

# Run specific test file
flutter test test/models/nosebleed_record_test.dart
```

**Test Categories:**
- `test/models/` - Model serialization, validation, computed properties
- `test/services/` - Service logic with mocked dependencies
- `test/config/` - Configuration and app settings
- `test/widgets/` - Widget rendering and interaction tests

### Firebase Functions Tests

```bash
# Run Functions tests only
./tool/test.sh -t

# Or from functions directory
cd functions
npm test

# Run with coverage
npm run test:coverage
```

**Test Categories:**
- `functions/src/__tests__/` - Unit and integration tests
- Tests use `firebase-functions-test` for mocking

### Coverage Reports

```bash
# Generate coverage reports
./tool/coverage.sh

# View HTML reports
# Flutter coverage (requires lcov):
open coverage/html-flutter/index.html  # Mac
xdg-open coverage/html-flutter/index.html  # Linux

# TypeScript/Functions coverage (always available):
open coverage/html-functions/index.html  # Mac
xdg-open coverage/html-functions/index.html  # Linux
```

The coverage script:
1. Runs Flutter tests with lcov output
2. Runs TypeScript tests with lcov output (generates HTML via Jest)
3. Merges both lcov files into a combined report (lcov-combined.info)
4. Generates separate HTML reports for Flutter and TypeScript

**Note**: TypeScript coverage HTML is always available at `coverage/html-functions/index.html` because Jest generates it directly. Flutter HTML reports require lcov to be installed.

### Install Dependencies

**lcov** (required for Flutter coverage HTML reports):
```bash
# Mac
brew install lcov

# Linux (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install lcov

# Linux (Fedora/RHEL)
sudo dnf install lcov

# Verify installation
lcov --version
genhtml --version
```

Without lcov installed:
- TypeScript coverage HTML: Available at `coverage/html-functions/index.html`
- Flutter coverage HTML: Not available (only lcov.info file)

### CI/CD Integration

Tests run automatically on:
- **Push/PR to main or develop**: Full test suite + lint + analyze
- **Coverage**: Uploaded to Codecov on main branch pushes

The CI pipeline will **fail** if:
- `dart format` finds unformatted code
- `flutter analyze` finds any issues (including infos)
- `eslint` finds any issues in TypeScript
- Any test fails
- TypeScript compilation fails

### Writing Tests

**Flutter Unit Test Example:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';

void main() {
  group('NosebleedRecord', () {
    test('fromJson creates valid record', () {
      final json = {
        'id': 'test-123',
        'date': '2024-01-15T00:00:00.000',
        'severity': 'dripping',
      };

      final record = NosebleedRecord.fromJson(json);

      expect(record.id, 'test-123');
      expect(record.severity, NosebleedIntensity.dripping);
    });
  });
}
```

**TypeScript Unit Test Example:**
```typescript
import { validateEnrollmentCode } from '../validators';

describe('validateEnrollmentCode', () => {
  it('accepts valid CUREHHT codes', () => {
    expect(validateEnrollmentCode('CUREHHT1')).toBe(true);
    expect(validateEnrollmentCode('curehht9')).toBe(true);
  });

  it('rejects invalid codes', () => {
    expect(validateEnrollmentCode('INVALID')).toBe(false);
    expect(validateEnrollmentCode('CUREHHTX')).toBe(false);
  });
});
```

### Test Coverage Requirements

- **Minimum coverage**: 80% (enforced in CI)
- **New code**: Should have tests for all public APIs
- **Bug fixes**: Should include regression test

### Widget Testing

```bash
# Run widget tests with golden files
flutter test --update-goldens  # Update golden images
flutter test                    # Run with comparison
```

## 📚 Development

### Project Structure

```
lib/
├── src/
│   └── presentation/
│       ├── screens/          # UI screens
│       │   ├── home_screen.dart
│       │   ├── nosebleed_entry_screen.dart
│       │   └── nosebleed_history_screen.dart
│       └── widgets/          # Reusable widgets
│           ├── nosebleed_list_item.dart
│           └── sync_status_indicator.dart
└── main.dart
```

### Architecture Principles

1. **Presentation Only** - No business logic in this app
2. **Reusable Logic** - Commands/queries/viewmodels in append_only_datastore
3. **Reactive UI** - Using Signals for state management
4. **Offline-First** - All data cached locally with encryption

### Development Workflow

```bash
# Install dependencies
flutter pub get

# Run app with hot reload
doppler run -- flutter run

# Run tests
./tool/test.sh

# Check code quality
flutter analyze
dart format .
```

### CI/CD Workflows

- **CI**: `.github/workflows/clinical_diary-ci.yml`
  - Triggers: Push/PR to main or develop
  - Runs: Format check, analyze, tests on stable and beta
  
- **Coverage**: `.github/workflows/clinical_diary-coverage.yml`
  - Triggers: Push to main
  - Runs: Coverage report, uploads to Codecov

## 🏗️ Architecture

```
┌─────────────────────────────────┐
│   clinical_diary (THIS APP)    │
│   - UI Screens                  │
│   - Widgets                     │
│   - Presentation only           │
└─────────────────────────────────┘
           ↓ uses
┌─────────────────────────────────┐
│ append_only_datastore           │
│   - EventRepository             │
│   - Hash chain integrity        │
│   - Cross-platform storage      │
└─────────────────────────────────┘
           ↓ uses
┌─────────────────────────────────┐
│   Sembast Database              │
│   - Native: sembast_io          │
│   - Web: sembast_web (IndexedDB)│
└─────────────────────────────────┘
```

### Append-Only Datastore Integration

The app uses the `append_only_datastore` package for offline-first event sourcing with FDA 21 CFR Part 11 compliance.

**Benefits of Integration:**

| Benefit | Description |
| ------- | ----------- |
| **Tamper Detection** | SHA-256 hash chain links each event to its predecessor. Any modification breaks the chain and is immediately detectable. |
| **FDA Compliance** | Immutable audit trail with sequence numbers, timestamps, and user/device attribution. Events cannot be updated or deleted—only new events can be appended. |
| **Cross-Platform** | Uses Sembast database with platform-specific storage: `sembast_io` for iOS/Android/macOS/Windows/Linux, `sembast_web` for browser (IndexedDB). |
| **Offline-First** | All data is stored locally first. Cloud sync is tracked per-event with `syncedAt` timestamps. |
| **Testable** | Repository injection allows easy mocking. Tests use in-memory Sembast databases for fast, isolated execution. |

**How It Works:**

1. **Initialization** (main.dart):
   ```dart
   await Datastore.initialize(
     config: DatastoreConfig.development(
       deviceId: deviceId,
       userId: 'anonymous',
     ),
   );
   ```

2. **Recording Events** (NosebleedService):
   ```dart
   final storedEvent = await _eventRepository.append(
     aggregateId: 'diary-2024-01-15',
     eventType: 'NosebleedRecorded',
     data: eventData,
     userId: userId,
     deviceId: deviceUuid,
     clientTimestamp: DateTime.now(),
   );
   ```

3. **Integrity Verification**:
   ```dart
   final isValid = await _eventRepository.verifyIntegrity();
   ```

## 🚀 Phase 1 Status

- ✅ Project structure created
- ✅ Testing infrastructure
- ✅ CI/CD pipelines
- ⏳ Main screen (Day 17)
- ⏳ Nosebleed entry screen (Day 17)
- ⏳ Nosebleed history screen (Day 18)
- ⏳ Sync status indicator (Day 18)
- ⏳ Offline banner (Day 18)

## 📱 Features

### Nosebleed Entry
- Date and time picker
- Duration tracking
- Intensity rating (1-10)
- Location (left/right nostril)
- Photos (optional)
- Notes field
- Offline support

### History View
- Chronological list of nosebleeds
- Filter by date range
- Export to PDF
- Share with physician
- Sync status per entry

### Sync Status
- Real-time sync indicator
- Pending events count
- Last sync time
- Manual sync button
- Offline banner when disconnected

## 🔒 Security & Compliance

### FDA 21 CFR Part 11

This app implements:
- **Secure authentication** - Multi-factor where available
- **Audit trail** - Every action tracked via append-only event store
- **Electronic signatures** - Cryptographic signatures on events
- **Data integrity** - SHA-256 hash chain for tamper detection (see [Append-Only Datastore Integration](#append-only-datastore-integration))
- **Encryption** - At rest and in transit
- **Immutability** - Events cannot be updated or deleted, only appended

### Data Protection

- **Local Storage**: Sembast database with platform-specific storage (native or IndexedDB for web)
- **Network**: TLS 1.3+ only
- **Secrets**: Never in code, always in Doppler
- **Backup**: Encrypted cloud backups only

## 📖 User Documentation

See `/docs/user-guide.md` (to be created in Phase 2)

## 🐛 Troubleshooting

### App won't start

```bash
# Check Doppler is configured
doppler setup --no-interactive

# Verify secrets are set
doppler secrets

# Clear Flutter cache
flutter clean
flutter pub get
```

### Sync failing

```bash
# Check sync server URL
echo $SYNC_SERVER_URL

# Verify API key
doppler secrets get SYNC_API_KEY

# Check device connectivity
flutter run --verbose
```

### Database errors

```bash
# Clear local database (will lose offline data!)
flutter clean
rm -rf ~/.flutter-devtools

# Restart app
doppler run -- flutter run
```

## 🤝 Contributing

This is FDA-regulated medical software. All contributions must:
- Pass all tests
- Maintain 90%+ code coverage
- Follow strict linting rules
  - Pass flutter analyze cleanly - no errors, warnings or info, even in test code
  - Pass dart format cleanly, even in test code
- Include comprehensive documentation
- Be reviewed by at least one other developer
- Include user testing plan
- Failing tests should be created first
- Integration tests are strongly preferred when reasonable and possible

## 📝 License

See repository root LICENSE file.

---

**Remember**: This app handles sensitive patient health information. Security and compliance are paramount. 🏥
