# ADR-004: Separation of Investigator Annotations

**Date**: 2025-10-14
**Deciders**: Development Team, Clinical Research Team, Compliance Officer
**Compliance Impact**: High

## Status

Accepted

---

## Context

Clinical trial workflows involve two distinct types of data modifications:

### 1. Patient-Generated Data
- Study participants enter diary data (symptoms, medications, activities)
- Patient owns and controls their data
- May be edited by patient within allowed timeframes
- Source data for clinical analysis

### 2. Investigator Oversight
- Clinical investigators review patient diary entries
- May add notes, queries, or corrections
- Cannot directly modify original patient data
- Required for data quality and compliance

### Regulatory Requirements

**21 CFR Part 11 & Good Clinical Practice (GCP)**:
- Original patient data must be preserved
- Any investigator changes must be documented separately
- Clear attribution (who made what change)
- Audit trail for all modifications
- Original and modified values both accessible

### Problem

How should we handle investigator modifications to diary data?

**Option A**: Modify patient data directly
```sql
-- Bad: Overwrites original patient data
UPDATE diary_entries
SET data = jsonb_set(data, '{symptoms}', '...')
WHERE id = 'xxx';
```
- ❌ Loses original patient input
- ❌ Unclear if data is original or modified
- ❌ Violates FDA requirements

**Option B**: Add to event log
```sql
-- Acceptable but cluttered
INSERT INTO record_audit (operation, data, ...)
VALUES ('INVESTIGATOR_UPDATE', modified_data, ...);
```
- ✅ Preserves history
- ⚠️ Mixes patient and investigator operations
- ⚠️ Hard to distinguish notes vs. data changes

---

## Decision

We will use a **separate `investigator_annotations` table** for all investigator oversight activities.

### Implementation

```sql
CREATE TABLE investigator_annotations (
    annotation_id BIGSERIAL PRIMARY KEY,
    event_uuid UUID NOT NULL REFERENCES record_state(event_uuid),
    investigator_id TEXT NOT NULL,
    site_id TEXT NOT NULL REFERENCES sites(site_id),
    annotation_text TEXT NOT NULL,
    annotation_type TEXT CHECK (annotation_type IN (
        'NOTE',          -- Investigator comment
        'QUERY',         -- Question for patient
        'CORRECTION',    -- Data quality issue noted
        'CLARIFICATION' -- Explanation of patient entry
    )),
    requires_response BOOLEAN DEFAULT false,
    resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMPTZ,
    resolved_by TEXT,
    parent_annotation_id BIGINT REFERENCES investigator_annotations(annotation_id),
    created_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);
```

### Workflow

**1. Patient Creates Entry**:
```sql
INSERT INTO record_audit (
    event_uuid, patient_id, operation, data, ...
) VALUES (
    'uuid-1', 'patient_1', 'USER_CREATE', '{"symptom": "headache", "severity": 8}', ...
);
```

**2. Investigator Adds Query**:
```sql
INSERT INTO investigator_annotations (
    event_uuid, investigator_id, annotation_type, annotation_text, requires_response
) VALUES (
    'uuid-1', 'investigator_1', 'QUERY',
    'Please clarify: did severity increase throughout the day?', true
);
```

**3. Patient Responds**:
```sql
-- Patient creates new audit entry with clarification
INSERT INTO record_audit (
    event_uuid, patient_id, operation, data, parent_audit_id, change_reason, ...
) VALUES (
    'uuid-1', 'patient_1', 'USER_UPDATE',
    '{"symptom": "headache", "severity": 8, "notes": "Severity peaked at 3pm"}',
    (SELECT audit_id FROM record_audit WHERE event_uuid = 'uuid-1' ORDER BY audit_id DESC LIMIT 1),
    'Response to investigator query', ...
);

-- Mark annotation as resolved
UPDATE investigator_annotations
SET resolved = true, resolved_at = now(), resolved_by = 'patient_1'
WHERE annotation_id = 123;
```

---

## Consequences

### Positive Consequences

✅ **Preserves Original Data**
- Patient data never modified by investigators
- Original entries always accessible
- Audit trail shows exact patient input

✅ **Clear Attribution**
- Patient data in `record_audit`
- Investigator notes in `investigator_annotations`
- No ambiguity about data source

✅ **Compliance**
```
21 CFR Part 11 Requirement:
"Ability to generate accurate and complete copies of records
in both human-readable and electronic form"
```
- Original records: `record_audit` + `record_state`
- Investigator oversight: `investigator_annotations`
- Both preserved and auditable

✅ **Workflow Support**
- Queries require patient response
- Annotations can be nested (replies)
- Resolution tracking built-in
- Different annotation types for different workflows

✅ **Query Flexibility**
```sql
-- Get entry with annotations
SELECT
    rs.current_data,
    ia.annotation_text,
    ia.annotation_type,
    ia.created_at
FROM record_state rs
LEFT JOIN investigator_annotations ia ON ia.event_uuid = rs.event_uuid
WHERE rs.event_uuid = 'uuid-1';

-- Get unresolved queries
SELECT * FROM investigator_annotations
WHERE requires_response = true
AND resolved = false;
```

✅ **Access Control**
- Patients see annotations on their entries
- Investigators see annotations at their sites
- Separate RLS policies for annotations table

✅ **Audit Trail**
- Annotations themselves are auditable
- Who added what annotation when
- Resolution tracking

### Negative Consequences

