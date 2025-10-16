# Event Sourcing Naming Consistency Plan

## Context

Recent commits introduced Event Sourcing terminology, but the codebase has inconsistent naming between old "audit log" terms and new "event store/read model" terms.

## User Question

> "when that change was made, the name of the state table was changed to record_read table"

**Finding**: The table name is still `record_state` in the actual database schema. No `record_read` table exists in the codebase.

**Clarification Needed**: Should we:
1. Keep table name as `record_state` and just update documentation terminology?
2. Actually rename the table from `record_state` → `record_read`?

## Current Naming Status

### Tables (Actual PostgreSQL Names)
- ✅ `record_audit` - Event store table (name is good, just needs better comments)
- ❓ `record_state` - Read model table (should this be renamed to `record_read`?)
- ✅ `auth_audit_log` - Authentication logging (correctly named, separate from event sourcing)

### Documentation Terminology

**Inconsistent references found in 52 files across:**

#### Event Sourcing Terminology (New/Preferred):
- "event store"
- "read model"
- "CQRS" (Command Query Responsibility Segregation)
- "event sourcing pattern"
- "immutable event log"

#### Audit Log Terminology (Old/Inconsistent):
- "audit table"
- "audit log" (when referring to record_audit in event sourcing context)
- "state table"
- "audit trail" (sometimes appropriate for compliance, sometimes conflated)

## Recommended Naming Standard

### Option A: Keep `record_state` table name
**Pros:**
- No database schema changes required
- No foreign key updates needed
- Less risky
- Documentation-only changes

**Standard:**
- Table: `record_audit` → Refer to as "Event Store"
- Table: `record_state` → Refer to as "Read Model" or "Current State View"
- Comments: Update to use Event Sourcing terminology
- Docs: Consistently use "event store" and "read model"

### Option B: Rename `record_state` → `record_read`
**Pros:**
- More explicit CQRS terminology (read vs write separation)
- Clearer that it's a read-optimized view
- Aligns with "read model" concept

**Cons:**
- Requires ALTER TABLE statement
- Must update all foreign keys
- Must update all triggers
- Must update all Dart code
- Must update all documentation
- Higher risk of breaking things

**Standard:**
- Table: `record_audit` → Event Store
- Table: `record_read` → Read Model
- All code and docs updated

## Files Requiring Updates (52 total)

### Critical Database Files (Must Match Reality)
1. `database/schema.sql` - Table definitions and comments
2. `database/triggers.sql` - References to both tables
3. `database/indexes.sql` - Indexes on both tables
4. `database/rls_policies.sql` - RLS policies
5. `database/roles.sql` - Permission grants
6. `database/tamper_detection.sql` - Hash validation queries
7. `database/init.sql` - Initialization and validation
8. `database/compliance_verification.sql` - Compliance checks
9. `database/seed_data.sql` - Test data inserts

### Migration Files
10-17. `database/migrations/*.sql` - All migration scripts
18-21. `database/testing/migrations/*.sql` - Test migrations
22-25. `database/testing/migrations/rollback/*.sql` - Rollback scripts

### Test Files
26. `database/tests/test_audit_trail.sql`
27. `database/tests/test_compliance_functions.sql`
28. `database/tests/README.md`

### Dart Code Files
29. `database/dart/diary_repository.dart` - Main repository with SQL queries
30. `database/dart/event_deletion_handler.dart` - Deletion logic
31. `database/dart/models.dart` - Data models
32. `database/dart/README.md` - Dart documentation

### Core Specification Documents
33. `spec/db-spec.md` - **PRIMARY architecture document**
34. `spec/JSONB_SCHEMA.md` - Schema definitions
35. `spec/README.md` - Overview
36. `spec/QUICK_REFERENCE.md` - Quick reference guide
37. `database/README.md` - Database documentation

### Architecture Decision Records
38. `docs/adr/ADR-001-event-sourcing-pattern.md` - **KEY document**
39. `docs/adr/ADR-002-jsonb-flexible-schema.md`
40. `docs/adr/ADR-003-row-level-security.md`
41. `docs/adr/ADR-004-investigator-annotations.md`

### Compliance & Operations Documents
42. `spec/compliance-practices.md` - Compliance requirements
43. `spec/AUTH_AUDIT_README.md` - Auth logging (separate system)
44. `spec/DEPLOYMENT_CHECKLIST.md` - Deployment steps
45. `spec/PRODUCTION_OPERATIONS.md` - Operations guide
46. `spec/MIGRATION_STRATEGY.md` - Migration strategy
47. `spec/SECURITY.md` - Security documentation
48. `spec/DATA_CLASSIFICATION.md` - Data classification
49. `spec/LOGGING_STRATEGY.md` - Logging strategy
50. `spec/COMPARISON.md` - Comparison docs
51. `spec/PROJECT_SUMMARY.md` - Project summary
52. `spec/SUPABASE_SETUP.md` - Supabase setup
53. `database-compliance-todos.md` - Compliance TODOs

