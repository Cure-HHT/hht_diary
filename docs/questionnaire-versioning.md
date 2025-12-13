# Questionnaire Versioning Implementation Guide

**Version**: 1.0
**Last Updated**: 2025-01-15
**Status**: Draft

## Related Requirements

This document provides implementation details for:
- **REQ-p01051**: Questionnaire Versioning Model
- **REQ-p01052**: Questionnaire Localization and Translation Tracking
- **REQ-p01053**: Sponsor Questionnaire Eligibility Configuration

---

## Overview

The questionnaire versioning system uses a three-layer model where schema, content, and presentation evolve independently. This enables clinical teams to refine question wording, UX teams to improve presentation, and engineering to modify data structures—all without forcing unnecessary changes to the other layers.

---

## Three-Layer Version Model

### Layer Definitions

| Layer | Purpose | Changes When | Owner |
| ----- | ------- | ------------ | ----- |
| **Schema Version** | JSONB structure, field types, validation | Fields added/removed, types changed | Engineering |
| **Content Version** | Question text, labels, help text, scoring | Wording clarified, questions refined | Clinical/Scientific |
| **GUI Version** | Presentation, layout, widgets, UX | UI redesigned, accessibility improved | Product/UX |

### Version Independence Examples

**Scenario 1: Wording Clarification**
```
Before: content_version: "2.1.2"
Change: "How severe was your nosebleed?" → "Rate the severity (1-6 scale)"
After:  content_version: "2.1.3"

Schema: unchanged
GUI: unchanged
Migration: none required
```

**Scenario 2: UI Redesign**
```
Before: gui_version: "2.0"
Change: Complete visual overhaul for accessibility
After:  gui_version: "3.0"

Schema: unchanged
Content: unchanged
Migration: none required
```

**Scenario 3: Add Optional Field**
```
Before: schema nose-hht-v2.1
Change: Add optional "treatment_used" field
After:  schema nose-hht-v2.2

Content: may need update for new question
GUI: may need update for new field
Migration: backward compatible (field optional)
```

---

## Data Model

### Response Storage Structure

```json
{
  "versioned_type": "nose-hht-v2.1",
  "event_data": {
    "content_version": "2.1.3",
    "gui_version": "3.0",
    "localization": {
      "language": "es-MX",
      "translation_version": "1.2"
    },
    "completedAt": "2025-01-15T10:00:00-05:00",
    "responses": [
      {
        "question_id": "severity",
        "response_canonical": "moderate",
        "response_displayed": "moderada"
      },
      {
        "question_id": "notes",
        "response_canonical": "Occurred during exercise",
        "response_displayed": "Ocurrió durante el ejercicio",
        "translation_method": "auto"
      }
    ],
    "lastModified": "2025-01-15T10:00:00-05:00"
  }
}
```

### Field Definitions

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `versioned_type` | string | Yes | Schema version (e.g., "nose-hht-v2.1") |
| `content_version` | string | Yes | Content/wording version (e.g., "2.1.3") |
| `gui_version` | string | Yes | Presentation version (e.g., "3.0") |
| `localization.language` | string | Yes | BCP 47 language tag (e.g., "es-MX") |
| `localization.translation_version` | string | Yes | Translation version for that language |
| `responses[].question_id` | string | Yes | Stable question identifier |
| `responses[].response_canonical` | any | Yes | Normalized value for analysis |
| `responses[].response_displayed` | any | No | Value as shown to patient (if different) |
| `responses[].translation_method` | string | No | "auto", "manual", or "verified" |

---

## Localization Model

### Version Hierarchy

```
Schema: nose-hht-v2.1
    │
Content: 2.1.3 (English source)
    │
    ├── Translation: en-US v1.0 (source)
    ├── Translation: es-MX v1.2
    ├── Translation: fr-FR v1.1
    └── Translation: de-DE v1.0
```

### Translation Independence

Translations version independently from the source content:

```yaml
# Source content updated
content_version: "2.1.3" → "2.1.4"  # English wording improved

# Translations may lag behind
translations:
  en-US: "1.0"      # Updated with source
  es-MX: "1.2"      # Still based on 2.1.3, update pending
  fr-FR: "1.2"      # Updated to match 2.1.4
```

### Response Types

**Enum/Choice Questions**
```json
{
  "question_id": "severity",
  "response_canonical": "moderate",
  "response_displayed": "moderada"
}
```

**Free-Text Questions**
```json
{
  "question_id": "notes",
  "response_canonical": "Occurred during exercise",
  "response_displayed": "Ocurrió durante el ejercicio",
  "translation_method": "auto"
}
```

**Translation Methods**