⚠️ **Additional Complexity**
- One more table to manage
- Joins needed to see full picture
- Application must handle both tables

⚠️ **Potential Confusion**
- Developers might not know where to put investigator actions
- Need clear guidelines on audit vs. annotations
- **Mitigation**: Documentation and code reviews

⚠️ **Query Complexity**
```sql
-- Must join to see annotations
SELECT
    rs.event_uuid,
    rs.current_data,
    json_agg(ia.*) as annotations
FROM record_state rs
LEFT JOIN investigator_annotations ia ON ia.event_uuid = rs.event_uuid
GROUP BY rs.event_uuid, rs.current_data;
```

⚠️ **No Direct Data Correction**
- Investigators cannot fix obvious typos directly
- Must query patient or admin must intervene
- **Mitigation**: Admin role can create correction events

---

## Alternatives Considered

### Alternative 1: Store in Event Log

**Approach**: Use `record_audit` for investigator notes

```sql
INSERT INTO record_audit (
    event_uuid, created_by, operation, data, role, ...
) VALUES (
    'uuid-1', 'investigator_1', 'INVESTIGATOR_ANNOTATE',
    '{"annotation": "Please clarify severity"}', 'INVESTIGATOR', ...
);
```

**Why Rejected**:
- ❌ Mixes patient data and investigator notes in same table
- ❌ Harder to query just notes
- ❌ Data and notes have different schemas
- ❌ Complicates state reconstruction
- ✅ Simpler (one table)
- ✅ All audit in one place

**Verdict**: Separation of concerns worth the extra table

### Alternative 2: Nested in JSONB

**Approach**: Store annotations inside diary data

```json
{
  "symptom": "headache",
  "severity": 8,
  "_investigator_notes": [
    {
      "investigator": "inv_1",
      "note": "Please clarify",
      "timestamp": "2024-01-15T10:30:00Z"
    }
  ]
}
```

**Why Rejected**:
- ❌ Modifies patient data structure
- ❌ Hard to query annotations across entries
- ❌ No table-level constraints
- ❌ Harder to enforce RLS
- ❌ Violates separation principle
- ✅ Self-contained entries

**Verdict**: Too coupled; loses benefits of relational database

### Alternative 3: Separate Annotations Database

**Approach**: Entirely separate database for annotations

**Why Rejected**:
- ❌ Over-engineering
- ❌ Complicates transactions
- ❌ Cross-database joins not possible
- ❌ Backup/restore more complex
- ✅ Complete separation

**Verdict**: Overkill for this use case

### Alternative 4: Investigator Can Create Correction Events

**Approach**: Allow investigators to insert into `record_audit` with special operation type

```sql
INSERT INTO record_audit (
    event_uuid, created_by, operation, data, role, ...
) VALUES (
    'uuid-1', 'investigator_1', 'INVESTIGATOR_CORRECTION',
    '{"symptom": "headache", "severity": 7, "correction_reason": "Typo"}',
    'INVESTIGATOR', ...
);
```

**Why Partially Adopted**:
- ✅ For genuine corrections (with documentation)
- ✅ Admin role can make corrections
- ⚠️ Must be used carefully
- ⚠️ Original data still preserved (event sourcing)

**Verdict**: Allow for corrections, but use annotations for queries/notes

---

## Usage Guidelines

### When to Use Annotations

✅ **Use `investigator_annotations` for**:
- Questions for the patient
- Clarification requests
- Clinical observations about entry
- Notes for other investigators
- Quality control comments

### When to Use Audit Events

✅ **Use `record_audit` for**:
- Data corrections (by admin with justification)
- Transcription (investigator enters data on patient's behalf)
- Administrative actions (merging, splitting entries)

### Annotation Types

**NOTE**: General comment
```sql
INSERT INTO investigator_annotations (...)
VALUES (..., 'NOTE', 'Patient reports this is typical for them', false);
```

**QUERY**: Requires patient response
```sql
INSERT INTO investigator_annotations (...)
VALUES (..., 'QUERY', 'Please specify time of day', true);
```

**CORRECTION**: Documents data quality issue
```sql
INSERT INTO investigator_annotations (...)
VALUES (..., 'CORRECTION', 'Severity seems inconsistent with description', false);
```

**CLARIFICATION**: Explains context
```sql
INSERT INTO investigator_annotations (...)
VALUES (..., 'CLARIFICATION', 'Patient confirmed this occurred during exercise', false);
```

---

## UI/UX Implications

**Display to Patients**:
- Show annotations on their diary entries
- Highlight queries requiring response
- Indicate when annotation resolved

**Display to Investigators**:
- See all annotations on site entries
- Filter by type (queries, notes, etc.)
- See unresolved queries needing follow-up

**Search and Reports**:
- Include annotations in full data export
- Option to filter entries with queries
- Compliance reports show annotation activity

---

## References

- [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
- [ICH E6(R2) Good Clinical Practice](https://database.ich.org/sites/default/files/E6_R2_Addendum.pdf) - Section 5.5.3
- [ALCOA+ Principles](https://www.fda.gov/media/77769/download)
- Database implementation: `database/schema.sql:99-120`

---

## Related ADRs

- [ADR-001](./ADR-001-event-sourcing-pattern.md) - Annotations are separate from event log
- [ADR-003](./ADR-003-row-level-security.md) - RLS protects annotations

---

**Review History**:
- 2025-10-14: Accepted by development, clinical research, and compliance teams
