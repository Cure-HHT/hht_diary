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

- Flutter SDK 3.38.7 or higher
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
   cd apps/daily-diary/clinical_diary
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

| Flavor | App Name       | Bundle ID                  | Banner | Dev Tools |
|--------|----------------|----------------------------|--------|-----------|
| `dev`  | Diary DEV      | org.anspar.curehht.app.dev | Orange | Yes       |
| `qa`   | Diary QA       | org.anspar.curehht.app.qa  | Purple | Yes       |
| `uat`  | Clinical Diary | org.anspar.curehht.app.uat | None   | No        |
| `prod` | Clinical Diary | org.anspar.curehht.app     | None   | No        |

Each flavor has:
- **Distinct bundle ID** - Allows side-by-side installation on the same device
- **Unique app icon** - DEV/TEST have labeled icons for easy identification
- **Separate Firebase project** - Isolated data per environment
- **Environment-specific API base URL**

### Running with Flavors

All configuration (API base URL, feature flags, etc.) is derived from a single `APP_FLAVOR` value.
This simplifies build commands and IDE configurations.

**Using IDE Run Configurations (Recommended):**

Pre-configured run configurations are available for both IDEs:
- **IntelliJ IDEA**: `.idea/runConfigurations/` (dev, qa, uat, prod, plus profile/release variants)
- **VS Code**: `.vscode/launch.json`

Simply select the desired flavor from your IDE's run configuration dropdown.

**Using Command Line:**

```bash
# Web builds (--flavor doesn't work on web, use --dart-define only)
flutter run -d chrome --dart-define=APP_FLAVOR=dev
flutter run -d chrome --dart-define=APP_FLAVOR=qa
flutter run -d chrome --dart-define=APP_FLAVOR=prod

# Mobile builds (--flavor sets FLUTTER_APP_FLAVOR for native config)
# Include both for cross-platform compatibility
flutter run --flavor dev --dart-define=APP_FLAVOR=dev
flutter run --flavor qa --dart-define=APP_FLAVOR=qa
flutter run --flavor prod --dart-define=APP_FLAVOR=prod
```

### How Flavor Configuration Works

The app reads `APP_FLAVOR` (or `FLUTTER_APP_FLAVOR` on mobile) in `main.dart` and derives all
other settings from `FlavorConfig` in `lib/flavors.dart`:

| Setting        | Derived From                          |
|----------------|---------------------------------------|
| `apiBase`      | `FlavorConfig.byName(flavor).apiBase` |
| `showDevTools` | `F.showDevTools` (true for dev/qa)    |
| `showBanner`   | `F.showBanner` (true for dev/qa)      |

> **Note**: The `--flavor` flag only affects native platform builds (iOS/Android bundle IDs,
> app names, icons). For web builds, `--dart-define=APP_FLAVOR` is required.

### Building for Release

Build scripts are available in `tool/` for common build operations:

```bash
# Web builds
./tool/build_web_dev.sh
./tool/build_web_qa.sh
./tool/build_web_prod.sh

# iOS builds
./tool/build_ios_dev.sh
./tool/build_ios_prod.sh

# Android builds
./tool/build_android_dev.sh
./tool/build_android_prod.sh
```

Or build manually:

```bash
# Web (use --dart-define only)
flutter build web --release --dart-define=APP_FLAVOR=prod

# Mobile (include both --flavor and --dart-define)
flutter build apk --release --flavor prod --dart-define=APP_FLAVOR=prod
flutter build ios --release --flavor prod --dart-define=APP_FLAVOR=prod
flutter build appbundle --release --flavor prod --dart-define=APP_FLAVOR=prod
```

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
# Build for web (dev)
- name: Build Web
  run: flutter build web --release --dart-define=APP_FLAVOR=dev

# Build for Production APK
- name: Build Production APK
  run: flutter build apk --release --flavor prod --dart-define=APP_FLAVOR=prod

# Build iOS
- name: Build Production iOS
  run: flutter build ios --release --flavor prod --dart-define=APP_FLAVOR=prod --no-codesign
