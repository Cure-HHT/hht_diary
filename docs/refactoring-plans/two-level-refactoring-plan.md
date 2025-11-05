# Two-Level Documentation Refactoring Plan

**Date**: 2025-11-05
**Insight**: `prd-flutter-event-sourcing.md` is NOT a Flutter module spec - it's a generic event-sourcing system architecture description that happens to mention Flutter.

---

## Key Realizations

1. **prd-flutter-event-sourcing.md is the Generic Layer**
   - Describes WHAT the event-sourcing system does
   - Architecture, patterns, capabilities
   - Already 22x more generic than diary-specific
   - Only needs Flutter references removed

2. **prd-database.md is Perfect for App Layer**
   - Executive summary level
   - Diary-specific context
   - REQ-p00003 (Separate DB Per Sponsor) and REQ-p00013 (Change History)
   - Should stay as-is

3. **Diary Docs Should Be Refinements Only**
   - Don't repeat generic content
   - Add diary-specific context
   - Link to generic via "Implements"

---

## Proper Two-Level Structure

```
┌─────────────────────────────────────────────────────────────┐
│ LEVEL 1: GENERIC EVENT-SOURCING SYSTEM (Reusable)          │
│                                                             │
│  prd-event-sourcing-system.md                              │
│    ├─ Preamble (from prd-flutter-event-sourcing.md)       │
│    │  - Architecture Overview                              │
│    │  - High-Level Design                                  │
│    │  - Component Architecture                             │
│    │  - Data Flow                                          │
│    ├─ REQ-p01000: Event Sourcing Client Interface         │
│    ├─ REQ-p01001: Offline Event Queue                     │
│    ├─ REQ-p01002: Optimistic Concurrency Control          │
│    ├─ REQ-p01003: Immutable Event Storage                 │
│    ├─ REQ-p01004: Schema Version Management               │
│    ├─ REQ-p01005: Real-time Event Subscription            │
│    ├─ REQ-p01006: Type-Safe Materialized View Queries     │
│    ├─ REQ-p01007: Error Handling and Diagnostics          │
│    ├─ REQ-p01008: Event Replay (optional)                 │
│    ├─ REQ-p01009: Encryption at Rest (optional)           │
│    ├─ REQ-p01010: Multi-tenancy Support (optional)        │
│    ├─ REQ-p01011: Event Transformation (optional)         │
│    ├─ REQ-p01012: Batch Event Operations (optional)       │
│    ├─ REQ-p01013: GraphQL/gRPC Transport (optional)       │
│    ├─ REQ-p01014: Observability and Monitoring            │
│    ├─ REQ-p01015: Automated Testing Support               │
│    ├─ REQ-p01016: Performance Benchmarking                │
│    ├─ REQ-p01017: Backward Compatibility                  │
│    ├─ REQ-p01018: Security Audit                          │
│    └─ REQ-p01019: Phased Implementation                   │
│                                                             │
│  (All de-fluttered: "application" not "Flutter")          │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Implements/Refines
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ LEVEL 2: DIARY-SPECIFIC IMPLEMENTATION (Refinement)        │
│                                                             │
│  prd-database.md (KEEP AS-IS - Perfect!)                   │
│    ├─ Executive Summary                                    │
│    ├─ REQ-p00003: Separate Database Per Sponsor           │
│    │  └─ Implements: REQ-p01010 (multi-tenancy)           │
│    └─ REQ-p00013: Complete Data Change History            │
│       └─ Implements: REQ-p01003 (immutable events)        │
│                                                             │
│  prd-database-event-sourcing.md (Minor update)             │
│    └─ REQ-p00004: Immutable Audit Trail via Event Sourcing│
│       └─ Implements: REQ-p01003 (+ FDA context)           │
│                                                             │
│  dev-database.md (Focus on diary schema)                   │
│    ├─ REQ-d00007: Database Schema Implementation          │
│    │  └─ Implements: REQ-d02000 (generic schema)          │
│    └─ REQ-d00011: Multi-Site Schema Implementation        │
│       └─ Implements: REQ-d02001 (generic multi-entity)    │
│    └─ Diary-specific tables: patients, sites, diary_entries│
│                                                             │
│  (Add "See: prd-event-sourcing-system.md" references)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Why This Structure Works

### Generic Layer (prd-event-sourcing-system.md)

**Purpose**: Describe event-sourcing architecture in app-agnostic terms

**Content Sources**:
- Preamble from prd-flutter-event-sourcing.md (before REQ-p01000)
- All REQ-p01000-p01019 requirements (de-fluttered)

**Key Characteristics**:
- No Flutter/mobile-specific language
- No diary/clinical trial terminology
- Pure event-sourcing patterns and capabilities
- Could apply to ANY event-sourced application

**Example Transformations**:
```
BEFORE: "The Flutter Event Sourcing Module is a reusable Dart/Flutter package..."
AFTER:  "The Event Sourcing System is a reusable software module..."

