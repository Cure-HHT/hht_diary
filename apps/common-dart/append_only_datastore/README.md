# Append-Only Datastore

FDA 21 CFR Part 11 compliant, offline-first event sourcing for Flutter applications.

## Features

- ✅ SQLite + SQLCipher encrypted storage
- ✅ Offline queue with automatic synchronization
- ✅ Conflict detection using version vectors
- ✅ Immutable audit trail
- ✅ OpenTelemetry integration
- ✅ Reactive state with Signals

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  append_only_datastore:
    path: ../common-dart/append_only_datastore
  trial_data_types:
    path: ../common-dart/trial_data_types
```

### Basic Usage

```dart
import 'package:append_only_datastore/append_only_datastore.dart';

// Initialize with encryption
await Datastore.initialize(
  config: DatastoreConfig.production(
    deviceId: await getDeviceId(),
    userId: currentUser.id,
    syncServerUrl: 'https://api.example.com',
    encryptionKey: await getEncryptionKey(), // From Doppler
  ),
);

// Use in your app
final events = await Datastore.instance.queryService.getEvents();
```

## 🔐 Encryption Setup

This package uses **SQLCipher** for database encryption. Encryption is **enabled by default** for medical software security.

### Using Doppler for Key Management

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

3. **Setup Project**:

   ```bash
   cd apps/common-dart/append_only_datastore
   doppler setup
   ```

4. **Set Encryption Key** (generate strong 32-byte key):

   ```bash
   # Generate a secure key
   openssl rand -base64 32
   
   # Store in Doppler
   doppler secrets set DATASTORE_ENCRYPTION_KEY="<your-generated-key>"
   ```

5. **Access in Development**:

   ```bash
   # Run with Doppler
   doppler run -- flutter run
   
   # Or get key programmatically
   final encryptionKey = Platform.environment['DATASTORE_ENCRYPTION_KEY'];
   ```

### Environment Variables

Required secrets in Doppler:

```bash
# Database encryption
DATASTORE_ENCRYPTION_KEY=<base64-encoded-32-byte-key>

# Sync server
SYNC_SERVER_URL=https://api.example.com
SYNC_API_KEY=<your-api-key>

# OpenTelemetry (optional)
OTEL_ENDPOINT=https://otel.example.com
OTEL_API_KEY=<your-otel-key>
```

### Development vs Production Keys

**Development** (less strict, can be shared):

```bash
doppler secrets set DATASTORE_ENCRYPTION_KEY="dev-key-not-for-production" --config dev
```

**Production** (strict, never commit):

```bash
doppler secrets set DATASTORE_ENCRYPTION_KEY="$(openssl rand -base64 32)" --config prd
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

### Coverage in CI/CD

Coverage is automatically run on every push to `main`. View reports:

- GitHub Actions: Check workflow artifacts
- Codecov: <https://codecov.io/gh/your-org/hht_diary>

## 📚 Development

### Project Structure

```
lib/
├── src/
│   ├── core/
│   │   ├── config/          # Configuration
│   │   ├── errors/          # Exceptions
│   ├── infrastructure/
│   │   ├── database/        # SQLite + SQLCipher
│   │   ├── repositories/    # Event repository
│   │   └── sync/            # Sync engine
│   └── application/
│       ├── commands/        # Business commands
│       ├── queries/         # Query services
│       └── viewmodels/      # View models
└── append_only_datastore.dart
```

### Running Tests Locally

```bash
# Install dependencies
flutter pub get

# Run tests
./tool/test.sh

# Run with coverage
./tool/coverage.sh
```

### CI/CD Workflows

- **CI**: `.github/workflows/append_only_datastore-ci.yml`
  - Triggers: Push/PR to main or develop
  - Runs: Format check, analyze, tests on stable and beta
  
- **Coverage**: `.github/workflows/append_only_datastore-coverage.yml`
  - Triggers: Push to main
  - Runs: Coverage report, uploads to Codecov

## 📖 Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture decisions (APPROVED)
- [PLAN.md](PLAN.md) - Implementation plan
- [docs/ADR-001-di-pattern.md](docs/ADR-001-di-pattern.md) - Dependency injection pattern
- [docs/ARCHITECTURE_UPDATES.md](docs/ARCHITECTURE_UPDATES.md) - Recent changes

## 🔒 Security

### FDA 21 CFR Part 11 Compliance

This datastore implements:

- **§11.10(e)**: Immutable audit trail (database triggers)
- **§11.10(c)**: Sequence of operations (sequence numbers)
- **§11.50**: Signature manifestations (cryptographic signatures)
- **§11.10(a)**: Validation (comprehensive testing)

### Encryption Details

- **Algorithm**: AES-256 via SQLCipher
- **Key Storage**: Doppler (never in code or config files)
- **Key Rotation**: Manual via Doppler (recommended: quarterly)
- **Backup**: Encrypted backups only

### Security Best Practices

1. ✅ **Never commit encryption keys** to version control
2. ✅ **Use Doppler** for all secrets management
3. ✅ **Rotate keys regularly** (quarterly recommended)
4. ✅ **Different keys** for dev/staging/production
5. ✅ **Audit key access** via Doppler logs

## 🚀 Phase 1 MVP Status

- ✅ Configuration and DI setup
- ✅ Exception handling
- ✅ Testing infrastructure
- ✅ CI/CD pipelines
- ⏳ Database layer (Days 4-5)
- ⏳ Event storage (Days 6-7)
- ⏳ Offline queue (Days 8-9)
- ⏳ Conflict detection (Days 10-11)
- ⏳ Query service (Days 12-13)
- ⏳ Sync engine (Days 14-15)

## 📝 License

See repository root LICENSE file.

## 🤝 Contributing

This is FDA-regulated medical software. All contributions must:

- Pass all tests
- Maintain 90%+ code coverage
- Follow strict linting rules
- Include comprehensive documentation
- Be reviewed by at least one other developer

---

**Remember**: This is production medical software. No shortcuts. Every line matters. 🏥