```

### Firebase Configuration

Each flavor uses its own Firebase project:

| Flavor | Firebase Project | Hosting URL                   |
|--------|------------------|-------------------------------|
| dev    | hht-diary-mvp    | https://hht-diary-mvp.web.app |
| qa     | hht-diary-qa     | https://hht-diary-qa.web.app  |
| uat    | hht-diary-uat    | https://hht-diary-uat.web.app |
| prod   | hht-diary        | https://hht-diary.web.app     |

Firebase configuration is managed via:
- `firebase.json` - Hosting, functions, and Firestore config
- `.firebaserc` - Project aliases
- `lib/firebase_options.dart` - Generated Flutter Firebase config

## Push Notifications (FCM)

The app uses Firebase Cloud Messaging (FCM) to receive push notifications from the portal server. This is used for the questionnaire task system (REQ-CAL-p00023, REQ-CAL-p00081).

### Architecture

The mobile app talks to the **diary server** (not the portal server). The portal server sends
FCM notifications. Both servers share the same database.

```
Portal Server (per-sponsor GCP project)          Diary Server (per-sponsor GCP project)
  │                                                 ▲
  │  Coordinator clicks "Send Questionnaire"        │  Mobile app registers FCM token
  │  → Creates questionnaire_instances row           │  POST /api/v1/user/fcm-token
  │  → Looks up FCM token from shared DB             │  → Stores in patient_fcm_tokens table
  │  → Sends FCM via HTTP v1 API                     │
  │                                                 │
  │  FCM HTTP v1 API                              Patient's Mobile App
  │  (WIF/ADC auth, no key files)                   │
  │                                                 ├── MobileNotificationService
  ▼                                                 │   - Requests permission (iOS/Android 13+)
Firebase (cure-hht-admin GCP project)               │   - Gets FCM registration token
  │                                                 │   - Sends token to diary server
  │  Routes by FCM token                            │   - Listens for foreground/background msgs
  │                                                 │
  └──────────────────────────────────────────────►  └── TaskService
                                                        - Routes FCM data by 'type' field
              ┌──────────────────┐                      - Manages task list (ChangeNotifier)
              │  Shared Database │                      - Persists to SharedPreferences
              │  (PostgreSQL)    │
              │                  │
              │  patient_fcm_    │  ◄── Written by diary server
              │    tokens        │  ◄── Read by portal server
              │  questionnaire_  │  ◄── Written by portal server
              │    instances     │  ◄── (future: read by diary server for sync)
              └──────────────────┘