BEFORE: "Events defined as strongly-typed Dart classes"
AFTER:  "Events defined as strongly-typed data structures"

BEFORE: "Flutter Application Layer"
AFTER:  "Application Layer"
```

### Diary Layer (prd-database.md, etc.)

**Purpose**: Refine generic patterns for clinical diary use case

**Content**:
- Keep existing files mostly as-is
- Add "Implements: REQ-p01XXX" links
- Add "See: prd-event-sourcing-system.md" cross-references
- Focus on diary-specific aspects (patients, sites, investigators)

**What NOT to Repeat**:
- Generic event-sourcing concepts (already in generic layer)
- CQRS patterns (already in generic layer)
- Offline queue architecture (already in generic layer)

**What TO Add**:
- Clinical trial context
- FDA compliance specifics
- Multi-site organization
- Patient enrollment workflows
- Investigator roles

---

## Implementation Using Tools

### Step 1: Extract Everything

```bash
# Extract all requirements and preambles from relevant files
python3 tools/extract_requirements.py \
    spec/prd-flutter-event-sourcing.md \
    spec/prd-database.md \
    spec/prd-database-event-sourcing.md
```

**Output**:
```
untracked-notes/extracted-reqs/
├── prd-flutter-event-sourcing_preamble.md  ← The gold!
├── REQ-p01000.md
├── REQ-p01001.md
├── ... (REQ-p01000 through REQ-p01019)
├── prd-database_preamble.md
├── REQ-p00003.md
├── REQ-p00013.md
├── prd-database-event-sourcing_preamble.md
├── REQ-p00004.md
└── MANIFEST.md
```

### Step 2: Transform to Generic

```bash
# De-flutter all REQ-p01000-p01019
python3 tools/transform_requirements.py --deflutter
```

**What This Does**:
- Replaces "Flutter" → "application"
- Replaces "Dart classes" → "strongly-typed data structures"
- Replaces "mobile" → "client"
- Updates titles and content throughout

**Also transform the preamble**:
```bash
# Manually edit prd-flutter-event-sourcing_preamble.md
# Change title: "Flutter Event Sourcing Module" → "Event Sourcing System"
# Remove Flutter-specific references
```

### Step 3: Update Implements Links

```bash
# Update diary requirements to implement generic ones
python3 tools/transform_requirements.py \
    --update-implements REQ-p00003:REQ-p01010

python3 tools/transform_requirements.py \
    --update-implements REQ-p00013:REQ-p01003

python3 tools/transform_requirements.py \
    --update-implements REQ-p00004:REQ-p01003
```

### Step 4: Create Recombination Config

```bash
# Generate template
python3 tools/recombine_requirements.py --create-config
```

**Edit** `untracked-notes/refactor-config.json`:

```json
{
  "output_dir": "spec-refactored",
  "files": [
    {
      "filename": "prd-event-sourcing-system.md",
      "description": "Generic event-sourcing system (was prd-flutter-event-sourcing.md)",
      "preamble": "prd-flutter-event-sourcing_preamble.md",
      "requirements": [
        "REQ-p01000", "REQ-p01001", "REQ-p01002", "REQ-p01003",
        "REQ-p01004", "REQ-p01005", "REQ-p01006", "REQ-p01007",
        "REQ-p01008", "REQ-p01009", "REQ-p01010", "REQ-p01011",
        "REQ-p01012", "REQ-p01013", "REQ-p01014", "REQ-p01015",
        "REQ-p01016", "REQ-p01017", "REQ-p01018", "REQ-p01019"
      ],
      "custom_sections": [
        "## References\n\n- **Diary Implementation**: prd-database.md\n- **Event Sourcing Pattern**: prd-database-event-sourcing.md\n- **Development Guide**: dev-event-sourcing-postgres.md (to be created)\n- **Operations Guide**: ops-event-sourcing-deployment.md (to be created)"
      ]
    },
    {
      "filename": "prd-database.md",
      "description": "Diary-specific database PRD (keep mostly as-is)",
      "preamble": "prd-database_preamble.md",
      "requirements": [
        "REQ-p00003",
        "REQ-p00013"
      ],
      "custom_sections": [
        "## Generic Architecture\n\nThis document describes the diary-specific implementation of the event-sourcing system.\n\n**See**: prd-event-sourcing-system.md for generic event sourcing architecture and capabilities."
      ]
    },
    {
      "filename": "prd-database-event-sourcing.md",
      "description": "Keep as-is with cross-reference",
      "preamble": "prd-database-event-sourcing_preamble.md",
      "requirements": [
        "REQ-p00004"
      ],
      "custom_sections": [
        "## Generic Patterns\n\n**See**: prd-event-sourcing-system.md for complete event sourcing architecture patterns.\n\nThis document focuses on FDA 21 CFR Part 11 compliance aspects specific to clinical trials."
      ]
    }
  ]
}
```

### Step 5: Recombine Into New Structure

```bash
python3 tools/recombine_requirements.py \
    --config untracked-notes/refactor-config.json
