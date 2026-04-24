# Event Sourcing Datastore

FDA 21 CFR Part 11 compliant, offline-first event sourcing for Flutter applications.

## Features

- ✅ **Cross-platform storage** using Sembast (iOS, Android, macOS, Windows, Linux, Web)
- ✅ **Append-only event storage** with cryptographic hash chain
- ✅ Offline queue with automatic synchronization
- ✅ Conflict detection using version vectors
- ✅ Immutable audit trail for FDA compliance
- ✅ OpenTelemetry integration
- ✅ Reactive state with Signals

## Platform Support

| Platform  | Storage Backend         |
|-----------|-------------------------|
| iOS       | sembast_io (file)       |
| Android   | sembast_io (file)       |
| macOS     | sembast_io (file)       |
| Windows   | sembast_io (file)       |
| Linux     | sembast_io (file)       |
| **Web**   | sembast_web (IndexedDB) |

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  event_sourcing_datastore:
    path: ../common-dart/event_sourcing_datastore
```

### Basic Usage

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

// Initialize the datastore
await Datastore.initialize(
  config: DatastoreConfig.development(
    deviceId: 'device-123',
    userId: 'user-456',
  ),
);

// Append an event (immutable once written)
final event = await Datastore.instance.repository.append(
  aggregateId: 'diary-entry-123',
  eventType: 'NosebleedRecorded',
  data: {'severity': 'mild', 'duration': 10},
  userId: 'user-456',
  deviceId: 'device-789',
);

// Query all events
final events = await Datastore.instance.repository.getAllEvents();

// Get events for a specific aggregate
final diaryEvents = await Datastore.instance.repository
    .getEventsForAggregate('diary-entry-123');

// Get unsynced events (for sync to server)
final unsynced = await Datastore.instance.repository.getUnsyncedEvents();

// Mark events as synced after successful server upload
await Datastore.instance.repository.markEventsSynced(
  unsynced.map((e) => e.eventId).toList(),
);

// Verify data integrity (checks hash chain)
final isValid = await Datastore.instance.repository.verifyIntegrity();
```

### Production Configuration

```dart
await Datastore.initialize(
  config: DatastoreConfig.production(
    deviceId: await getDeviceId(),
    userId: currentUser.id,
    syncServerUrl: 'https://api.example.com',
  ),
);
```

### Reactive UI with Signals

```dart
// Watch queue depth in your UI
Watch((context) {
  final depth = Datastore.instance.queueDepth.value;
  return Text('$depth events pending sync');
});

// Watch sync status
Watch((context) {
  final status = Datastore.instance.syncStatus.value;
  return Text(status.message); // "Ready to sync", "Syncing...", etc.
});
```

## 🔐 Data Security

### Storage Security

Sembast stores data as JSON files (native) or in IndexedDB (web). For sensitive medical data:

- **Native platforms**: Data is stored in the app's private documents directory, protected by OS-level sandboxing
- **Web**: Data is stored in IndexedDB, tied to the origin (domain) and protected by browser security policies

### Tamper Detection

Every event includes:

- **SHA-256 hash**: Computed from event data for integrity verification
- **Hash chain**: Each event references the previous event's hash, forming a blockchain-like structure
- **Sequence numbers**: Monotonically increasing to detect gaps or insertions

```dart
// Verify the integrity of all stored events
final isValid = await Datastore.instance.repository.verifyIntegrity();
if (!isValid) {
  // Data tampering detected!
}
```

### Environment Variables

Required secrets in Doppler:

```bash
# Sync server
SYNC_SERVER_URL=https://api.example.com
SYNC_API_KEY=<your-api-key>

# OpenTelemetry (optional)
OTEL_ENDPOINT=https://otel.example.com
OTEL_API_KEY=<your-otel-key>
```

### Future: Application-Level Encryption (TODO)

For enhanced security, application-level encryption can be added to encrypt sensitive fields before storage. This is planned for a future release.

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
│   │   ├── config/          # DatastoreConfig
│   │   ├── di/              # Datastore singleton
│   │   └── errors/          # Exceptions
│   ├── infrastructure/
│   │   ├── database/        # Sembast DatabaseProvider
│   │   ├── repositories/    # EventRepository (append-only)
│   │   └── sync/            # Sync engine (planned)
│   └── application/
│       ├── commands/        # Business commands (planned)
│       ├── queries/         # Query services (planned)
│       └── viewmodels/      # View models (planned)
└── event_sourcing_datastore.dart
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

- **CI**: `.github/workflows/event_sourcing_datastore-ci.yml`
  - Triggers: Push/PR to main or develop
  - Runs: Format check, analyze, tests on stable and beta
  
- **Coverage**: `.github/workflows/event_sourcing_datastore-coverage.yml`
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

- **§11.10(e)**: Immutable audit trail (append-only storage, no updates/deletes)
- **§11.10(c)**: Sequence of operations (monotonic sequence numbers)
- **§11.50**: Signature manifestations (SHA-256 hash chain)
- **§11.10(a)**: Validation (comprehensive testing with 30+ unit tests)

### Data Integrity Features

- **Append-only**: Events cannot be modified or deleted after creation
- **Hash chain**: Each event includes a SHA-256 hash of its data and a reference to the previous event's hash
- **Sequence numbers**: Monotonically increasing numbers detect gaps or insertions
- **Integrity verification**: `verifyIntegrity()` method validates the entire hash chain

### Security Best Practices

1. ✅ **Never commit secrets** to version control
2. ✅ **Use Doppler** for all secrets management
3. ✅ **Verify integrity** periodically using `verifyIntegrity()`
4. ✅ **Sync regularly** to ensure server-side backup
5. ✅ **Monitor sync status** using reactive signals

## 🚀 Implementation Status

- ✅ Configuration and DI setup
- ✅ Exception handling
- ✅ Testing infrastructure (30+ tests)
- ✅ CI/CD pipelines
- ✅ **Database layer** (Sembast cross-platform)
- ✅ **Event storage** (append-only with hash chain)
- ⏳ Offline queue manager
- ⏳ Conflict detection (version vectors)
- ⏳ Query service
- ⏳ Sync engine

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