```

### How Device Targeting Works

1. **App startup**: `MobileNotificationService` requests an FCM registration token from Firebase. This is a unique ~150-char string identifying this app installation on this device.
2. **Token registration** (TODO): The app sends this token to the **diary server** via `POST /api/v1/user/fcm-token` (JWT auth). The diary server stores it in the `patient_fcm_tokens` database table linked to the patient's ID.
3. **Token refresh**: Firebase may rotate the token at any time. The app listens for `onTokenRefresh` and re-registers with the diary server.
4. **Sending**: When a coordinator clicks "Send Questionnaire", the **portal server** looks up the patient's active FCM token from the **shared database** and calls the FCM HTTP v1 API to deliver a data-only message to that specific device.
5. **No token?**: If no token is registered (e.g., app not installed), the questionnaire is still created server-side. The patient discovers it via data sync.

**Why two servers?** The mobile app only talks to the diary server (JWT auth via linking codes). The portal UI only talks to the portal server (Firebase Auth). They share the same PostgreSQL database, so the portal server can read tokens that the diary server wrote.

### FCM Message Format

Messages are **data-only** (no PHI in the notification payload):

```json
{
  "message": {
    "token": "<patient_fcm_token>",
    "data": {
      "type": "questionnaire_sent",
      "questionnaire_type": "nose_hht",
      "questionnaire_instance_id": "<uuid>",
      "action": "new_task"
    },
    "notification": {
      "title": "New Questionnaire Available",
      "body": "You have a new questionnaire to complete."
    }
  }
}
```

For deletion (`type: "questionnaire_deleted"`), only the `data` payload is sent (no notification banner).

### Key Files

| File                                     | Purpose                                                  |
|------------------------------------------|----------------------------------------------------------|
| `lib/services/notification_service.dart` | FCM initialization, permission, token, message handling  |
| `lib/services/task_service.dart`         | Task list management, FCM data message routing           |
| `lib/widgets/task_list_widget.dart`      | Task cards on home screen (priority-sorted, color-coded) |
| `lib/main.dart` (`_AppRootState`)        | Wires TaskService + MobileNotificationService on init    |
| `lib/screens/home_screen.dart`           | Hosts TaskListWidget in banner section                   |

### Testing Locally

**Without a real device** (console mode):

The portal server supports `FCM_CONSOLE_MODE=true` which logs notification payloads to stdout instead of sending them. This is the default in `run_local.sh`.

To simulate a notification arriving on the mobile app:
```bash
# From the sponsor-portal directory:
./tool/testNotification.sh
```

This script calls the portal server's questionnaire API, which will log the FCM payload to the server console in console mode.

**On a real device** (dev/qa environments):

1. Run the app on a physical device with `--flavor dev`
2. The app will request notification permissions and obtain an FCM token
3. Check the debug console for `[FCM] Token: ...`
4. Send a test notification via Firebase Console:
   - Go to Firebase Console > cure-hht-admin > Messaging
   - Click "Send your first message"
   - Enter title/body, click "Send test message"
   - Paste the FCM token from the debug console
5. Or use the portal server's API endpoint (once token registration is built)

### Environment Variables (Portal Server)

| Variable           | Default          | Description                                           |
|--------------------|------------------|-------------------------------------------------------|
| `FCM_PROJECT_ID`   | `cure-hht-admin` | Firebase project for FCM API endpoint                 |
| `FCM_ENABLED`      | `true`           | Set to `false` to disable push notifications          |
| `FCM_CONSOLE_MODE` | `false`          | Set to `true` for local dev (logs instead of sending) |

### Remaining Work

- [ ] Database migration: `patient_fcm_tokens` and `questionnaire_instances` tables
- [ ] Token registration endpoint: `POST /api/v1/user/fcm-token` on diary server (mobile app talks to diary server, not portal)
- [ ] Mobile app: send FCM token to diary server on startup and refresh
- [ ] Task tap navigation: route to questionnaire screen
- [ ] iOS: Enable Push Notifications capability in Xcode, upload APNs key to Firebase

---

## 🔄 Version Checking & Updates

The app includes an automatic version checking system that notifies users when updates are available.

### How It Works

1. **Build Time**: The CI workflow extracts the version from `pubspec.yaml` and embeds it via `--dart-define=APP_VERSION=x.x.x`
2. **Deploy Time**: A `version.json` file is generated containing the current version plus `minVersion` and `releaseNotes` from `version-info.json`
3. **Runtime**: The app compares the embedded version against the remote `version.json` (fetched with cache-busting)

### Update Notifications

| Condition                       | UI Behavior                              |
|---------------------------------|------------------------------------------|
| Local version < remote version  | Dismissible blue banner at top of screen |
| Local version < minVersion      | Blocking dialog (cannot dismiss)         |
| Local version >= remote version | No notification                          |

The banner/dialog includes:
- Current and new version numbers
- Release notes (if provided)
- "Update Now" button (clears cache and reloads on web)

### Update Indicator

When an update is available, a small dot appears on the logo menu icon with a tooltip saying "Update available".

### Configuration

Edit `version-info.json` in the app root to control update behavior:

```json
{
  "minVersion": "0.7.68",
  "releaseNotes": "Bug fixes and improvements"
}
```

| Field          | Description                                                               |
|----------------|---------------------------------------------------------------------------|
| `minVersion`   | Minimum supported version. Users below this see a blocking update dialog. |
| `releaseNotes` | Text shown in update banner/dialog. Keep it brief.                        |

### Check Frequency

Version checks occur at most once every 24 hours to avoid excessive network calls. The check timestamp is stored in SharedPreferences.

### Web Cache Handling

On web, the "Update Now" button:
1. Unregisters all service workers
2. Clears all CacheStorage caches
3. Forces a hard page reload

This ensures users get the latest version even with aggressive browser caching.

### Firebase Hosting Cache Headers

Cache-busting headers are configured in `firebase.json`:
- `index.html` - `no-cache, no-store, must-revalidate`
- `version.json` - `no-cache, no-store, must-revalidate`
- `flutter_service_worker.js` - `no-cache, max-age=0`

### Related Files

| File                                      | Purpose                                  |
|-------------------------------------------|------------------------------------------|
| `version-info.json`                       | Maintainable minVersion and releaseNotes |
| `lib/utils/app_version.dart`              | Embedded version constant                |
| `lib/services/version_check_service.dart` | Version comparison and fetch logic       |
| `lib/widgets/update_banner.dart`          | Dismissible update banner                |
| `lib/widgets/update_dialog.dart`          | Blocking update dialog                   |
| `lib/widgets/update_banner_wrapper.dart`  | Wrapper that orchestrates update UI      |

## 🔐 Configuration with Doppler

[Doppler](https://www.doppler.com/) is used for secrets management. All sensitive configuration
values are stored in Doppler and automatically shared with team members who have access to the
project. This eliminates insecure secret sharing via Slack, email, or .env files.

### Why Doppler?

- **Team Sharing**: Secrets are automatically available to all authorized team members
- **Environment Sync**: Secrets sync in real-time across team members and environments
- **Audit Logging**: Track who accessed secrets and when
- **Firebase Integration**: Native support for Firebase Functions deployment
- **No .env Files**: Eliminates the need for manual secret file management

### Getting Started with Doppler

1. **Install Doppler CLI**:
   ```bash
   # Mac
   brew install dopplerhq/cli/doppler

   # Linux
   curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh | sh
   ```

2. **Login to Doppler**:
   ```bash
   doppler login
   ```

3. **Setup project** (links local directory to Doppler project):
   ```bash
   cd apps/daily-diary/clinical_diary
   doppler setup
   # Select: hht-diary > dev (or your environment)
   ```

4. **Verify secrets are available**:
   ```bash
   doppler secrets
   ```

   You should see all project secrets. If you're missing `CUREHHT_QA_API_KEY`,
   ask a teammate to verify you have access to the dev/qa configs.

5. **Run with Doppler** (injects secrets as environment variables):
   ```bash
   # For web
   doppler run -- flutter run -d chrome --dart-define=APP_FLAVOR=dev

   # For mobile
   doppler run -- flutter run --flavor dev --dart-define=APP_FLAVOR=dev
   ```

### Team Secret Sharing

Doppler automatically shares secrets with team members based on project access. Once you're
added to the `hht-diary` project in Doppler, you'll have access to all secrets for your
assigned environments.

**For new team members:**
1. Ask a project admin to add you to the `hht-diary` project in Doppler
2. Run `doppler login` and `doppler setup`
3. All secrets (including `CUREHHT_QA_API_KEY`) will be automatically available

**No manual key sharing required** - Doppler handles this securely.

### Adding a New Secret to Doppler

**Option 1: Web Dashboard**
1. Go to [dashboard.doppler.com](https://dashboard.doppler.com)
2. Select your project (e.g., `hht-diary`)
3. Select your environment/config (e.g., `dev`)
4. Click **"Add Secret"**
5. Enter the secret name and value
6. Click **"Save"**

**Option 2: CLI**
```bash
# Add to specific environment
doppler secrets set CUREHHT_QA_API_KEY="your-api-key-here" --config dev