```

**Output**:
```
spec-refactored/
├── prd-event-sourcing-system.md     ← Generic (was prd-flutter-event-sourcing.md)
├── prd-database.md                   ← Diary refinement (updated)
└── prd-database-event-sourcing.md    ← Diary refinement (updated)
```

### Step 6: Review and Validate

```bash
# Check the refactored files
diff -u spec/prd-flutter-event-sourcing.md spec-refactored/prd-event-sourcing-system.md

# Validate requirements
python3 tools/requirements/validate_requirements.py

# Check that all REQ-IDs preserved
grep -h "^### REQ-" spec-refactored/*.md | sort
```

### Step 7: Replace Original Files

```bash
# Once reviewed and validated:
mv spec/prd-flutter-event-sourcing.md spec/prd-flutter-event-sourcing.md.backup
mv spec-refactored/prd-event-sourcing-system.md spec/
mv spec-refactored/prd-database.md spec/prd-database.md.new

# Compare and merge manually
# Then commit
```

---

## Detailed Comparison

### BEFORE (Current State)

**spec/prd-flutter-event-sourcing.md**:
```markdown
# Flutter Event Sourcing Module

The Flutter Event Sourcing Module is a reusable Dart/Flutter package...

### REQ-p01000: Event Sourcing Client Interface
The module SHALL provide a type-safe client interface...

- Events defined as strongly-typed Dart classes
- Automatic JSON serialization/deserialization

### REQ-p01001: Offline Event Queue with Automatic Synchronization
The module SHALL queue events locally when network unavailable...

- Events stored in local persistent storage (SQLite/Hive)
```

**Problem**: File name and content suggest Flutter-specific, but it's really generic architecture

### AFTER (Refactored)

**spec/prd-event-sourcing-system.md** (new name):
```markdown
# Event Sourcing System

The Event Sourcing System is a reusable software module...

### REQ-p01000: Event Sourcing Client Interface
The system SHALL provide a type-safe client interface...

- Events defined as strongly-typed data structures
- Automatic JSON serialization/deserialization

### REQ-p01001: Offline Event Queue with Automatic Synchronization
The system SHALL queue events locally when network unavailable...

- Events stored in local persistent storage
```

**Result**: Generic, reusable, applicable to any event-sourced system

**spec/prd-database.md** (updated):
```markdown
# Clinical Trial Database Architecture

> **See**: prd-event-sourcing-system.md for generic event sourcing patterns

## Executive Summary

The database stores patient diary entries with complete history...

### REQ-p00003: Separate Database Per Sponsor
**Level**: PRD | **Implements**: REQ-p01010 | **Status**: Active

Each pharmaceutical sponsor SHALL operate an independent database instance...

(Refines REQ-p01010 multi-tenancy for clinical trial sponsor isolation)

### REQ-p00013: Complete Data Change History
**Level**: PRD | **Implements**: REQ-p01003 | **Status**: Active

The system SHALL preserve the complete history of all data modifications...

(Refines REQ-p01003 immutable events for clinical trial audit requirements)
```

**Result**: Focused on diary-specific refinements, references generic foundation

---

## Validation Checklist

- [ ] All REQ-IDs preserved (p01000-p01019, p00003, p00013, p00004)
- [ ] No Flutter/Dart references in prd-event-sourcing-system.md
- [ ] Preamble from prd-flutter-event-sourcing.md used in new generic file
- [ ] Diary files add "Implements: REQ-p01XXX" links
- [ ] Diary files add "See: prd-event-sourcing-system.md" cross-references
- [ ] Diary files don't repeat generic content
- [ ] `validate_requirements.py` passes
- [ ] Traceability matrix still valid
- [ ] prd-database.md content mostly preserved (it was perfect!)

---

## Benefits of This Approach

1. **Clear Separation**: Generic system architecture vs. diary-specific refinement
2. **Reusability**: prd-event-sourcing-system.md can be used for other apps
3. **No Repetition**: Diary docs reference generic, don't duplicate
4. **REQ Preservation**: All IDs unchanged, traceability maintained
5. **Package Path**: Generic layer ready for extraction as standalone docs
6. **Better Naming**: "Event Sourcing System" clearer than "Flutter Event Sourcing Module"

---

## What Each File Contains

### prd-event-sourcing-system.md (Generic)

**Purpose**: Architecture and capabilities of event-sourcing system

**Audience**: Anyone implementing event-sourced applications

**Content**:
- Architecture diagrams
- CQRS patterns
- Event store concepts
- Materialized views
- Offline queue architecture
- Conflict resolution
- Real-time subscriptions
- All REQ-p01000-p01019 (de-fluttered)

**Does NOT Contain**:
- Flutter/Dart/mobile specifics
- Clinical trial context
- Diary schema
- Patient/site concepts

### prd-database.md (Diary Refinement)

**Purpose**: Executive summary of diary database

**Audience**: Stakeholders, product managers

**Content**:
- Clinical diary context
- REQ-p00003: Separate DB per sponsor (refines multi-tenancy)
- REQ-p00013: Complete change history (refines immutable events)
- Multi-site organization
- Patient data protection

**Does NOT Repeat**:
- Generic event sourcing concepts (references prd-event-sourcing-system.md)
- CQRS architecture (already in generic)

### prd-database-event-sourcing.md (Diary Refinement)

**Purpose**: Event sourcing with FDA context

**Audience**: Compliance, regulators

**Content**:
- REQ-p00004: Audit trail (refines immutable events + FDA)
- FDA 21 CFR Part 11 compliance
- ALCOA+ principles
- Clinical trial audit requirements

**Does NOT Repeat**:
- Generic event sourcing mechanics (references prd-event-sourcing-system.md)

---

## Migration Path

### Phase 1: Preparation (This Plan)
- Create extraction/transformation/recombination tools ✅
- Analyze current structure ✅
- Plan new structure ✅

### Phase 2: Execution (Next Steps)
1. Extract all requirements and preambles
2. De-flutter REQ-p01000-p01019
3. Update "Implements" links
4. Recombine into new structure
5. Review spec-refactored/ output

### Phase 3: Validation
1. Manual review of all changes
2. Run validate_requirements.py
3. Check traceability matrix
4. Get stakeholder approval

### Phase 4: Deployment
1. Replace original files
2. Update cross-references throughout docs
3. Commit with detailed message
4. Update any external documentation

---

## Success Criteria

1. ✅ prd-event-sourcing-system.md is 100% app-agnostic (no Flutter/diary refs)
2. ✅ All REQ-IDs preserved (p01000-p01019, p00003, p00013, p00004)
3. ✅ Diary files focused on refinements, not repetition
4. ✅ Cross-references correct (diary → generic)
5. ✅ Validation tools pass
6. ✅ Clearer documentation structure
7. ✅ Foundation for package extraction

---

## Tools Summary

Created three Python tools in `tools/`:

1. **extract_requirements.py** - Extract REQs and preambles to individual files
2. **transform_requirements.py** - De-flutter, update implements, rename
3. **recombine_requirements.py** - Combine REQs back into spec files per config

These tools enable safe, auditable refactoring without information loss.

---

## Conclusion

The key insight: **prd-flutter-event-sourcing.md was never really a Flutter module spec - it's the generic event-sourcing system architecture that accidentally had Flutter in the name.**

Refactoring correctly positions this as:
- **Generic Layer**: prd-event-sourcing-system.md (architecture, reusable)
- **Diary Layer**: prd-database.md + prd-database-event-sourcing.md (refinements)

Tools are ready. Waiting for approval to execute.
