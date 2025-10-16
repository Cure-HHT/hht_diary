# ADR-001: Event Sourcing Pattern for Diary Data

**Date**: 2025-10-14
**Status**: Accepted
**Deciders**: Development Team, Compliance Officer
**Compliance**: FDA 21 CFR Part 11, HIPAA

---

## Context

Clinical trial diary data has unique requirements that differ from typical CRUD applications:

1. **Regulatory Compliance**: FDA 21 CFR Part 11 requires complete, immutable audit trails showing all data modifications
2. **Multi-Device Sync**: Study participants may use multiple devices, requiring conflict detection and resolution
3. **Data Integrity**: Need to prove data has not been tampered with for regulatory audits
4. **Time-Travel Queries**: Investigators need to see historical states of data for analysis
5. **Offline Support**: Mobile apps need to work offline and sync later
6. **Conflict Resolution**: Multiple edits to same entry must be detectable and resolvable

Traditional CRUD (Create, Read, Update, Delete) patterns with separate audit trail tables don't naturally support these requirements and can lead to inconsistencies between primary data and compliance records.

---

## Decision

We will use an **Event Sourcing pattern** where:

1. **`record_audit` table is the source of truth** (immutable event log)
   - Every data modification is an INSERT into this table
   - No UPDATEs or DELETEs allowed (enforced by PostgreSQL rules)
   - Each entry is an "event" describing what changed

2. **`record_state` table is a materialized view** (derived state)
   - Contains current state of each diary entry
   - Updated automatically via database triggers
   - Acts as a read-optimized cache

3. **All changes flow through the event store**
   - Application inserts events into `record_audit` (event store)
   - Triggers update `record_state` (read model) automatically
   - No direct modifications to read model allowed

### Implementation

```sql
-- Event log (source of truth)
CREATE TABLE record_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL,
    patient_id TEXT NOT NULL,
    operation TEXT NOT NULL,  -- USER_CREATE, USER_UPDATE, etc.
    data JSONB NOT NULL,
    created_by TEXT NOT NULL,
    parent_audit_id BIGINT REFERENCES record_audit(audit_id),
    server_timestamp TIMESTAMPTZ DEFAULT now() NOT NULL,
    -- ... other metadata
);

-- Prevent modifications
CREATE RULE audit_no_update AS ON UPDATE TO record_audit DO INSTEAD NOTHING;
CREATE RULE audit_no_delete AS ON DELETE TO record_audit DO INSTEAD NOTHING;

-- Current state (derived)
CREATE TABLE record_state (
    event_uuid UUID PRIMARY KEY,
    patient_id TEXT NOT NULL,
    current_data JSONB NOT NULL,
    version INTEGER NOT NULL,
    last_audit_id BIGINT NOT NULL REFERENCES record_audit(audit_id),
    -- ... other fields
);

-- Automatic state synchronization
CREATE TRIGGER sync_state_from_audit
    AFTER INSERT ON record_audit
    FOR EACH ROW
    EXECUTE FUNCTION update_record_state_from_audit();
```

---

## Consequences

### Positive Consequences

✅ **Audit Trail by Design**
- Complete history automatically captured in event store
- No chance of event store getting out of sync with current state (same database trigger)
- Every modification is permanently recorded as an immutable event

✅ **Time-Travel Queries**
```sql
-- View data as it was at specific time
SELECT * FROM record_audit
WHERE event_uuid = 'xxx'
AND server_timestamp <= '2024-01-01'
ORDER BY audit_id DESC LIMIT 1;
```

✅ **Conflict Detection**
- `parent_audit_id` creates explicit version chain
- Can detect when two clients modified same entry
- Traceable conflict resolution

✅ **Immutability**
- Database rules prevent tampering
- Cryptographic hashing adds additional tamper detection
- Meets FDA 21 CFR Part 11 requirements

✅ **Debugging & Forensics**
- Can replay sequence of events
- Understand exactly how data reached current state
- Investigate issues without losing information

✅ **Compliance Ready**
- Regulators can audit complete history
- No data ever deleted (soft delete via events)
- Maintains chain of custody

### Negative Consequences