# View all secrets (values hidden)
doppler secrets

# View a specific secret value
doppler secrets get CUREHHT_QA_API_KEY
```

### Required Secrets

| Secret               | Description                         | Environments | Used By                         |
|----------------------|-------------------------------------|--------------|---------------------------------|
| `CUREHHT_QA_API_KEY` | API key for sponsor config endpoint | dev, qa only | Flutter app, Firebase Functions |

> **Note**: Configuration like `apiBase` is no longer passed via dart-define. It's derived from
> the `APP_FLAVOR` setting in `lib/flavors.dart`.

### Firebase Functions Secrets (Doppler Integration)

Doppler can sync secrets directly to Firebase Functions, eliminating the need for Google Secret
Manager for most use cases. See [Doppler Firebase Integration](https://docs.doppler.com/docs/firebase-installation).

**Setup for Firebase Functions:**

1. **Link Doppler to the functions directory**:
   ```bash
   cd apps/daily-diary/clinical_diary/functions
   doppler setup
   # Select: hht-diary > dev
   ```

2. **Update package.json scripts** for local development:
   ```json
   {
     "scripts": {
       "serve": "CLOUD_RUNTIME_CONFIG=\"$(doppler secrets download --no-file | jq '{doppler: .}')\" firebase emulators:start --only functions"
     }
   }
   ```

3. **Access secrets in Firebase Functions**:
   ```typescript
   import * as functions from 'firebase-functions';

   // Secrets are available under functions.config().doppler
   const apiKey = functions.config().doppler?.CUREHHT_QA_API_KEY;
   ```

4. **Deploy secrets to Firebase** (CI/CD):
   ```bash
   # Sync Doppler secrets to Firebase config
   firebase functions:config:set doppler="$(doppler secrets download --no-file)"

   # Then deploy
   firebase deploy --only functions
   ```

**Alternative: Google Secret Manager**

If you prefer using Google Secret Manager (which we currently use), secrets are configured
separately in the Firebase Console under Project Settings > Service Accounts, or via:
```bash
firebase functions:secrets:set CUREHHT_QA_API_KEY
```

### Environment-Specific Configs

| Environment | Doppler Config | Has QA API Key |
|-------------|----------------|----------------|
| Development | `dev`          | Yes            |
| QA          | `qa`           | Yes            |
| UAT         | `uat`          | No             |
| Production  | `prd`          | No             |

**Why no QA API Key in UAT/Prod?**

The `CUREHHT_QA_API_KEY` is only for dev/qa testing of the sponsor configuration feature.
In production, sponsor configuration will be loaded during enrollment using production
authentication, not a shared test key.

### Accessing Configuration in Flutter Code

Most configuration is derived from the flavor, not dart-defines:

```dart
import 'package:clinical_diary/flavors.dart';
import 'package:clinical_diary/config/app_config.dart';

