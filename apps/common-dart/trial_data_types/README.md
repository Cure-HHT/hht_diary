# Trial Data Types

Shared domain models for clinical trial applications. Pure Dart package with no Flutter dependencies.

## Features

- ✅ Domain entities (Participant, Trial, Clinical Site)
- ✅ Event definitions (base classes and domain events)
- ✅ Value objects (Email, Phone Number, Identifiers)
- ✅ Shared between client and server
- ✅ Type-safe serialization
- ✅ Comprehensive validation

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  trial_data_types:
    path: ../common-dart/trial_data_types
```

### Basic Usage

```dart
import 'package:trial_data_types/trial_data_types.dart';

// TODO: Will be implemented in Phase 1 Day 3
// Create domain entities
// final participant = Participant(
//   id: 'participant-123',
//   email: Email('patient@example.com'),
//   phone: PhoneNumber('+1-555-0123'),
// );

// Create domain events
// final event = ParticipantEnrolledEvent(
//   participantId: participant.id,
//   trialId: 'trial-456',
//   timestamp: DateTime.now(),
// );
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
- Codecov: https://codecov.io/gh/your-org/hht_diary

## 📚 Development

### Project Structure

```
lib/
├── src/
│   ├── entities/         # Domain entities
│   │   ├── participant.dart
│   │   ├── trial.dart
│   │   └── clinical_site.dart
│   ├── events/           # Event definitions
│   │   ├── event_base.dart
│   │   ├── participant_events.dart
│   │   └── nosebleed_events.dart
│   └── value_objects/    # Value objects
│       ├── email.dart
│       ├── phone_number.dart
│       └── identifier.dart
└── trial_data_types.dart
```

### Design Principles

1. **Pure Dart** - No Flutter dependencies
2. **Immutable** - All models are immutable
3. **Validated** - Value objects enforce validation
4. **Serializable** - JSON serialization built-in
5. **Shared** - Used by both client and server

### Running Tests Locally

```bash
# Install dependencies
dart pub get

# Run tests
./tool/test.sh

# Run with coverage
./tool/coverage.sh
```

### CI/CD Workflows

- **CI**: `.github/workflows/trial_data_types-ci.yml`
  - Triggers: Push/PR to main or develop
  - Runs: Format check, analyze, tests on stable and beta
  
- **Coverage**: `.github/workflows/trial_data_types-coverage.yml`
  - Triggers: Push to main
  - Runs: Coverage report, uploads to Codecov

## 🏗️ Architecture

This package is the **domain layer** in our three-layer architecture:

```
┌─────────────────────────────────┐
│   trial_data_types (Domain)    │  ← This package
│   - Entities                    │
│   - Events                      │
│   - Value Objects               │
└─────────────────────────────────┘
           ↓ depends on
┌─────────────────────────────────┐
│ append_only_datastore (Storage) │
│   - SQLite + Encryption         │
│   - Repositories                │
│   - Sync Engine                 │
└─────────────────────────────────┘
           ↓ depends on
┌─────────────────────────────────┐
│   clinical_diary (App)          │
│   - UI Screens                  │
│   - Widgets                     │
└─────────────────────────────────┘
```

### Used By

- **Client**: Flutter applications (clinical_diary)
- **Server**: Supabase Edge Functions (Dart)
- **Database**: PostgreSQL table definitions

### Basis for PostgreSQL Tables

Domain events in this package map directly to PostgreSQL tables:

```dart
// Dart event
class ParticipantEnrolledEvent {
  final String participantId;
  final String trialId;
  final DateTime timestamp;
}

// PostgreSQL table
CREATE TABLE events (
  event_id UUID,
  event_type TEXT, -- 'ParticipantEnrolledEvent'
  payload JSONB,   -- { participantId, trialId, timestamp }
  ...
);
```

## 🚀 Phase 1 Status

- ✅ Project structure created
- ✅ Testing infrastructure
- ✅ CI/CD pipelines
- ⏳ Event base class (Day 3)
- ⏳ Domain entities (Day 3)
- ⏳ Value objects (Day 3)
- ⏳ Participant events (Day 3)
- ⏳ Nosebleed events (Day 3)

## 📝 TDD Workflow

This package follows strict TDD:

1. **Write test first**
2. **Confirm test fails (Red)**
3. **Implement code**
4. **Test passes (Green)**
5. **Refactor**

Example:
```bash
# Day 3: Event base class
cd test/src/events
vim event_base_test.dart  # Write failing test
./tool/test.sh            # Confirm RED
cd lib/src/events
vim event_base.dart       # Implement
./tool/test.sh            # Confirm GREEN
```

## 📖 Documentation

See parent project documentation:
- [../../append_only_datastore/ARCHITECTURE.md](../../append_only_datastore/ARCHITECTURE.md)
- [../../append_only_datastore/PLAN.md](../../append_only_datastore/PLAN.md)

## 🤝 Contributing

This is FDA-regulated medical software. All contributions must:
- Pass all tests
- Maintain 90%+ code coverage
- Follow strict linting rules
- Include comprehensive documentation
- Be reviewed by at least one other developer

---

**Remember**: These are shared domain models used across client and server. Changes impact the entire system. 🏥
