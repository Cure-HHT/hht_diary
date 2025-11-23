# Architecture Decisions for Append-Only Datastore

**Version**: 1.1.0  
**Status**: APPROVED  
**Last Updated**: 2025-11-23  
**Approved By**: Michael Bushe

## Executive Summary

This document presents the architectural choices for implementing an FDA 21 CFR Part 11 compliant, offline-first event sourcing module for clinical trial data capture. Each option is evaluated against our critical requirements: compliance, offline capability, performance, and maintainability.

This document covers both **client-side** (Flutter applications) and **server-side** (Supabase backend) architecture decisions.

## Critical Requirements Recap

### Client-Side Requirements
1. **FDA 21 CFR Part 11 Compliance**: Immutable audit trail, user attribution, tamper detection
2. **Offline-First**: Full functionality without connectivity, automatic synchronization
3. **Multi-Device Support**: Conflict resolution for concurrent edits
4. **Performance**: <10ms event creation, 10,000+ event capacity
5. **Security**: Encryption at rest, secure key management
6. **Observability**: Integration with Dartastic OpenTelemetry

### Server-Side Requirements
1. **FDA 21 CFR Part 11 Compliance**: Immutable audit trail, tamper detection, database-level constraints
2. **High Availability**: 99.9%+ uptime for clinical trial operations
3. **Scalability**: Support for hundreds of concurrent users, millions of events
4. **Multi-Tenant Support**: Isolated data per trial/organization
5. **Real-Time Capabilities**: Event subscriptions for collaborative features
6. **Backup & Recovery**: Point-in-time recovery, disaster recovery
7. **Integration with Supabase**: Leverage existing PostgreSQL infrastructure

## 🗄️ Client Storage Layer Options

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

## 🌐 Server Storage Layer Options

### Overview

The server-side event store has different requirements than the client:
- Must handle hundreds of concurrent connections
- Needs real-time event subscriptions (WebSocket/Server-Sent Events)
- Requires complex queries across millions of events
- Must support multi-tenant data isolation
- Needs enterprise-grade backup and recovery
- Must integrate with existing Supabase infrastructure

### Option 1: PostgreSQL (Native Supabase) - RECOMMENDED

**Implementation**: Direct PostgreSQL with Supabase features

**Pros:**
- ✅✅✅ **Native Supabase Integration**: Already have PostgreSQL infrastructure
- ✅✅✅ **FDA Compliance Excellence**: Row-level security, audit logging, immutable constraints
- ✅✅✅ **ACID Transactions**: Guaranteed data consistency across complex operations
- ✅✅✅ **Real-Time Subscriptions**: Supabase Realtime built on PostgreSQL replication
- ✅✅✅ **Rich Query Language**: SQL with JSONB support for flexible event payloads
- ✅✅✅ **Mature Ecosystem**: Decades of production use, extensive tooling
- ✅✅ **Scalability**: Proven to billions of rows with proper indexing
- ✅✅ **Multi-Tenancy**: Row-level security policies per tenant
- ✅✅ **Point-in-Time Recovery**: Built-in backup and restore capabilities
- ✅✅ **Advanced Features**: Triggers, materialized views, full-text search, GIS support
- ✅ **Cost Effective**: No additional infrastructure needed with Supabase
- ✅ **Developer Experience**: Supabase Studio for database management
- ✅ **Observability**: pganalyze, pg_stat_statements for performance monitoring

**Cons:**
- ⚠️ **Vertical Scaling Limits**: Eventually hits single-machine limits (addressable with read replicas)
- ⚠️ **Connection Pooling**: Requires connection pooler (PgBouncer) for high concurrency
- ❌ **Not Purpose-Built for Streams**: Requires careful schema design for high-throughput event ingestion