// API base URL (derived from FlavorConfig)
final apiUrl = AppConfig.apiBase;  // e.g., "https://hht-diary-mvp.web.app/api"

// Feature flags (derived from flavor)
if (AppConfig.showDevTools) {
  // Show debug menu
}

// Secrets still use dart-define (passed from Doppler)
static const String _qaApiKeyRaw = String.fromEnvironment('CUREHHT_QA_API_KEY');
```

The IDE run configurations only need to pass `--dart-define=APP_FLAVOR=<flavor>`.

## 🧪 Testing

This project uses a comprehensive testing strategy covering both Flutter (Dart) and Firebase Functions (TypeScript).

### Testing with Pre-populated Data

The app supports loading test data on startup via the `IMPORT_FILE` dart-define. This is useful for:
- Manual testing with consistent data
- Demo presentations
- QA testing specific scenarios

**Using run scripts (recommended):**

```bash
# Run dev flavor with test data
./tool/run_dev.sh --import-file ./test/data/hht-diary-export-2025-12-14-123050.json

# Run on web with test data
./tool/run_dev.sh --web --import-file ./test/data/export.json

# Run QA flavor with test data
./tool/run_qa.sh --import-file ./test/data/export.json

# Run UAT flavor
./tool/run_uat.sh --import-file ./test/data/export.json
```

**Using flutter run directly:**

```bash
# Web (absolute path required)
flutter run -d chrome --dart-define=APP_FLAVOR=dev \
    --dart-define=IMPORT_FILE=/full/path/to/export.json

