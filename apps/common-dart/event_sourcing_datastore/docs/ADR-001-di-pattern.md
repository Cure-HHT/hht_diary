# Architecture Decision: Static Singleton vs DI Container

**Date**: 2025-11-23  
**Decision**: Use Static Singleton Pattern (NOT get_it)  
**Status**: APPROVED

## The Question

Should we use a DI container like get_it, or just use a static singleton with factory pattern?

## Decision: Static Singleton Pattern

**We're removing get_it** and using a simple static singleton instead.

## Reasoning

### For Medical Software

1. **Explicit > Magical**
   - Static instances are obvious and traceable
   - No "magic" container resolving dependencies
   - FDA validation is easier with explicit code

2. **Simple Scope**
   - We have ~6 services total, not 50+
   - Dependencies are straightforward (no complex graphs)
   - Manual wiring is not burdensome

3. **Zero Dependencies**
   - One less external dependency to vet and maintain
   - Pure Dart solution
   - No breaking changes from library updates

4. **Easy Debugging**
   - Stack traces are clearer
   - No indirection through DI container
   - Breakpoints work naturally

5. **Testing Still Easy**
   - Can reset state between tests
   - Can pass test config
   - Can mock services if needed

### Implementation

```dart
class Datastore {
  static Datastore? _instance;
  
  static Datastore get instance {
    if (_instance == null) {
      throw StateError('Not initialized');
    }
    return _instance!;
  }
  
  static Future<Datastore> initialize({
    required DatastoreConfig config,
  }) async {
    _instance = Datastore._(config);
    await _instance!._database.initialize();
    return _instance!;
  }
  
  final EventRepository repository;
  final SyncService syncService;
  final QueryService queryService;
  
  // Reactive signals for UI
  final Signal<SyncStatus> syncStatus;
  final Signal<int> queueDepth;
  
  Datastore._(DatastoreConfig config)
      : repository = SQLiteEventRepository(config),
        syncService = SyncService(config),
        syncStatus = signal(SyncStatus.idle),
        queueDepth = signal(0);
}
```

### Usage

```dart
// In main.dart
await Datastore.initialize(
  config: DatastoreConfig.production(
    deviceId: await getDeviceId(),
    userId: currentUser.id,
    syncServerUrl: 'https://api.example.com',
    encryptionKey: await getSecureKey(),
  ),
);

// In services
await Datastore.instance.repository.append(event);

// In UI
Watch((context) {
  final status = Datastore.instance.syncStatus.value;
  return Text(status.message);
});
```

### When Would get_it Make Sense?

get_it (or another DI container) would make sense if:

1. **Large app** - 20+ services with complex dependency graphs
2. **Multiple scopes** - Need different instances for different users/sessions
3. **Plugin architecture** - Services registered dynamically at runtime
4. **Team preference** - Team strongly prefers DI containers

## Alternatives Considered

### 1. get_it (Rejected)

- **Pro**: Popular, well-tested, async support
- **Con**: External dependency, "magic" resolution, overkill for our scope
- **Verdict**: ❌ Too much for what we need

### 2. Injectable (Rejected)

- **Pro**: Compile-time DI, type-safe
- **Con**: Requires code generation, complex setup
- **Verdict**: ❌ Way too much complexity

### 3. Manual Constructor Injection (Considered)

- **Pro**: Most explicit, zero dependencies
- **Con**: Wiring boilerplate in app layer
- **Verdict**: ⚠️ Good alternative, but singleton is cleaner

### 4. Static Singleton (APPROVED) ✅

- **Pro**: Simple, explicit, zero dependencies, testable
- **Con**: Global state (but scoped to module)
- **Verdict**: ✅ **Best fit for our use case**

## Migration from get_it

Already completed:

- ✅ Removed `get_it` dependency
- ✅ Created `Datastore` singleton class
- ✅ Updated all documentation
- ✅ Updated pubspec.yaml (kept Signals)

## Summary

For FDA-regulated medical software with a focused scope, **explicit is better than clever**. A static singleton provides all the benefits we need without the complexity of a DI container.

---

**Decision approved by**: Mike Bushe  
**Implementation**: Phase 1 Day 1 (Complete)