**FDA Compliance Implementation:**
```sql
-- Immutable events table with comprehensive audit trail
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  aggregate_id UUID NOT NULL,
  aggregate_type VARCHAR(100) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  event_version INTEGER NOT NULL,
  sequence_number BIGINT NOT NULL,
  
  -- Event payload and metadata
  payload JSONB NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Audit trail fields (FDA 21 CFR Part 11)
  user_id UUID NOT NULL,
  user_email VARCHAR(255) NOT NULL,
  device_id VARCHAR(100),
  ip_address INET,
  
  -- Timestamps (server-authoritative)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Tamper detection
  event_hash VARCHAR(64) NOT NULL,
  previous_event_hash VARCHAR(64),
  
  -- Constraints
  CONSTRAINT events_tenant_aggregate_sequence 
    UNIQUE (tenant_id, aggregate_id, sequence_number),
  
  CHECK (event_version > 0),
  CHECK (sequence_number >= 0)
);

-- Immutability enforcement - prevents UPDATE and DELETE
CREATE RULE events_immutable_update AS 
  ON UPDATE TO events 
  DO INSTEAD NOTHING;

CREATE RULE events_immutable_delete AS 
  ON DELETE TO events 
  DO INSTEAD NOTHING;

-- Alternative: Use trigger for custom error messages
CREATE FUNCTION prevent_event_modification() 
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Events are immutable per FDA 21 CFR Part 11 requirements';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER events_prevent_update
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION prevent_event_modification();

CREATE TRIGGER events_prevent_delete
  BEFORE DELETE ON events
  FOR EACH ROW EXECUTE FUNCTION prevent_event_modification();

-- Indexes for performance
CREATE INDEX idx_events_tenant_aggregate 
  ON events(tenant_id, aggregate_id, sequence_number DESC);
  
CREATE INDEX idx_events_tenant_type_created 
  ON events(tenant_id, event_type, created_at DESC);
  
CREATE INDEX idx_events_created 
  ON events(created_at DESC);

-- Materialized view for current state (updated via trigger)
CREATE MATERIALIZED VIEW participant_current_state AS
SELECT 
  tenant_id,
  aggregate_id as participant_id,
  jsonb_agg(
    payload ORDER BY sequence_number
  ) FILTER (WHERE aggregate_type = 'Participant') as state_history,
  MAX(sequence_number) as last_sequence,
  MAX(created_at) as last_updated
FROM events
WHERE aggregate_type = 'Participant'
GROUP BY tenant_id, aggregate_id;

CREATE UNIQUE INDEX ON participant_current_state(tenant_id, participant_id);

-- Trigger to refresh materialized view incrementally
CREATE FUNCTION refresh_participant_state()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY participant_current_state;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Row Level Security for multi-tenancy
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON events
  FOR ALL
  USING (tenant_id = current_setting('app.current_tenant')::UUID);
```

**Real-Time Event Subscriptions via Supabase:**
```dart
// Client-side Dart/Flutter code
final supabase = Supabase.instance.client;

// Subscribe to new events for this tenant
final subscription = supabase
  .from('events')
  .stream(primaryKey: ['id'])
  .eq('tenant_id', currentTenantId)
  .order('created_at')
  .listen((List<Map<String, dynamic>> data) {
    // Process new events
    for (final event in data) {
      handleIncomingEvent(Event.fromJson(event));
    }
  });
```

**Performance Characteristics:**
- **Write throughput**: 1,000-10,000 events/second (single instance)
- **Read latency**: <5ms for indexed queries
- **Storage**: Unlimited (PostgreSQL supports petabyte-scale)
- **Concurrent connections**: 200-500 (with PgBouncer: 10,000+)

**Scaling Strategy:**
1. **Vertical scaling**: Increase CPU/RAM for single instance (Supabase handles)
2. **Read replicas**: Add read-only replicas for query load (Supabase Pro+)
3. **Table partitioning**: Partition events by tenant_id or date range
4. **Connection pooling**: PgBouncer for connection management (Supabase includes)
5. **Caching**: Redis for hot data (materialized view results)

**Cost Analysis (Supabase):**
- **Free tier**: 500MB database, 2GB bandwidth, 50,000 monthly active users
- **Pro tier** ($25/mo): 8GB database, 50GB bandwidth, 100,000 MAU
- **Team tier** ($599/mo): 100GB database, 250GB bandwidth, read replicas
- **Enterprise**: Custom pricing for dedicated infrastructure

### Option 2: Apache Kafka

**Implementation**: Event streaming platform with consumer groups

