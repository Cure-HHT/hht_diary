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

### Run Tests

```bash
# Simple test run
./tool/test.sh

# With custom concurrency
./tool/test.sh --concurrency 20
```

### Run Tests with Coverage

```bash
# Generate coverage report
./tool/coverage.sh

# View HTML report
open coverage/html/index.html  # Mac
xdg-open coverage/html/index.html  # Linux
```

### Install lcov (for coverage HTML reports)

**Mac**:
```bash
brew install lcov
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install lcov
```

**Linux** (Fedora/RHEL):
```bash
sudo dnf install lcov
```

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
│   - Commands (RecordEventCommand)
│   - Queries (GetEventsQuery)   │
│   - ViewModels                  │
└─────────────────────────────────┘
           ↓ uses
┌─────────────────────────────────┐
│   trial_data_types              │
│   - Events (NosebleedEvent)     │
│   - Entities (Participant)      │
└─────────────────────────────────┘
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
- Severity rating (1-10)
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
- **Audit trail** - Every action tracked
- **Electronic signatures** - Cryptographic signatures on events
- **Data integrity** - Tamper detection
- **Encryption** - At rest and in transit

### Data Protection

- **Local Storage**: AES-256 encrypted via SQLCipher
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
- Include comprehensive documentation
- Be reviewed by at least one other developer
- Include user testing plan

## 📝 License

See repository root LICENSE file.

---

**Remember**: This app handles sensitive patient health information. Security and compliance are paramount. 🏥
