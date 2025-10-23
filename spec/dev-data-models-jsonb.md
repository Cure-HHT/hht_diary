# JSONB Schema Documentation
# TODO: There should be a single source of truth for each JSON schema used. This source will be used in automatic or manual generation of the schemas used in the postgresQL database as well as any app (e.g. flutter/web) that accesses the database
# TODO: Each schema (epistaxis records, various surveys) should be in its own versioned file.

## Document Information
- **Version**: 1.0
- **Last Updated**: 2025-10-15
- **Status**: Draft
- **Related Files**:
  - `database/dart/diary.tsx` (application data model)
  - `database/schema.sql` (database schema)

---

## Overview

This document defines the JSONB data structure stored in the `data` column of the `record_audit` (event store) and `current_data` column of the `record_state` (read model) tables.

The schema uses a **hierarchical event-sourced model** with versioned types to support schema evolution over time.

**Architecture**: Event Sourcing pattern where all changes are captured as immutable events in the event store, with the read model materialized from the event stream.

### Architecture Context

- **Scale**: ~100 users, ~10 events per user per day
- **Model**: Local-first with offline sync to central database
- **Access**: Users write only their own records (enforced by RLS)
- **Analysis**: Analysts use exported data snapshots, not live queries
- **Compliance**: FDA 21 CFR Part 11 with complete audit trail

---

## Design Principles

### 1. ALCOA+ Compliance
- **Attributable, Legible, Contemporaneous, Original, Accurate**
- Use meaningful string values for enums (e.g., "moderate" not 2)
- Data must be clear and unambiguous without database context
- All timestamps in ISO 8601 format with timezone

### 2. Schema Versioning
- Each event type includes version number (e.g., "epistaxis-v1.0")
- Supports backward compatibility during schema evolution
- Validation rules vary by version
- Migration path documented for each version change

### 3. UUID Strategy
- Client-generated UUIDs (RFC 9562)
- Recommended: UUID v7 for time-ordered sorting
- Supported: UUID v4 for compatibility
- Same UUID used across audit history chain

---

## Top-Level Structure: EventRecord

All diary events follow this root structure:

```typescript
type EventRecord = {
  id: string;                    // UUID v7 per RFC 9562
  versioned_type: string;        // Format: "{type}-v{major}.{minor}"
  event_data: object;            // Type-specific data (see below)
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (UUID) | Yes | Client-generated UUID. Must match `record_state.event_uuid`. Recommended: UUID v7 for time-ordering. |
| `versioned_type` | string | Yes | Event type with version. Format: `{event_type}-v{major}.{minor}`. Examples: `"epistaxis-v1.0"`, `"survey-v2.1"` |
| `event_data` | object | Yes | Type-specific event data. Structure depends on `versioned_type`. See event-specific schemas below. |

### Validation Rules

- `id` must be valid UUID format
- `versioned_type` must match pattern: `^[a-z_]+-(v\d+\.\d+)$`
- `event_data` must be non-empty object
- `event_data` structure must match the schema for its `versioned_type`

---

## Event Type: Epistaxis (Nosebleed)

### Version: epistaxis-v1.0

Records nosebleed events with clinical details.

```typescript
type EpistaxisRecord = {
  id: string;                         // UUID (typically same as parent EventRecord.id)
  startTime: string;                  // ISO 8601: YYYY-MM-DDTHH:MM:SS±HH:MM
  endTime?: string;                   // ISO 8601: YYYY-MM-DDTHH:MM:SS±HH:MM
  severity?: string;                  // One of: "minimal", "mild", "moderate", "severe", "very_severe", "extreme"
  user_notes?: string;                // Free-text notes from user
  isNoNosebleedsEvent?: boolean;      // true = user confirmed NO nosebleeds occurred on startTime's date
  isUnknownNosebleedsEvent?: boolean; // true = user doesn't recall nosebleed events for this date
  isIncomplete?: boolean;             // true = partial data entry (e.g., only startTime recorded)
  lastModified: string;               // ISO 8601: when record was last modified
}
```

### Complete Example

```json
{
  "id": "018e1234-5678-9abc-def0-123456789abc",
  "versioned_type": "epistaxis-v1.0",
  "event_data": {
    "id": "018e1234-5678-9abc-def0-123456789abc",
    "startTime": "2025-10-15T14:30:00-05:00",
    "endTime": "2025-10-15T14:45:00-05:00",
    "severity": "moderate",
    "user_notes": "Occurred during exercise. Stopped with pressure.",
    "isNoNosebleedsEvent": false,
    "isUnknownNosebleedsEvent": false,
    "isIncomplete": false,
    "lastModified": "2025-10-15T14:50:00-05:00"
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (UUID) | Yes | Event identifier. Typically matches parent `EventRecord.id`. |
| `startTime` | string (ISO 8601) | Yes | When nosebleed started. Must include timezone. |
| `endTime` | string (ISO 8601) | No | When nosebleed stopped. Omit if ongoing or unknown. |
| `severity` | string (enum) | No | Clinical severity rating. See severity values below. |
| `user_notes` | string | No | Patient-entered free-text notes. Max length: 2000 characters recommended. |
| `isNoNosebleedsEvent` | boolean | No | Set to `true` when user confirms no nosebleeds occurred on this date. Mutually exclusive with actual nosebleed data. |
| `isUnknownNosebleedsEvent` | boolean | No | Set to `true` when user cannot recall events for this date. Used for compliance tracking. |
| `isIncomplete` | boolean | No | Set to `true` if entry is partial (e.g., user started recording but didn't finish). |
| `lastModified` | string (ISO 8601) | Yes | Client-side timestamp of last modification. Used for conflict detection. |

### Severity Values (enum)

Meaningful string values per ALCOA+ principles:

| Value | Clinical Meaning | Display Text |
|-------|------------------|--------------|
| `"minimal"` | Trace blood only | Minimal |
| `"mild"` | Brief, self-limiting | Mild |
| `"moderate"` | Requires intervention | Moderate |
| `"severe"` | Difficult to control | Severe |
| `"very_severe"` | Medical attention needed | Very Severe |
| `"extreme"` | Emergency intervention | Extreme |

**Validation**: Must be one of these exact string values. Numbers (1-6) are NOT allowed.

### Special Event Types

#### No Nosebleeds Event

User confirms no nosebleeds occurred on a given date.

```json
{
  "id": "018e1234-5678-9abc-def0-123456789def",
  "versioned_type": "epistaxis-v1.0",
  "event_data": {
    "id": "018e1234-5678-9abc-def0-123456789def",
    "startTime": "2025-10-15T00:00:00-05:00",
    "isNoNosebleedsEvent": true,
    "isUnknownNosebleedsEvent": false,
    "isIncomplete": false,
    "lastModified": "2025-10-15T20:00:00-05:00"
  }
}
```

**Validation Rules**:
- When `isNoNosebleedsEvent: true`:
  - `endTime` must be omitted
  - `severity` must be omitted
  - `user_notes` may be present (e.g., "Felt fine all day")
  - `isUnknownNosebleedsEvent` must be `false` or omitted

#### Unknown/Don't Recall Event

User cannot remember if nosebleeds occurred.

```json
{
  "id": "018e1234-5678-9abc-def0-123456789fed",
  "versioned_type": "epistaxis-v1.0",
  "event_data": {
    "id": "018e1234-5678-9abc-def0-123456789fed",
    "startTime": "2025-10-12T00:00:00-05:00",
    "isNoNosebleedsEvent": false,
    "isUnknownNosebleedsEvent": true,
    "isIncomplete": false,
    "lastModified": "2025-10-15T20:05:00-05:00"
  }
}
```

**Validation Rules**:
- When `isUnknownNosebleedsEvent: true`:
  - `endTime` must be omitted
  - `severity` must be omitted
  - `user_notes` may be present (e.g., "Can't remember this day")
  - `isNoNosebleedsEvent` must be `false` or omitted

#### Incomplete Entry

User started recording but didn't finish.

```json
{
  "id": "018e1234-5678-9abc-def0-123456789abc",
  "versioned_type": "epistaxis-v1.0",
  "event_data": {
    "id": "018e1234-5678-9abc-def0-123456789abc",
    "startTime": "2025-10-15T14:30:00-05:00",
    "isIncomplete": true,
    "lastModified": "2025-10-15T14:31:00-05:00"
  }
}
```

**Validation Rules**:
- When `isIncomplete: true`:
  - Only `startTime` is required
  - All other fields are optional
  - User can complete later by updating with `isIncomplete: false`

---

## Event Type: Survey

### Version: survey-v1.0 (Proposed)

Records structured survey responses with scoring.

```typescript
type SurveyRecord = {
  id: string;                         // UUID (typically same as parent EventRecord.id)
  completedAt: string;                // ISO 8601: when survey was completed
  survey: SurveyQuestion[];           // Array of question/response pairs
  score?: SurveyScore;                // Calculated scores per rubric
  lastModified: string;               // ISO 8601: when record was last modified
}

type SurveyQuestion = {
  question_id: string;                // Unique question identifier
  question_text: string;              // Full question text (for auditability)
  response?: string | number | boolean | string[];  // Response value(s)
  skipped?: boolean;                  // true if user skipped this question
}

type SurveyScore = {
  total: number;                      // Total score
  subscales?: Record<string, number>; // Named subscale scores
  rubric_version: string;             // Version of scoring rubric used
}
```

### Complete Example

```json
{
  "id": "018e2345-6789-abcd-ef01-23456789abcd",
  "versioned_type": "survey-v1.0",
  "event_data": {
    "id": "018e2345-6789-abcd-ef01-23456789abcd",
    "completedAt": "2025-10-15T15:00:00-05:00",
    "survey": [
      {
        "question_id": "q1_frequency",
        "question_text": "How many nosebleeds did you experience in the past week?",
        "response": 3
      },
      {
        "question_id": "q2_impact",
        "question_text": "How much did nosebleeds impact your daily activities?",
        "response": "moderate"
      },
      {
        "question_id": "q3_medications",
        "question_text": "Which medications did you use?",
        "response": ["nasal_spray", "over_counter_pain_relief"],
        "skipped": false
      }
    ],
    "score": {
      "total": 42,
      "subscales": {
        "frequency": 15,
        "impact": 18,
        "treatment": 9
      },
      "rubric_version": "v1.2"
    },
    "lastModified": "2025-10-15T15:00:00-05:00"
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (UUID) | Yes | Event identifier. Typically matches parent `EventRecord.id`. |
| `completedAt` | string (ISO 8601) | Yes | When survey was completed. Must include timezone. |
| `survey` | array | Yes | Array of question/response pairs. Must be non-empty. |
| `score` | object | No | Calculated scores. Omit if survey incomplete or not scored. |
| `lastModified` | string (ISO 8601) | Yes | Client-side timestamp of last modification. |

### SurveyQuestion Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `question_id` | string | Yes | Unique identifier for this question (e.g., "q1_frequency"). Stable across versions. |
| `question_text` | string | Yes | Full text of question. Stored for auditability even if question changes later. |
| `response` | any | No | Answer value. Type depends on question (number, string, boolean, array). Omit if skipped. |
| `skipped` | boolean | No | Set to `true` if user explicitly skipped this question. |

### SurveyScore Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `total` | number | Yes | Total calculated score. |
| `subscales` | object | No | Named subscale scores (e.g., {"anxiety": 10, "depression": 15}). |
| `rubric_version` | string | Yes | Version of scoring algorithm used. Format: "v{major}.{minor}" |

### Validation Rules

- Each question must have unique `question_id` within survey
- `question_text` must be non-empty
- If `skipped: true`, `response` must be omitted
- If `skipped: false` or omitted, `response` must be present
- `score.total` must be non-negative number
- `score.rubric_version` must match pattern: `^v\d+\.\d+$`

---

## Future Event Types

### Planned Types

| Type | Version | Description | Status |
|------|---------|-------------|--------|
| `medication-v1.0` | 1.0 | Medication adherence tracking | Planned |
| `symptom-v1.0` | 1.0 | General symptom diary | Planned |
| `quality_of_life-v1.0` | 1.0 | QoL assessment | Planned |

---

## Schema Evolution Strategy

### Version Numbering

Format: `{event_type}-v{major}.{minor}`

- **Major version** (X.0): Breaking changes, incompatible with previous version
- **Minor version** (0.X): Backward-compatible additions

### Examples

- `epistaxis-v1.0` → `epistaxis-v1.1`: Add optional field (backward compatible)
- `epistaxis-v1.1` → `epistaxis-v2.0`: Change severity enum values (breaking change)

### Migration Rules

1. **Adding optional fields**: Increment minor version
2. **Removing fields**: Increment major version
3. **Changing field types**: Increment major version
4. **Changing enum values**: Increment major version
5. **Adding new enum values**: Increment minor version

### Backward Compatibility

- Database must validate against specific version
- Older versions remain valid (audit trail immutability)
- Application must handle multiple versions during read
- New writes should use latest version when possible

---

## Database Storage

### record_audit.data (Event Store)

Stores the complete EventRecord as shown above in the `data` JSONB column.

**Storage principle**: Complete snapshots, not deltas. Each event in the event store contains the full state of the record at that point in time.

**Event Sourcing**: This is the append-only event log. All state changes are recorded here as immutable events.

Example query to extract event type:
```sql
SELECT
  audit_id,
  data->>'versioned_type' as event_type,
  data->'event_data'->>'startTime' as start_time
FROM record_audit
WHERE data->>'versioned_type' LIKE 'epistaxis-%';
```

### record_state.current_data (Read Model)

Stores the current version (same structure as event store) in the `current_data` JSONB column.

**Access pattern**: Users query this table for current state. Investigators/analysts use this for reporting. Event store used only for compliance/history/event replay.

**CQRS**: This is the read-optimized materialized view. It's automatically updated by triggers when events are written to the event store.

Example query to find severe nosebleeds:
```sql
SELECT
  event_uuid,
  current_data->'event_data'->>'startTime' as start_time,
  current_data->'event_data'->>'severity' as severity
FROM record_state
WHERE
  current_data->>'versioned_type' LIKE 'epistaxis-%'
  AND current_data->'event_data'->>'severity' = 'severe';
```

### Access Control (RLS)

**Critical requirement**: Users must ONLY be able to access their own records.

Row-Level Security policies enforce:
- **Users**: Can only SELECT/INSERT/UPDATE records where `patient_id = current_user_id()`
- **Investigators**: Read-only access to records at their assigned site(s)
- **Analysts**: Export data through application layer, not direct database access

See `database/rls_policies.sql` for implementation.

### Performance Considerations

**Scale**: This database is designed for ~100 users with ~10 transactions per user per day.

**Architecture**: Local-first with offline sync. Users update only their own records.

**Query patterns**:
- Users: Read/write own records only (enforced by RLS)
- Investigators: Read-only access to assigned site(s)
- Analysts: Export data snapshots for external analysis

**Indexing**: Standard primary keys and foreign keys are sufficient. Additional JSONB indexes are unnecessary at this scale and would add complexity without benefit.

---

## Validation Function Requirements

The database validation function must check:

1. **Top-level structure**: Presence of `id`, `versioned_type`, `event_data`
2. **UUID format**: Valid UUID in `id` field
3. **Version format**: Pattern match `^[a-z_]+-v\d+\.\d+$`
4. **Event-specific validation**: Delegate to type-specific validator based on `versioned_type`
5. **ISO 8601 timestamps**: All date/time fields must be valid ISO 8601 with timezone
6. **Enum values**: String enums must match allowed values (not numbers)
7. **Mutual exclusivity**: Flags like `isNoNosebleedsEvent` and `isUnknownNosebleedsEvent` cannot both be true

See `database/schema.sql` for implementation.

---

## Compliance Notes

### ALCOA+ Principles Applied

| Principle | Implementation |
|-----------|----------------|
| **Attributable** | `created_by` in event store, UUID links to user |
| **Legible** | Meaningful string enums, clear field names |
| **Contemporaneous** | `client_timestamp` captures when event occurred |
| **Original** | Complete data stored in `event_data`, not transformed |
| **Accurate** | Validation functions enforce data quality |
| **Complete** | All fields captured, optional fields explicit |
| **Consistent** | Versioned schema ensures structural consistency |
| **Enduring** | Immutable audit trail, timestamps preserved |
| **Available** | RLS policies ensure proper access, archived long-term |

### FDA 21 CFR Part 11

- Complete audit trail of all changes (§11.10(e))
- Timestamped entries (§11.10(e)(1))
- Change reason recorded (§11.10(e)(2))
- Cannot modify historical records (§11.10(e)(3))
- Data validation enforced (§11.10(a))

---

## References

- **diary.tsx**: Application-layer data model (database/dart/diary.tsx)
- **schema.sql**: Database schema definition (database/schema.sql)
- **RFC 9562**: UUID specification (https://www.rfc-editor.org/rfc/rfc9562.html)
- **ISO 8601**: Date/time format standard
- **FDA 21 CFR Part 11**: Electronic records regulation
- **ALCOA+ Principles**: Data integrity guidance

---

*End of Document*