**Pros:**
- ✅✅✅ **Purpose-Built for Events**: Designed specifically for event streaming
- ✅✅✅ **High Throughput**: Millions of events per second
- ✅✅✅ **Durability**: Append-only logs with configurable retention
- ✅✅ **Real-Time Streaming**: Native support for event consumers
- ✅✅ **Horizontal Scalability**: Add brokers to scale indefinitely
- ✅✅ **Event Replay**: Built-in support for replaying event history
- ✅ **Ecosystem**: Kafka Connect, Kafka Streams, ksqlDB
- ✅ **Decoupling**: Producers and consumers are independent

**Cons:**
- ❌❌❌ **Not a Database**: No direct querying, requires external storage for views
- ❌❌❌ **Operational Complexity**: Requires dedicated cluster management (ZooKeeper/KRaft)
- ❌❌ **Infrastructure Cost**: Separate cluster to maintain and monitor
- ❌❌ **Query Limitations**: Cannot query historical events directly (need secondary storage)
- ❌❌ **Supabase Integration**: No native integration, requires custom bridge
- ❌ **Learning Curve**: Steeper learning curve than SQL
- ❌ **Materialized Views**: Must build and maintain separately
- ❌ **FDA Compliance**: Requires additional audit infrastructure

**Architecture Pattern:**
```
Flutter App → Supabase Edge Function → Kafka Producer → Kafka Topic
                                                             ↓
                                                       Kafka Consumers
                                                             ↓
                                      ┌─────────────────────┴──────────────────┐
                                      ↓                                        ↓
                              PostgreSQL Store                        Real-Time Subscriptions
                          (Materialized Views)                        (WebSocket to clients)
```

**When Kafka Makes Sense:**
1. **Event-Driven Microservices**: Multiple independent services consuming events
2. **Data Pipeline**: Streaming to analytics, data warehouses, ML systems
3. **Extreme Scale**: >100,000 events/second sustained throughput
4. **Event Processing**: Complex event processing, stream joins, windowing

**FDA Compliance Challenges:**
- Kafka topics are NOT append-only from a database perspective (messages can expire)
- Requires secondary storage (PostgreSQL) for permanent audit trail
- Need to implement tamper detection separately
- Must ensure end-to-end delivery guarantees

**Cost Considerations:**
- **Managed Kafka** (Confluent Cloud): $1-2/hour for small clusters ($720-1,440/month)
- **AWS MSK**: $0.21/hour per broker (minimum 3 brokers = $456/month)
- **Self-Hosted**: 3x VMs + monitoring + operational overhead

**Verdict for HHT Diary:**
❌ **Not Recommended** - Operational complexity and cost outweigh benefits for clinical trial data collection. Kafka is designed for high-throughput streaming use cases with multiple consumers. Our use case (client apps → REST API → single database) doesn't require Kafka's capabilities.

### Option 3: Hybrid PostgreSQL + Kafka

**Implementation**: PostgreSQL as source of truth, Kafka for event streaming

**Architecture:**
```
Flutter App → REST API → PostgreSQL (Immutable Events)
                              ↓
                      CDC (Debezium/pg_logical)
                              ↓
                         Kafka Topic
                              ↓
              ┌────────────────┴─────────────────┐
              ↓                                  ↓
      Analytics Pipeline              Real-Time WebSocket Service
      (Snowflake, BigQuery)           (Push to Flutter clients)
```

**Pros:**
- ✅✅ **Best of Both Worlds**: PostgreSQL durability + Kafka streaming
- ✅✅ **Scalable Architecture**: Separate read and write concerns
- ✅ **FDA Compliance**: PostgreSQL provides audit trail
- ✅ **Real-Time Analytics**: Stream events to data warehouse
- ✅ **Event Replay**: Kafka for replay, PostgreSQL for queries

**Cons:**
- ❌❌❌ **Highest Complexity**: Must manage two distinct systems
- ❌❌❌ **Operational Overhead**: PostgreSQL + Kafka + CDC connector
- ❌❌ **Cost**: Both PostgreSQL and Kafka infrastructure
- ❌ **Eventual Consistency**: CDC lag between PostgreSQL and Kafka
- ❌ **Debugging**: Harder to trace issues across systems

**When This Makes Sense:**
1. **Multiple Event Consumers**: Analytics, ML, reporting systems
2. **High Read/Write Separation**: Many more reads than writes
3. **Enterprise Scale**: Large organization with dedicated platform team

**Verdict for HHT Diary:**
⚠️ **Premature Optimization** - Save for Phase 3 if analytics requirements demand it. Start with PostgreSQL + Supabase Realtime, add Kafka later if needed.

