# Architecture Decisions for Append-Only Datastore

**Version**: 1.0.0  
**Status**: DRAFT - Pending Review  
**Last Updated**: 2025-01-24

## Executive Summary

This document presents the architectural choices for implementing an FDA 21 CFR Part 11 compliant, offline-first event sourcing module for clinical trial data capture. Each option is evaluated against our critical requirements: compliance, offline capability, performance, and maintainability.

## Critical Requirements Recap

1. **FDA 21 CFR Part 11 Compliance**: Immutable audit trail, user attribution, tamper detection
2. **Offline-First**: Full functionality without connectivity, automatic synchronization
3. **Multi-Device Support**: Conflict resolution for concurrent edits
4. **Performance**: <10ms event creation, 10,000+ event capacity
5. **Security**: Encryption at rest, secure key management
6. **Observability**: Integration with Dartastic OpenTelemetry

## 🗄️ Storage Layer Options

### Option 1: SQLite with SQLCipher (RECOMMENDED)

**Implementation**: `sqflite` + `sqflite_sqlcipher`

**Pros:**
- ✅ **Mature & Battle-tested**: Used in millions of production apps
- ✅ **FDA Compliance Ready**: Supports triggers for audit trails, immutable tables via constraints
- ✅ **Encryption**: SQLCipher provides transparent AES-256 encryption
- ✅ **SQL Power**: Complex queries, indexes, views for projections
- ✅ **Schema Management**: Built-in migration support via versioning
- ✅ **Cross-platform**: Works on iOS, Android, Desktop, Web (via sqlite_wasm)
- ✅ **Conflict Resolution**: UPSERT and ON CONFLICT clauses
- ✅ **Observability**: Can intercept all SQL for telemetry

**Cons:**
- ❌ SQL complexity for nested JSON structures
- ❌ Requires SQL knowledge for maintenance
- ❌ SQLCipher adds ~7MB to app size

**Compliance Features:**
```sql
-- Immutable event table with audit fields
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id TEXT UNIQUE NOT NULL,
  aggregate_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_version INTEGER NOT NULL,
  payload TEXT NOT NULL, -- JSON
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  signature TEXT NOT NULL,
  sequence_number INTEGER NOT NULL,
  CHECK (json_valid(payload))
);

-- Prevent updates/deletes via trigger
CREATE TRIGGER prevent_event_modification
BEFORE UPDATE OR DELETE ON events
BEGIN
  SELECT RAISE(FAIL, 'Events are immutable');
END;
```

### Option 2: Isar Database

**Implementation**: `isar` package

**Pros:**
- ✅ **NoSQL Simplicity**: Object database, no SQL required
- ✅ **Fast**: Memory-mapped, very fast reads
- ✅ **Built-in Encryption**: AES-256 encryption support
- ✅ **Schema Generation**: Compile-time code generation
- ✅ **Type Safety**: Strongly typed queries

**Cons:**
- ❌ **Immutability Challenges**: No built-in way to prevent updates
- ❌ **Limited Query Power**: No complex joins or SQL features
- ❌ **Newer/Less Proven**: Fewer production deployments
- ❌ **Web Support**: Limited web platform support
- ❌ **Migration Complexity**: Schema changes require careful handling

**Compliance Risk:**
- Harder to guarantee immutability without database-level constraints
- Would need application-level enforcement (less reliable)

### Option 3: Hive Database

**Implementation**: `hive` package

**Pros:**
- ✅ **Simple API**: Key-value store, easy to use
- ✅ **Pure Dart**: No native dependencies
- ✅ **Fast**: In-memory with disk persistence
- ✅ **Lightweight**: Small footprint

**Cons:**
- ❌ **No Built-in Encryption**: Requires hive_cipher adapter
- ❌ **No Query Language**: Manual filtering/sorting
- ❌ **No Transactions**: Risk of partial writes
- ❌ **No Immutability**: Can't prevent modifications
- ❌ **Limited Indexing**: Performance issues with large datasets

**Verdict**: Not suitable for FDA compliance requirements

### Option 4: ObjectBox

**Implementation**: `objectbox` package

**Pros:**
- ✅ **High Performance**: Very fast, especially for writes
- ✅ **ACID Transactions**: Data integrity
- ✅ **Sync Support**: Built-in synchronization (ObjectBox Sync)
- ✅ **Relations**: Support for object relations

**Cons:**
- ❌ **Commercial License**: Requires paid license for production
- ❌ **Large Binary Size**: Adds significant size to app
- ❌ **Limited Immutability**: No database-level constraints
- ❌ **Platform Limitations**: Some platforms not supported