| Method | Description |
| ------ | ----------- |
| `auto` | Machine translated, not verified |
| `manual` | Human translated |
| `verified` | Machine translated, human verified |

---

## Sponsor Configuration Schema

### Configuration File Structure

```yaml
# sponsor/{sponsor-id}/config/questionnaires.yaml

enabled_questionnaires:
  - id: epistaxis-daily
    display_name: "Daily Nosebleed Diary"
    schema_version: "1.0"
    content_version: "1.0.0"
    gui_version: "1.0"
    frequency: daily
    required: true

    enabled_languages:
      - language: en-US
        translation_version: "1.0"
        is_source: true
      - language: es-MX
        translation_version: "1.2"
        is_source: false

  - id: nose-hht
    display_name: "NOSE HHT Questionnaire"
    schema_version: "2.1"
    min_schema_version: "2.0"
    content_version: "2.1.3"
    gui_version: "3.0"
    frequency: on_demand
    required: false

    enabled_languages:
      - language: en-US
        translation_version: "1.0"
        is_source: true
      - language: es-MX
        translation_version: "1.2"
        is_source: false
      - language: fr-FR
        translation_version: "1.1"
        is_source: false

# Free-text handling configuration
free_text_handling:
  store_original: true
  auto_translate: true
  require_verification: false
```

### Configuration Field Definitions

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `id` | string | Yes | Unique questionnaire identifier |
| `display_name` | string | Yes | Human-readable name |
| `schema_version` | string | Yes | Current schema version for new entries |
| `min_schema_version` | string | No | Minimum acceptable version for historical data |
| `content_version` | string | Yes | Current content version |
| `gui_version` | string | Yes | Current GUI version |
| `frequency` | enum | Yes | "daily", "weekly", "on_demand" |
| `required` | boolean | Yes | Whether completion is mandatory |
| `enabled_languages` | array | Yes | Available language configurations |
| `enabled_languages[].language` | string | Yes | BCP 47 language tag |
| `enabled_languages[].translation_version` | string | Yes | Translation version |
| `enabled_languages[].is_source` | boolean | Yes | Whether this is the source language |

---

## Application Behavior

### Startup Flow

1. Load sponsor configuration from environment
2. Fetch questionnaire configuration for sponsor
3. Download questionnaire definitions for enabled types
4. Download GUI assets for configured gui_versions
5. Cache translation resources for enabled languages

### New Entry Creation

1. User selects entry type (e.g., epistaxis diary)
2. App looks up current versions from sponsor config
3. App determines user's language preference
4. Load questionnaire definition for content_version
5. Load translation for user's language and translation_version
6. Render using specified gui_version
7. On save, record all version identifiers

### Viewing Historical Entries

1. Read stored version identifiers from response
2. If content_version matches current: use current definitions
3. If content_version older: load archived definition for display
4. Render using appropriate GUI (current or compatible)

---

## Validation Rules

### Schema Validation

- `versioned_type` must exist in event type registry
- `versioned_type` must be within sponsor's min/max version range
- All required fields present per schema definition
- Field types match schema specification

### Content Validation

- `content_version` must exist for this questionnaire type
- All responses have valid `question_id` per content definition
- Enum responses match allowed values for that content version

### Localization Validation

- `language` must be in sponsor's enabled languages
- `translation_version` must exist for that language
- `response_displayed` present when language differs from source

---

## Migration Considerations

### Schema Migrations

Required when:
- Adding required fields
- Changing field types
- Restructuring data

Not required when:
- Adding optional fields
- Changing content/wording only
- Changing GUI only

### Backward Compatibility

- Old schema versions remain valid for historical data
- New entries use current schema version
- Reading old data: validate against stored version's rules
- Queries may need version-aware logic

---

## ALCOA+ Compliance

| Principle | Implementation |
| --------- | -------------- |
| **Attributable** | Patient ID, device ID, timestamps |
| **Legible** | `response_displayed` preserves what patient saw |
| **Contemporaneous** | `completedAt` captures entry time |
| **Original** | Original response stored, not just canonical |
| **Accurate** | Validation enforces data quality |
| **Complete** | All version identifiers stored |
| **Consistent** | Translation versions ensure consistent presentation |
| **Enduring** | Immutable audit trail in event store |
| **Available** | All versions archived, reconstructable |

---

## References

- **REQ-p01050**: Event Type Registry
- **REQ-p01051**: Questionnaire Versioning Model
- **REQ-p01052**: Questionnaire Localization and Translation Tracking
- **REQ-p01053**: Sponsor Questionnaire Eligibility Configuration
- **spec/dev-data-models-jsonb.md**: JSONB schema documentation
- **spec/prd-event-sourcing-system.md**: Event sourcing requirements