### Option 4: SQLite on Server (Not Recommended)

**Implementation**: SQLite database files on server

**Pros:**
- ✅ **Simple**: Single file database
- ✅ **No Server**: Embedded database
- ✅ **Fast**: Excellent performance for single-user scenarios

**Cons:**
- ❌❌❌ **Single Writer**: No concurrent write support
- ❌❌❌ **No Network Protocol**: Not designed for client-server
- ❌❌ **No Real-Time Subscriptions**: Cannot push updates to clients
- ❌❌ **Scaling**: Cannot scale horizontally
- ❌❌ **Backup**: File-based backup only, no point-in-time recovery
- ❌ **Multi-Tenancy**: Must manage separate files per tenant

**Verdict:**
❌ **Not Suitable** for server-side event store with concurrent clients.

### Option 5: Specialized Event Stores

**EventStoreDB, Marten (PostgreSQL), Axon Server**

**Pros:**
- ✅✅ **Purpose-Built**: Designed specifically for event sourcing
- ✅ **Event Streams**: First-class event stream support
- ✅ **Projections**: Built-in projection engines

**Cons:**
- ❌❌ **Not PostgreSQL**: Requires separate infrastructure from Supabase
- ❌❌ **Learning Curve**: Different from SQL databases
- ❌ **Ecosystem**: Smaller community than PostgreSQL
- ❌ **Integration**: No native Supabase integration

**Verdict:**
⚠️ **Possible Alternative** if PostgreSQL limitations become critical. For Phase 1, PostgreSQL provides all needed features without additional infrastructure.

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

### Client-Side Encryption

**Option 1: Database-Level Encryption (RECOMMENDED)**

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

**Option 2: Application-Level Field Encryption**

**Pros:**
- ✅ Selective encryption
- ✅ Works with any storage

**Cons:**
- ❌ Can't query encrypted fields
- ❌ Complex key management
- ❌ Performance overhead

**Option 3: File System Encryption**

**Pros:**
- ✅ OS-level security
- ✅ No app changes needed

**Cons:**
- ❌ Not all platforms support
- ❌ User must enable
- ❌ Not sufficient for FDA compliance alone

### Server-Side Encryption

**PostgreSQL Encryption at Rest (RECOMMENDED)**

Supabase provides:
- ✅ **Disk Encryption**: Encrypted block storage (AWS EBS encryption)
- ✅ **Transparent**: No performance impact
- ✅ **Key Management**: AWS KMS integration
- ✅ **Backup Encryption**: Encrypted backups

**Optional: Column-Level Encryption**

For highly sensitive fields (e.g., PHI):
```sql
-- Encrypt specific columns with pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt field on insert
INSERT INTO events (payload) 
VALUES (pgp_sym_encrypt('sensitive data', 'encryption_key'));

-- Decrypt on query
SELECT pgp_sym_decrypt(payload::bytea, 'encryption_key') 
FROM events;
```

**Cons:**
- ❌ Cannot index encrypted fields
- ❌ Performance overhead for encryption/decryption
- ❌ Key management complexity

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

Based on comprehensive evaluation, the recommended architecture is:

### Client Storage Layer
**SQLite with SQLCipher** for:
- Proven reliability in production
- FDA compliance features (triggers, constraints)
- Built-in encryption
- Rich query capabilities
- Cross-platform support

### Server Storage Layer
**PostgreSQL (Native Supabase)** for:
- Native integration with existing infrastructure
- FDA compliance excellence (ACID, audit logging, immutability)
- Real-time subscriptions via Supabase Realtime
- Mature ecosystem with extensive tooling
- Cost-effective (no additional infrastructure)
- Comprehensive backup and recovery
- Multi-tenant row-level security

### Sync Strategy
**Event-based REST API** for:
- Simplicity and reliability
- Easy debugging and monitoring
- Idempotent operations
- Backend flexibility

### Encryption
**Client**: Database-level (SQLCipher)  
**Server**: PostgreSQL disk encryption (Supabase default)  
For:
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

### Real-Time Updates
**Supabase Realtime** for:
- Native PostgreSQL integration
- Minimal operational overhead
- WebSocket-based subscriptions
- Automatic scaling

## 📋 Decision Matrix

