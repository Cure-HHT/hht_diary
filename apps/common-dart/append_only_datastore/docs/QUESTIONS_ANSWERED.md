# Your Questions - Answered & Implemented ✅

**Date**: 2025-11-23

## Q1: What alternatives to get_it? Why use DI at all?

### Answer: You're Right - We Don't Need get_it!

**Decision**: ✅ **Using Static Singleton Pattern** (no DI container)

### Why?

```dart
// Simple, explicit, zero magic
class Datastore {
  static Datastore? _instance;
  static Datastore get instance => _instance!;
  
  static Future<Datastore> initialize({
    required DatastoreConfig config,
  }) async {
    _instance = Datastore._(config);
    return _instance!;
  }
  
  final EventRepository repository;
  final SyncService syncService;
  final Signal<SyncStatus> syncStatus; // Still using Signals!
  
  Datastore._(DatastoreConfig config) { /* ... */ }
}
```

### Benefits for Medical Software

1. ✅ **Explicit** - No "magic" resolution
2. ✅ **Simple** - Zero dependencies (except Signals)
3. ✅ **Debuggable** - Clear stack traces
4. ✅ **FDA-friendly** - Easy to validate and audit
5. ✅ **Small scope** - We have 6 services, not 50+

### Alternatives Considered

| Option | Verdict | Why |
|--------|---------|-----|
| get_it | ❌ Rejected | Overkill for our scope |
| Injectable | ❌ Rejected | Requires code generation |
| Manual DI | ⚠️ Considered | Too much wiring in app |
| **Static Singleton** | ✅ **APPROVED** | Simple, explicit, sufficient |

**Full rationale**: See `docs/ADR-001-di-pattern.md`

---

## Q2: Did we create analysis_options.yaml?

### Answer: ✅ YES - All Three Projects!

**Status**: COMPLETE

- [x] trial_data_types/analysis_options.yaml ✅
- [x] append_only_datastore/analysis_options.yaml ✅
- [x] clinical_diary/analysis_options.yaml ✅

**Features:**
- `strict-casts`, `strict-inference`, `strict-raw-types` enabled
- Warnings treated as errors
- 80+ linting rules for production medical software

**Updated**: PLAN.md now shows these as complete.

---

## Q3: Where Should Commands/Queries/ViewModels Live?

### Answer: You're Absolutely Right - In the Package!

### Old (Wrong) Structure ❌

```
clinical_diary/
  └── application/
      ├── commands/      ❌ Too app-specific
      ├── queries/       ❌ Too app-specific
      └── viewmodels/    ❌ Too app-specific
```

### New (Correct) Structure ✅

```
append_only_datastore/              # REUSABLE
  └── application/
      ├── commands/                  ✅ RecordEventCommand
      ├── queries/                   ✅ GetEventsQuery
      ├── viewmodels/                ✅ EventViewModel
      └── services/                  ✅ QueryService

clinical_diary/                     # PRESENTATION ONLY
  └── presentation/
      ├── screens/                   ✅ NosebleedEntryScreen
      └── widgets/                   ✅ NosebleedListItem
```

### Rationale

**In Package (append_only_datastore):**
- `RecordEventCommand` - Generic event recording (reusable)
- `GetEventsQuery` - Generic event querying (reusable)  
- `EventViewModel` - Generic event state management (reusable)
- `QueryService` - Generic query service (reusable)

**In App (clinical_diary):**
- `NosebleedEntryScreen` - UI for nosebleed entry
- `NosebleedListItem` - UI widget for list items
- Just presentation, no business logic

### Example

```dart
// In append_only_datastore (reusable)
class RecordEventCommand {
  Future<void> execute(Event event) async {
    await Datastore.instance.repository.append(event);
  }
}

// In clinical_diary (presentation only)
class NosebleedEntryScreen extends StatelessWidget {
  final _command = RecordEventCommand();
  
  void _onSubmit() async {
    await _command.execute(NosebleedEvent(...));
  }
}
```