### Option 5: Custom File-Based Storage

**Implementation**: Direct file I/O with JSON/Protobuf

**Pros:**
- ✅ **Full Control**: Complete control over format and behavior
- ✅ **Minimal Dependencies**: No external packages
- ✅ **Format Flexibility**: Can use JSON, Protobuf, MessagePack

**Cons:**
- ❌ **High Development Cost**: Must implement everything
- ❌ **No Query Engine**: Must build indexing and queries
- ❌ **Reliability Risk**: Must handle corruption, atomic writes
- ❌ **Performance**: Likely slower than optimized databases

## 🔄 Synchronization Architecture Options

### Option 1: Event-Based Sync with REST API (RECOMMENDED)

**Architecture:**
```
Client Queue → Batch Upload → Server Event Log → Acknowledgments
```

**Pros:**
- ✅ Simple and reliable
- ✅ Idempotent operations
- ✅ Easy to debug and monitor
- ✅ Works with any backend

**Implementation:**
```dart
class SyncEngine {
  Future<void> sync() async {
    final pending = await queue.getPendingEvents();
    final batch = pending.take(100); // Batch size
    
    final response = await api.submitEvents(batch);
    await queue.markSynced(response.acknowledgedIds);
    
    // Handle conflicts
    for (final conflict in response.conflicts) {
      await conflictResolver.resolve(conflict);
    }
  }
}
```

### Option 2: WebSocket-Based Real-time Sync

**Pros:**
- ✅ Real-time updates
- ✅ Bidirectional communication
- ✅ Lower latency

**Cons:**
- ❌ Connection management complexity
- ❌ Requires persistent connections
- ❌ Battery drain on mobile

### Option 3: GraphQL Subscriptions

**Pros:**
- ✅ Efficient data fetching
- ✅ Real-time capabilities
- ✅ Type safety

**Cons:**
- ❌ Additional complexity
- ❌ Requires GraphQL backend
- ❌ Larger client library

## 🔐 Encryption Strategy Options

### Option 1: Database-Level Encryption (RECOMMENDED)

**SQLCipher Implementation:**
```dart
final db = await openDatabase(
  path,
  password: encryptionKey,
  singleInstance: true,
);
```

**Pros:**
- ✅ Transparent to application
- ✅ Proven security
- ✅ No performance overhead for queries

### Option 2: Application-Level Field Encryption

**Pros:**
- ✅ Selective encryption
- ✅ Works with any storage

**Cons:**
- ❌ Can't query encrypted fields
- ❌ Complex key management
- ❌ Performance overhead

### Option 3: File System Encryption

**Pros:**
- ✅ OS-level security
- ✅ No app changes needed

**Cons:**
- ❌ Not all platforms support
- ❌ User must enable
- ❌ Not sufficient for FDA compliance alone

## 🔍 Conflict Resolution Options

### Option 1: Version Vectors (RECOMMENDED)

**Implementation:**
```dart
class VersionVector {
  final Map<String, int> versions; // deviceId -> version
  
  bool hasConflict(VersionVector other) {
    // Detect concurrent edits
  }
  
  VersionVector merge(VersionVector other) {
    // Combine vectors
  }
}
```

**Pros:**
- ✅ Detects all conflicts accurately
- ✅ Supports multiple devices
- ✅ No false positives

### Option 2: Last-Write-Wins (LWW)

**Pros:**
- ✅ Simple implementation
- ✅ No user intervention

**Cons:**
- ❌ Data loss possible
- ❌ Not suitable for clinical data

### Option 3: Operational Transformation (OT)

**Pros:**
- ✅ Automatic merging
- ✅ Preserves intent

**Cons:**
- ❌ Complex implementation
- ❌ Domain-specific transforms needed

## 📊 Schema Evolution Options

### Option 1: Versioned Events with Upcasting (RECOMMENDED)

```dart
abstract class Event {
  int get schemaVersion;
  
  Map<String, dynamic> toJson();
  
  static Event fromJson(Map<String, dynamic> json) {
    final version = json['schema_version'];
    final type = json['event_type'];
    
    // Upcast old versions
    if (version < currentVersion) {
      json = EventMigrator.migrate(json, version, currentVersion);
    }
    
    return EventFactory.create(type, json);
  }
}
```

**Pros:**
- ✅ Backward compatibility
- ✅ Gradual migration
- ✅ Audit trail preserved

### Option 2: Database Migrations

**Pros:**
- ✅ Standard approach
- ✅ Tool support

**Cons:**
- ❌ Can't modify events (immutable)
- ❌ Complex for event sourcing

## 🎯 Recommended Architecture