### Client Storage
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

### Server Storage
| Requirement | PostgreSQL | Kafka | PostgreSQL+Kafka | SQLite | EventStoreDB |
|------------|------------|-------|------------------|--------|--------------|
| FDA Compliance | ✅✅✅ | ⚠️ | ✅✅✅ | ✅✅ | ✅✅ |
| Supabase Integration | ✅✅✅ | ❌ | ✅✅ | ❌❌ | ❌❌ |
| Real-Time | ✅✅✅ | ✅✅✅ | ✅✅✅ | ❌❌ | ✅✅ |
| Query Power | ✅✅✅ | ❌ | ✅✅✅ | ✅✅✅ | ✅ |
| Scalability | ✅✅ | ✅✅✅ | ✅✅✅ | ❌ | ✅✅ |
| Operational Complexity | ✅✅✅ | ❌ | ❌ | ✅✅✅ | ✅ |
| Cost (Monthly) | $25-599 | $500+ | $600+ | N/A | $200+ |
| Maturity | ✅✅✅ | ✅✅✅ | ✅✅ | ✅✅✅ | ✅✅ |
| Multi-Tenancy | ✅✅✅ | ⚠️ | ✅✅✅ | ⚠️ | ✅✅ |

## 🚦 Implementation Priorities

### Phase 1 - MVP (Client + Server)
**Client:**
1. SQLite with basic schema
2. Local event storage
3. Manual sync trigger
4. Basic conflict detection

**Server:**
1. PostgreSQL event table with immutability constraints
2. REST API for event submission
3. Basic materialized views
4. Tenant isolation (row-level security)

### Phase 2 - Production (Client + Server)
**Client:**
1. SQLCipher encryption
2. Automatic sync
3. Version vector conflicts
4. OpenTelemetry integration

**Server:**
1. Supabase Realtime subscriptions
2. Automated materialized view refresh
3. OpenTelemetry distributed tracing
4. Performance monitoring and alerts

### Phase 3 - Enterprise (Server-Focused)
**Server:**
1. Read replicas for query scaling
2. Table partitioning for large datasets
3. Advanced analytics (optional: Kafka integration)
4. Multi-region deployment
5. Disaster recovery testing

## ⚠️ Risk Mitigations

### Client Risks

**Risk: SQLCipher License**
**Mitigation**: Use community edition (free) or budget for commercial license

**Risk: SQL Complexity**
**Mitigation**: 
- Abstract SQL behind repository pattern
- Provide query builder DSL
- Comprehensive documentation

**Risk: Migration Errors**
**Mitigation**:
- Extensive migration testing
- Rollback capabilities
- Gradual rollout support

**Risk: Sync Conflicts**
**Mitigation**:
- Conservative conflict detection
- User notifications
- Manual resolution UI

### Server Risks

**Risk: PostgreSQL Connection Limits**
**Mitigation**:
- PgBouncer connection pooling (included with Supabase)
- Connection timeout monitoring
- Automatic retry logic in clients

**Risk: Database Performance Degradation**
**Mitigation**:
- Comprehensive indexing strategy
- Table partitioning by tenant_id or date
- Regular VACUUM and ANALYZE
- Query performance monitoring

**Risk: Storage Growth**
**Mitigation**:
- Data retention policies (archive old events)
- Compression for archived data
- Monitor storage growth trends
- Budget for storage scaling

**Risk: Single Point of Failure**
**Mitigation**:
- Supabase automatic backups
- Point-in-time recovery capability
- High availability configuration (Supabase Team/Enterprise)
- Regular disaster recovery testing

**Risk: Multi-Tenant Data Leakage**
**Mitigation**:
- Strict row-level security policies
- Comprehensive access testing
- Tenant isolation verification in CI/CD
- Security audits

## 📝 Open Questions for Review

1. **Sync Frequency**: How often should automatic sync occur? Battery vs data freshness tradeoff.

2. **Conflict UI**: Should conflicts be resolved automatically where possible or always require user input for clinical data?

3. **Data Retention**: How long should events be kept locally? Storage vs history tradeoff.

4. **Server Retention**: How long should events be retained on server? Compliance requirements vs storage costs.

5. **Telemetry Detail**: What level of operation tracing is acceptable? Privacy vs observability tradeoff.

