# ADR-002: JSONB for Flexible Diary Schema

**Date**: 2025-10-14
**Status**: Accepted
**Deciders**: Development Team, Clinical Research Team
**Technical Impact**: High

---

## Context

Clinical trial diary entries have varying data structures depending on:

1. **Study Design**: Different trials collect different data points
2. **Diary Type**: Symptom logs, medication tracking, activity logs, mood surveys
3. **Evolving Requirements**: Studies may add new questions mid-trial
4. **Multi-Language Support**: Questions and responses in multiple languages
5. **Conditional Fields**: Some fields appear based on previous answers
6. **Custom Extensions**: Research sites may add site-specific questions

Traditional relational schema would require:
- Extensive EAV (Entity-Attribute-Value) tables
- Schema migrations for every new question type
- Complex joins to reconstruct diary entries
- Difficulty handling optional/conditional fields

Example data complexity:
```json
{
  "diary_type": "symptom_log",
  "date": "2024-01-15",
  "symptoms": [
    {
      "symptom": "headache",
      "severity": 7,
      "duration_minutes": 120,
      "triggers": ["stress", "weather"]
    }
  ],
  "medications_taken": [
    {
      "medication": "ibuprofen",
      "dosage": "400mg",
      "time": "14:30"
    }
  ],
  "custom_site_fields": {
    "mood_score": 6,
    "sleep_quality": "good"
  }
}
```

---

## Decision

We will use **PostgreSQL JSONB** for storing diary entry data in the `record_audit.data` and `record_state.current_data` columns.

### Implementation

```sql
CREATE TABLE record_audit (
    -- ... other columns
    data JSONB NOT NULL,
    -- ... other columns
);

CREATE TABLE record_state (
    -- ... other columns
    current_data JSONB NOT NULL,
    -- ... other columns
);

-- GIN index for fast JSONB queries
CREATE INDEX idx_audit_data_gin ON record_audit USING GIN (data);
CREATE INDEX idx_state_data_gin ON record_state USING GIN (current_data);
```

### Validation Layer

```sql
-- Application-level validation function
CREATE OR REPLACE FUNCTION validate_diary_data(data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check required fields exist
    IF NOT (data ? 'event_type') THEN
        RAISE EXCEPTION 'Missing required field: event_type';
    END IF;

    IF NOT (data ? 'date') THEN
        RAISE EXCEPTION 'Missing required field: date';
    END IF;

    -- Validate types
    IF jsonb_typeof(data->'event_type') != 'string' THEN
        RAISE EXCEPTION 'event_type must be a string';
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql;
```

---

## Consequences

### Positive Consequences

✅ **Schema Flexibility**
- Add new fields without database migrations
- Support study-specific custom fields
- Accommodate conditional/optional fields naturally

✅ **Fast Development**
- No schema changes needed for new questions
- Studies can be configured via application
- Rapid prototyping of new diary types

✅ **Version Tolerance**
- Old and new diary formats coexist
- Backward compatible by design
- Graceful handling of missing fields

✅ **Natural Data Model**
- Diary entries are naturally hierarchical (nested objects)
- Arrays for repeating elements (multiple symptoms, medications)
- Matches JSON APIs and mobile app data structures

✅ **Query Capabilities**
```sql
-- Query by nested field
SELECT * FROM record_state
WHERE current_data->>'diary_type' = 'symptom_log';

-- Query array elements
SELECT * FROM record_state
WHERE current_data->'symptoms' @> '[{"symptom": "headache"}]';

-- Aggregate on nested values
SELECT
    current_data->>'diary_type' as type,
    COUNT(*) as count
FROM record_state
GROUP BY current_data->>'diary_type';
```

✅ **Index Performance**
- GIN indexes support fast containment queries
- Efficient for common query patterns
- Better than EAV joins

### Negative Consequences

⚠️ **Schema Validation Complexity**
- No database-enforced schema
- Validation must happen at application layer
- Risk of inconsistent data if validation bypassed
- **Mitigation**: Validation function called by trigger

⚠️ **Query Complexity**
- Developers must learn JSONB query syntax
- Complex nested queries can be hard to read
- Some queries harder than with normalized tables
- **Mitigation**: Create helper views for common queries

⚠️ **Type Safety**
- All values stored as JSON types (string, number, boolean, array, object)
- No database-enforced type constraints
- **Mitigation**: Application-level type checking, validation functions

⚠️ **Index Limitations**
- GIN indexes larger than B-tree indexes
- Not all JSON queries can use indexes
- Deep nesting can hurt query performance
- **Mitigation**: Keep nesting shallow, create functional indexes for hot paths

⚠️ **Referential Integrity**
- Cannot have foreign keys to nested JSONB values
- References must be validated in application
- **Mitigation**: Application-layer checks, validation triggers

⚠️ **Data Size**
- JSON has overhead (field names repeated)
- Larger than normalized tables for same data
- **Mitigation**: Acceptable trade-off for flexibility; compression helps

---

## Alternatives Considered

### Alternative 1: Normalized Relational Schema

**Approach**: Traditional normalized tables

```sql
CREATE TABLE diary_entries (
    id UUID PRIMARY KEY,
    patient_id TEXT,
    entry_date DATE,
    diary_type TEXT
);

CREATE TABLE symptoms (
    id UUID PRIMARY KEY,
    diary_entry_id UUID REFERENCES diary_entries(id),
    symptom TEXT,
    severity INTEGER,
    duration_minutes INTEGER
);

CREATE TABLE medications_taken (
    id UUID PRIMARY KEY,
    diary_entry_id UUID REFERENCES diary_entries(id),
    medication TEXT,
    dosage TEXT,
    time TIME
);

-- ... many more tables for each diary type
```