**Updated**: PLAN.md section 12 moved to package.  
**Updated**: Folder structures reflect new organization.

---

## Q4: Pull Up Dev Environment Setup?

### Answer: ✅ DONE - Moved to Phase 1 Day 1-2

**Old Plan**: Development environment setup in Phase 2 ❌

**New Plan**: Development environment setup in Phase 1 Days 1-2 ✅

### Phase 1 Day 1-2 Now Includes:
- [x] Project setup (folders, linting, DI)
- [ ] **Development environment validation** (NEW)
- [ ] **Basic CI/CD pipeline** (NEW)

**Rationale**: Catch environment issues early, not after 3 weeks of development.

---

## Q5: Encrypt From Day One?

### Answer: ✅ ABSOLUTELY - SQLCipher Enabled by Default

### Old Code ❌

```dart
/// Enable SQLCipher encryption.
/// WARNING: Must be false for Phase 1 MVP.  // ❌ BAD!
final bool enableEncryption;

const DatastoreConfig({
  this.enableEncryption = false,  // ❌ NO!
  // ...
});
```

### New Code ✅

```dart
/// Enable SQLCipher encryption.
/// Recommended: true for production medical software.  // ✅ GOOD!
final bool enableEncryption;

const DatastoreConfig({
  this.enableEncryption = true,  // ✅ YES!
  // ...
});
```

### Implementation

**Phase 1 Days 4-5 Now Includes:**
- SQLCipher setup and configuration
- Encryption key management
- Secure key storage integration

**Usage:**
```dart
await Datastore.initialize(
  config: DatastoreConfig.production(
    deviceId: await getDeviceId(),
    userId: currentUser.id,
    syncServerUrl: 'https://api.example.com',
    encryptionKey: await getSecureKey(), // Required!
  ),
);
```

**Rationale**: Medical software should be encrypted by default. No reason to defer security.

---

## Summary of All Changes ✅

### 1. Dependency Injection
- ❌ Removed: get_it dependency
- ✅ Added: Static Datastore singleton
- ✅ Kept: Signals for reactivity
- 📄 Documented: ADR-001-di-pattern.md

### 2. Linting
- ✅ All three projects configured
- ✅ Strict mode enabled
- ✅ PLAN.md updated

### 3. Architecture
- ✅ Commands/queries/viewmodels → package
- ✅ App → presentation only
- ✅ Folder structures updated
- 📄 Documented: ARCHITECTURE_UPDATES.md

### 4. Development Process
- ✅ Dev environment validation → Phase 1
- ✅ CI/CD pipeline → Phase 1
- ✅ Earlier validation

### 5. Security
- ✅ SQLCipher enabled by default
- ✅ Encryption in Phase 1 (not Phase 2)
- ✅ DatastoreConfig updated
- ✅ pubspec.yaml includes sqflite_sqlcipher

## Files Created/Updated

### Created
- ✅ `lib/src/core/di/datastore.dart` - Static singleton
- ✅ `docs/ADR-001-di-pattern.md` - DI decision
- ✅ `docs/ARCHITECTURE_UPDATES.md` - All changes
- ✅ `docs/QUESTIONS_ANSWERED.md` - This file

### Updated
- ✅ `lib/src/core/config/datastore_config.dart` - Encryption default
- ✅ `lib/append_only_datastore.dart` - Updated examples
- ✅ `pubspec.yaml` - Added signals, sqflite_sqlcipher
- ✅ `analysis_options.yaml` - All three projects

### Deleted
- ✅ `lib/src/core/di/service_locator.dart` - Replaced by Datastore

---

## Ready to Code! 🚀

**Next Steps:**
1. Validate dev environment
2. Set up basic CI/CD
3. Start Phase 1 Day 3: Domain models (TDD)

**All your concerns addressed and implemented!** ✅