6. **Migration Strategy**: Should we support rolling back schema changes? Safety vs complexity tradeoff.

7. **Real-Time Scope**: Which events need real-time push to clients vs polling?

8. **Backup Frequency**: How often should full backups run? (Supabase default: daily)

## 🎓 Alternative Patterns Considered

### Client Event Store Alternatives

We evaluated these specialized event sourcing libraries:

1. **EventStore Client**: Requires EventStoreDB server (not PostgreSQL)
2. **Harvest**: Last updated 2019, appears abandoned
3. **CQRS Package**: Too lightweight, missing offline support

None met our specific requirements for offline-first, FDA compliance, and PostgreSQL backend.

### Hybrid Approach (Client)

We considered using:
- Isar for fast local storage
- SQLite for audit trail only
- Separate sync queue

Rejected due to:
- Complexity of maintaining consistency
- Doubled storage requirements
- Difficult debugging

### Kafka for Clinical Trials

Kafka was seriously considered but ultimately rejected because:

**Why Kafka is Excellent:**
- Purpose-built for event streaming
- Extreme scalability and throughput
- Built-in event replay
- Large ecosystem

**Why Not for HHT Diary:**
1. **Operational Overhead**: Requires dedicated cluster, ZooKeeper/KRaft, monitoring
2. **Cost**: $500+ monthly for managed service vs $25+ for Supabase
3. **Use Case Mismatch**: Kafka excels at high-throughput streaming with multiple consumers. Our use case is client apps submitting events to a single PostgreSQL store.
4. **Integration Complexity**: No native Supabase integration
5. **FDA Compliance**: Kafka requires additional infrastructure for permanent audit trail

**When Kafka Would Make Sense:**
- Multiple event consumers (analytics, ML, reporting systems)
- >100,000 events/second sustained throughput
- Event-driven microservices architecture
- Real-time data pipelines to multiple destinations

**Future Consideration:**
If Phase 3 requires real-time analytics streaming to data warehouses, we can add Kafka via Change Data Capture (CDC) from PostgreSQL without refactoring the core application.

## ✅ Recommendation Summary

### Client Architecture
**GO WITH**: SQLite + SQLCipher for the storage layer, implementing:

1. **Immutable event table** with trigger-enforced append-only behavior
2. **Materialized views** for efficient current state queries  
3. **Version vectors** for conflict detection
4. **REST API** for synchronization
5. **SQLCipher** for transparent encryption

### Server Architecture
**GO WITH**: PostgreSQL (Native Supabase) for the event store, implementing:

1. **Immutable events table** with database rules and triggers
2. **Row-level security** for multi-tenant isolation
3. **Materialized views** for current state, refreshed by triggers
4. **Supabase Realtime** for event subscriptions
5. **Comprehensive indexing** for query performance
6. **Disk encryption** (Supabase default) with optional column encryption for PHI
7. **OpenTelemetry integration** for observability

**Rationale**: PostgreSQL provides ALL required capabilities:
- ✅ FDA 21 CFR Part 11 compliance (immutability, audit trail, tamper detection)
- ✅ Native Supabase integration (zero additional infrastructure)
- ✅ Real-time subscriptions (Supabase Realtime)
- ✅ ACID transactions (data integrity)
- ✅ Multi-tenant row-level security
- ✅ Cost-effective ($25-599/month vs $500+ for Kafka)
- ✅ Mature ecosystem (30+ years in production)
- ✅ Excellent query capabilities (SQL + JSONB)
- ✅ Built-in backup and recovery

**Kafka Considered but Rejected**: While Kafka is an excellent event streaming platform, it adds operational complexity and cost without providing essential capabilities that PostgreSQL already delivers. Kafka's strengths (extreme throughput, multiple consumers, streaming pipelines) don't match our use case of client apps submitting events to a single database. If future analytics requirements demand event streaming, Kafka can be added via CDC without refactoring the core application.

This architecture provides the best balance of:
- ✅ FDA compliance capabilities (client and server)
- ✅ Production reliability
- ✅ Developer experience
- ✅ Performance characteristics
- ✅ Cross-platform support (client)
- ✅ Scalability (server)
- ✅ Operational simplicity
- ✅ Cost effectiveness

**Next Step**: Await architecture approval, then proceed with Phase 1 MVP implementation following the plan in PLAN.md.