**Why Rejected**:
- ❌ Requires schema migration for each new field
- ❌ Complex joins to reconstruct full diary entry
- ❌ Difficult to handle study-specific customizations
- ❌ Over-engineering for flexible data
- ❌ Event sourcing harder with many tables
- ✅ Would provide strong type safety
- ✅ Would support referential integrity

**Verdict**: Too rigid for clinical research requirements

### Alternative 2: Entity-Attribute-Value (EAV)

**Approach**: Generic attribute storage

```sql
CREATE TABLE diary_entries (
    id UUID PRIMARY KEY,
    patient_id TEXT,
    entry_date DATE
);

CREATE TABLE diary_attributes (
    id UUID PRIMARY KEY,
    diary_entry_id UUID REFERENCES diary_entries(id),
    attribute_name TEXT,
    attribute_value TEXT,
    value_type TEXT  -- 'string', 'number', 'date', etc.
);
```

**Why Rejected**:
- ❌ Terrible query performance (many joins)
- ❌ No native support for nested/hierarchical data
- ❌ Type conversions error-prone
- ❌ Hard to understand and maintain
- ❌ Index strategy complex
- ✅ Very flexible
- ✅ Easy to add new attributes

**Verdict**: JSONB provides same flexibility with better performance

### Alternative 3: XML Column

**Approach**: Store data as XML

```sql
CREATE TABLE record_audit (
    -- ... other columns
    data XML NOT NULL,
    -- ... other columns
);
```

**Why Rejected**:
- ❌ XML more verbose than JSON (larger storage)
- ❌ PostgreSQL JSONB has better query support than XML
- ❌ JSON is standard for modern APIs
- ❌ Mobile apps use JSON natively
- ❌ Limited index support compared to JSONB
- ✅ XML Schema validation available
- ✅ XPath queries

**Verdict**: JSONB is better fit for modern architecture

### Alternative 4: Hybrid Approach

**Approach**: Normalize common fields, use JSONB for extensions

```sql
CREATE TABLE record_audit (
    -- ... other columns
    diary_type TEXT NOT NULL,  -- normalized
    entry_date DATE NOT NULL,  -- normalized
    data JSONB NOT NULL,       -- flexible extensions
    -- ... other columns
);
```

**Why Rejected (for now)**:
- ❌ Where to draw the line between normalized and flexible?
- ❌ Diary types have very different common fields
- ❌ Would still need JSONB for most data
- ❌ Adds complexity without major benefit
- ✅ Might perform slightly better for common queries
- ✅ Could revisit if performance issues arise

**Verdict**: Pure JSONB simpler; revisit if needed

---

## Implementation Guidelines

### For Developers

**1. Always Validate**:
```javascript
// Application validation before insert
const diarySchema = {
  type: "object",
  required: ["event_type", "date"],
  properties: {
    event_type: { type: "string" },
    date: { type: "string", format: "date" },
    // ... more validation rules
  }
};

validate(diaryData, diarySchema);
```

**2. Use Type-Safe Accessors**:
```sql
-- Good: explicit type casting
SELECT (data->>'severity')::INTEGER FROM record_state;

-- Bad: assuming types
SELECT data->>'severity' FROM record_state;
```

**3. Create Helper Views**:
```sql
-- Make common queries easier
CREATE VIEW symptom_logs AS
SELECT
    event_uuid,
    patient_id,
    (current_data->>'date')::DATE as entry_date,
    jsonb_array_elements(current_data->'symptoms') as symptom
FROM record_state
WHERE current_data->>'diary_type' = 'symptom_log';
```

**4. Document Schema**:
- Maintain JSON schema definitions in code
- Version schemas as diary types evolve
- Generate documentation from schemas

### Query Examples

```sql
-- Find all headache reports
SELECT * FROM record_state
WHERE current_data->'symptoms' @> '[{"symptom": "headache"}]';

-- Average severity by symptom type
SELECT
    symptom->>'symptom' as symptom_name,
    AVG((symptom->>'severity')::INTEGER) as avg_severity
FROM record_state,
    jsonb_array_elements(current_data->'symptoms') as symptom
WHERE current_data->>'diary_type' = 'symptom_log'
GROUP BY symptom->>'symptom';

-- Entries with high severity
SELECT * FROM record_state
WHERE EXISTS (
    SELECT 1 FROM jsonb_array_elements(current_data->'symptoms') as s
    WHERE (s->>'severity')::INTEGER > 7
);
```

---

## Migration Path

If we need to move away from JSONB in the future:

1. **To Normalized Schema**:
   - Create normalized tables
   - Write migration script to extract JSONB → tables
   - Keep JSONB as backup/audit
   - Switch reads to new tables

2. **Cost**: High (major refactoring)
3. **Likelihood**: Low (JSONB meets requirements well)

---

## Performance Monitoring

Key metrics to track:
- JSONB column size growth
- GIN index size
- Query performance on JSONB fields
- Application validation overhead

---

## References

- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [JSONB Performance Tips](https://www.postgresql.org/docs/current/datatype-json.html#JSON-INDEXING)
- [JSON Schema](https://json-schema.org/) - For application-level validation
- Database implementation: `database/schema.sql:49,88`

---

## Related ADRs

- [ADR-001](./ADR-001-event-sourcing-pattern.md) - Event sourcing uses JSONB for event data
- [ADR-003](./ADR-003-row-level-security.md) - RLS policies apply to JSONB queries

---

**Review History**:
- 2025-10-14: Accepted by development team and clinical research team