## Specific Changes Needed

### Database Comments (All Files)
**Current:** "Immutable audit log - all changes recorded here"
**Proposed:** "Event Store (Event Sourcing pattern) - Immutable event log capturing all changes. Provides audit trail for FDA 21 CFR Part 11 compliance."

**Current:** "Current state of diary entries - updated via triggers only"
**Proposed:** "Read Model (CQRS pattern) - Materialized view of current state, derived from event store via triggers"

### Preserve "Audit Trail" for Compliance Contexts
**Keep using "audit trail" when:**
- Discussing FDA 21 CFR Part 11 compliance requirements
- Talking about regulatory audit capabilities
- In compliance documentation

**Use this phrasing:**
- "The event store provides the audit trail required for FDA 21 CFR Part 11 compliance"
- "Immutable audit trail maintained via event sourcing pattern"

### auth_audit_log (No Changes)
This table is **correctly named** - it's for authentication auditing (HIPAA), not part of the diary data event sourcing system. Leave as-is.

## Implementation Checklist

### Phase 1: User Confirmation
- [ ] Confirm with user: Keep `record_state` or rename to `record_read`?
- [ ] If renaming, create migration script with rollback

### Phase 2: Database Schema (if renaming)
- [ ] Create ALTER TABLE script
- [ ] Update all foreign key references
- [ ] Update all triggers
- [ ] Update all RLS policies
- [ ] Update all indexes
- [ ] Update seed data
- [ ] Test migration on clean database

### Phase 3: Database Comments & Documentation
- [ ] Update schema.sql table and column comments
- [ ] Update triggers.sql comments
- [ ] Update other SQL file comments

### Phase 4: Code Files
- [ ] Update all Dart files with SQL queries
- [ ] Update Dart documentation
- [ ] Update Dart models if needed

### Phase 5: Documentation Files
- [ ] Update spec/db-spec.md (PRIMARY)
- [ ] Update docs/adr/ADR-001-event-sourcing-pattern.md (KEY)
- [ ] Update all other spec/ files
- [ ] Update all database/ README files
- [ ] Update migration documentation

### Phase 6: Testing & Verification
- [ ] Run database/init.sql on clean database
- [ ] Verify all triggers work
- [ ] Run test suite
- [ ] Check compliance verification queries
- [ ] Verify all foreign keys intact

### Phase 7: Commit
- [ ] Review all changes
- [ ] Create comprehensive commit message
- [ ] Commit to feature branch

## Terminology Guide

### Preferred Terms (Going Forward)

| Context | Term to Use | Example |
|---------|-------------|---------|
| PostgreSQL table | `record_audit` | SELECT * FROM record_audit |
| PostgreSQL table | `record_state` (or `record_read` if renamed) | SELECT * FROM record_state |
| Documentation (record_audit) | "event store" | "The event store contains all changes" |
| Documentation (record_state) | "read model" or "current state view" | "Query the read model for current data" |
| Architecture pattern | "Event Sourcing with CQRS" | "We use Event Sourcing with CQRS" |
| Compliance context | "audit trail" | "Provides audit trail for FDA compliance" |
| Data flow | "write to event store, read from read model" | Standard CQRS pattern |

### Terms to Avoid (Ambiguous)

- ❌ "audit table" (ambiguous - which one?)
- ❌ "state table" (too generic)
- ❌ "audit log" when referring specifically to record_audit in event sourcing context (use "event store" instead)
- ❌ Mixing terminology within same document

### auth_audit_log Exception
This table is for **authentication auditing** (HIPAA compliance), not diary data event sourcing:
- ✅ Always call it "auth_audit_log" or "authentication audit log"
- ✅ Keep separate in documentation
- ❌ Don't confuse with diary data event store

## Questions for User

1. **Critical Decision**: Should we rename `record_state` to `record_read`?
   - If yes: We'll do full schema rename + all code updates
   - If no: We'll just update documentation/comments to use "read model" terminology

2. **Scope Confirmation**: Are there any files we should NOT update?
   - Old migration files in `database/testing/migrations/`?
   - Any legacy documentation?

3. **Timeline**: Should we tackle this all at once, or break into smaller commits?

## Next Steps

1. **Get user confirmation** on table rename decision
2. Start with high-impact files first (schema.sql, spec/db-spec.md, ADR-001)
3. Work through files systematically by category
4. Test thoroughly before committing