Based on evaluation, the recommended architecture is:

### Storage Layer
**SQLite with SQLCipher** for:
- Proven reliability in production
- FDA compliance features (triggers, constraints)
- Built-in encryption
- Rich query capabilities
- Cross-platform support

### Sync Strategy
**Event-based REST API** for:
- Simplicity and reliability
- Easy debugging and monitoring
- Idempotent operations
- Backend flexibility

### Encryption
**Database-level (SQLCipher)** for:
- Transparent operation
- Proven security
- Optimal performance

### Conflict Resolution
**Version Vectors** for:
- Accurate conflict detection
- Multi-device support
- Audit trail preservation

### Schema Evolution
**Versioned Events with Upcasting** for:
- Backward compatibility
- Immutable event preservation
- Gradual migration support

## 📋 Decision Matrix

| Requirement | SQLite+SQLCipher | Isar | Hive | ObjectBox | Custom |
|------------|-----------------|------|------|-----------|--------|
| FDA Compliance | ✅✅✅ | ✅ | ❌ | ✅ | ❓ |
| Offline-First | ✅✅✅ | ✅✅✅ | ✅✅ | ✅✅✅ | ✅✅ |
| Performance | ✅✅ | ✅✅✅ | ✅✅ | ✅✅✅ | ✅ |
| Encryption | ✅✅✅ | ✅✅ | ✅ | ✅✅ | ❓ |
| Query Power | ✅✅✅ | ✅ | ❌ | ✅✅ | ❌ |
| Maturity | ✅✅✅ | ✅ | ✅✅ | ✅✅ | ❌ |
| Maintenance | ✅✅ | ✅✅ | ✅✅✅ | ✅ | ❌ |
| App Size Impact | ✅✅ | ✅✅✅ | ✅✅✅ | ✅ | ✅✅✅ |

## 🚦 Implementation Priorities

### Phase 1 - MVP
1. SQLite with basic schema
2. Local event storage
3. Manual sync trigger
4. Basic conflict detection

### Phase 2 - Production
1. SQLCipher encryption
2. Automatic sync
3. Version vector conflicts
4. OpenTelemetry integration

### Phase 3 - Enterprise
1. Real-time subscriptions
2. Advanced conflict resolution
3. Multi-tenant support
4. Analytics integration

## ⚠️ Risk Mitigations

### Risk: SQLCipher License
**Mitigation**: Use community edition (free) or budget for commercial license

### Risk: SQL Complexity
**Mitigation**: 
- Abstract SQL behind repository pattern
- Provide query builder DSL
- Comprehensive documentation

### Risk: Migration Errors
**Mitigation**:
- Extensive migration testing
- Rollback capabilities
- Gradual rollout support

### Risk: Sync Conflicts
**Mitigation**:
- Conservative conflict detection
- User notifications
- Manual resolution UI

## 📝 Open Questions for Review

1. **Sync Frequency**: How often should automatic sync occur? Battery vs data freshness tradeoff.

2. **Conflict UI**: Should conflicts be resolved automatically where possible or always require user input for clinical data?

3. **Data Retention**: How long should events be kept locally? Storage vs history tradeoff.

4. **Telemetry Detail**: What level of operation tracing is acceptable? Privacy vs observability tradeoff.

5. **Migration Strategy**: Should we support rolling back schema changes? Safety vs complexity tradeoff.

## 🎓 Alternative Patterns Considered

### Event Store Alternatives

We evaluated these specialized event sourcing libraries:

1. **EventStore Client**: Requires EventStoreDB server (not PostgreSQL)
2. **Harvest**: Last updated 2019, appears abandoned
3. **CQRS Package**: Too lightweight, missing offline support

None met our specific requirements for offline-first, FDA compliance, and PostgreSQL backend.

### Hybrid Approach

We considered using:
- Isar for fast local storage
- SQLite for audit trail only
- Separate sync queue

Rejected due to:
- Complexity of maintaining consistency
- Doubled storage requirements
- Difficult debugging

## ✅ Recommendation Summary

**GO WITH**: SQLite + SQLCipher for the storage layer, implementing:

1. **Immutable event table** with trigger-enforced append-only behavior
2. **Materialized views** for efficient current state queries  
3. **Version vectors** for conflict detection
4. **REST API** for synchronization
5. **SQLCipher** for transparent encryption

This architecture provides the best balance of:
- ✅ FDA compliance capabilities
- ✅ Production reliability
- ✅ Developer experience
- ✅ Performance characteristics
- ✅ Cross-platform support

**Next Step**: Await architecture approval, then proceed with Phase 1 MVP implementation following the plan in PLAN.md.