⚠️ **Increased Complexity**
- More complex than simple CRUD operations
- Developers must understand event sourcing concepts
- Trigger logic must be carefully maintained

⚠️ **Storage Overhead**
- All history retained permanently
- Disk space grows continuously
- Needs monitoring and archival strategy for very old data

⚠️ **Query Complexity**
- Current state queries simple (use `record_state` read model)
- Historical queries more complex (need to query event store)
- Developers must understand when to query event store vs read model

⚠️ **Performance Considerations**
- Every write creates event in event store AND updates read model
- Trigger execution adds latency (atomic transaction)
- Need indexes on both event store and read model

⚠️ **Cannot Truly Delete**
- Even "deleted" entries remain in event store (immutability requirement)
- Must use soft delete flags in read model
- GDPR "right to be forgotten" requires special handling (compliance vs. technical challenge)

---

## Alternatives Considered

### Alternative 1: Traditional CRUD with Audit Triggers

**Approach**: Normal tables with separate audit trail table populated by triggers

```sql
CREATE TABLE diary_entries (
    id UUID PRIMARY KEY,
    data JSONB,
    updated_at TIMESTAMP
);

CREATE TABLE audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name TEXT,
    record_id UUID,
    old_value JSONB,
    new_value JSONB,
    -- ...
);
```

**Why Rejected**:
- ❌ Audit trail table is separate from main data (can get out of sync)
- ❌ Harder to ensure audit trail completeness
- ❌ Reconstruction of history requires complex queries joining multiple tables
- ❌ Conflict detection not natural to the model
- ❌ Triggers can be disabled, breaking audit trail (compliance risk)

### Alternative 2: PostgreSQL Temporal Tables

**Approach**: Use PostgreSQL's built-in temporal table features

```sql
CREATE TABLE diary_entries (
    id UUID,
    data JSONB,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    PERIOD FOR valid_time(valid_from, valid_to)
);
```

**Why Rejected**:
- ❌ Less flexible for compliance metadata
- ❌ Doesn't naturally support conflict detection
- ❌ Harder to add cryptographic signatures
- ❌ Not as explicit about operations (CREATE vs UPDATE)
- ✅ Would work, but event sourcing fits requirements better

### Alternative 3: Append-Only Log with CQRS

**Approach**: Pure event sourcing with separate read/write models

**Why Rejected**:
- ❌ Too complex for this use case
- ❌ Would require event replay on every query
- ❌ Performance challenges without caching
- ✅ Our hybrid approach (event log + materialized state) provides best of both worlds

---

## Implementation Notes

### For Developers

**Writing Data**:
```sql
-- Always insert into record_audit
INSERT INTO record_audit (
    event_uuid, patient_id, operation, data,
    created_by, role, client_timestamp, change_reason
) VALUES (...);

-- record_state updates automatically via trigger
```

**Reading Current Data**:
```sql
-- Use record_state for current data
SELECT * FROM record_state
WHERE patient_id = 'xxx'
AND is_deleted = false;
```

**Reading History**:
```sql
-- Use record_audit for history
SELECT * FROM record_audit
WHERE event_uuid = 'xxx'
ORDER BY audit_id;
```

### Conflict Resolution

When a conflict is detected:
1. Insert both versions into `record_audit`
2. Create entry in `sync_conflicts` table
3. Application resolves conflict
4. Insert resolution as new audit entry with `conflict_resolved = true`

### Monitoring

Key metrics to monitor:
- Event store size (plan for growth and partitioning)
- Trigger execution time (event store → read model sync)
- Conflicts detected vs resolved
- Read model consistency checks (verify against event store)

---

## References

- [Event Sourcing Pattern - Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html)
- [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
- [Event Sourcing for CQRS](https://docs.microsoft.com/en-us/azure/architecture/patterns/event-sourcing)
- Database implementation: `database/schema.sql`, `database/triggers.sql`

---

## Related ADRs

- [ADR-002](./ADR-002-jsonb-flexible-schema.md) - Why we use JSONB for diary data
- [ADR-004](./ADR-004-investigator-annotations.md) - Why annotations are separate from events

---

**Review History**:
- 2025-10-14: Accepted by development team and compliance officer