# Mobile (absolute path required)
flutter run --flavor dev --dart-define=APP_FLAVOR=dev \
    --dart-define=IMPORT_FILE=/full/path/to/export.json
```

**Notes:**
- The file path must be absolute when using `--dart-define` directly
- The run scripts automatically convert relative paths to absolute
- IMPORT_FILE only works on native platforms (iOS, Android, macOS, Linux, Windows)
- On web, IMPORT_FILE is ignored (browsers cannot read local files)
- Import merges with existing data (duplicates are skipped by record ID)
- To start fresh, use "Reset All Data" from the logo menu before running with IMPORT_FILE

### Run Scripts

Convenience scripts in `tool/` for running the app with different flavors:

| Script              | Flavor | Dev Tools |
|---------------------|--------|-----------|
| `./tool/run_dev.sh` | dev    | Yes       |
| `./tool/run_qa.sh`  | qa     | Yes       |
| `./tool/run_uat.sh` | uat    | No        |

All scripts support these options:
- `--import-file <path>` - Auto-import JSON export file on startup
- `--device <device>` - Specify device (e.g., `chrome`, `macos`, `iPhone 15`)
- `--web` - Shortcut for `--device chrome`

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

### Widgetbook Component Catalog

[Widgetbook](https://www.widgetbook.io/) provides an interactive component catalog for developing and testing widgets in isolation. It's similar to Storybook for web development.

**Running Widgetbook:**

```bash
# macOS (recommended for development)
flutter run -t widgetbook/main.dart -d macos

# Web
flutter run -t widgetbook/main.dart -d chrome

# iOS Simulator
flutter run -t widgetbook/main.dart -d iPhone
```

**Features:**

| Feature        | Description                                                      |
|----------------|------------------------------------------------------------------|
| **Viewports**  | Test on iPhone 13, iPhone SE, Samsung Galaxy S20, Galaxy Note 20 |
| **Themes**     | Switch between Light and Dark modes                              |
| **Locales**    | Test all supported languages (EN, ES, FR, DE)                    |
| **Text Scale** | Accessibility testing with text scaling (1.0x - 2.0x)            |
| **Knobs**      | Interactive controls to modify widget properties                 |

**Available Use Cases:**

- **Profile Screen > Participation Status Badge**
  - Active State - Enrolled and connected to clinical trial
  - Disconnected State - Warning state with reconnect option
  - Not Participating - Not enrolled in any trial
  - Interactive - Modify properties via knobs

**Adding New Use Cases:**

Edit `widgetbook/main.dart` to add new components:

```dart
WidgetbookComponent(
  name: 'My Widget',
  useCases: [
    WidgetbookUseCase(
      name: 'Default State',
      builder: (context) => MyWidget(),
    ),
    WidgetbookUseCase(
      name: 'With Knobs',
      builder: (context) {
        final enabled = context.knobs.boolean(
          label: 'Enabled',
          initialValue: true,
        );
        return MyWidget(enabled: enabled);
      },
    ),
  ],
),
```

**Documentation:** [Widgetbook Docs](https://docs.widgetbook.io/)

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

| Benefit              | Description                                                                                                                                                |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Tamper Detection** | SHA-256 hash chain links each event to its predecessor. Any modification breaks the chain and is immediately detectable.                                   |
| **FDA Compliance**   | Immutable audit trail with sequence numbers, timestamps, and user/device attribution. Events cannot be updated or deleted—only new events can be appended. |
| **Cross-Platform**   | Uses Sembast database with platform-specific storage: `sembast_io` for iOS/Android/macOS/Windows/Linux, `sembast_web` for browser (IndexedDB).             |
| **Offline-First**    | All data is stored locally first. Cloud sync is tracked per-event with `syncedAt` timestamps.                                                              |
| **Testable**         | Repository injection allows easy mocking. Tests use in-memory Sembast databases for fast, isolated execution.                                              |

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
