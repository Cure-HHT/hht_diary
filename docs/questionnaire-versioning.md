# Questionnaire Versioning Implementation Guide

**Version**: 2.0
**Last Updated**: 2026-03-04
**Status**: Draft

## Related Requirements

This document provides implementation guidance not covered by the requirement assertions:

- **REQ-p01051**: Questionnaire Versioning Model (three-layer model, immutability)
- **REQ-p01052**: Questionnaire Localization and Translation Tracking
- **REQ-p01053**: Sponsor Questionnaire Eligibility Configuration
- **REQ-d00107**: Questionnaire Response Collection and Storage
- **REQ-d80064**: Questionnaire Version Integrity Enforcement

> For the normative requirements (what the system SHALL do), see the REQs above.
> This document provides implementation guidance -- architectural patterns, data formats, and
> workflow suggestions. It is not prescriptive: alternative approaches that satisfy the
> referenced requirements are equally valid.

---

## Version Dimension Ownership

Each versioning dimension has a different owner and change cadence:

| Layer | Owner | Typical Change Trigger |
| ----- | ----- | ---------------------- |
| **Schema** | Engineering | Fields added/removed, types changed |
| **Content** | Clinical/Scientific | Wording clarified, questions refined |
| **GUI** | Product/UX | UI redesigned, accessibility improved |

---

## Response Storage Format

Concrete example of a versioned questionnaire response event (see `dev-data-models-jsonb.md` for the base `EventRecord` structure):

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
        "response_displayed": "Ocurrio durante el ejercicio",
        "translation_method": "auto"
      }
    ],
    "lastModified": "2025-01-15T10:00:00-05:00"
  }
}
```

### Response Field Reference

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `versioned_type` | string | Yes | Schema version (e.g., "nose-hht-v2.1") |
| `content_version` | string | Yes | Content/wording version (e.g., "2.1.3") |
| `gui_version` | string | Yes | Presentation version (e.g., "3.0") |
| `localization.language` | string | Yes | BCP 47 language tag (e.g., "es-MX") |
| `localization.translation_version` | string | Yes | Translation version for that language |
| `responses[].question_id` | string | Yes | Stable question identifier |
| `responses[].response_canonical` | any | Yes | Normalized value for analysis (REQ-p01052-F) |
| `responses[].response_displayed` | any | No | Value as shown to patient (REQ-p01052-E) |
| `responses[].translation_method` | string | No | "auto", "manual", or "verified" (REQ-p01052-G) |

Values must be human-readable strings, not numeric codes (REQ-d00107-L).

---

## Sponsor Configuration Format

Sponsors pin all three version dimensions plus language settings (REQ-p01053):

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

free_text_handling:
  store_original: true
  auto_translate: true
  require_verification: false
```

### Configuration Field Reference

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `id` | string | Yes | Unique questionnaire identifier |
| `display_name` | string | Yes | Human-readable name |
| `schema_version` | string | Yes | Current schema version for new entries (REQ-p01053-D) |
| `min_schema_version` | string | No | Minimum acceptable version for historical data (REQ-p01053-E) |
| `content_version` | string | Yes | Current content version |
| `gui_version` | string | Yes | Current GUI version |
| `frequency` | enum | Yes | "daily", "weekly", "on_demand" |
| `required` | boolean | Yes | Whether completion is mandatory |
| `enabled_languages` | array | Yes | Available language configurations (REQ-p01053-C) |
| `enabled_languages[].language` | string | Yes | BCP 47 language tag |
| `enabled_languages[].translation_version` | string | Yes | Translation version |
| `enabled_languages[].is_source` | boolean | Yes | Whether this is the source language (REQ-p01052-D) |

---

## Application Behavior

### Startup Flow

1. Load sponsor configuration from environment
2. Fetch questionnaire configuration for sponsor
3. Download questionnaire definitions for enabled types
4. Download GUI assets for configured gui_versions
5. Cache translation resources for enabled languages

All definitions and assets must be available offline after startup (REQ-p00006-E).

### New Entry Creation

1. User selects entry type (e.g., epistaxis diary)
2. App looks up current versions from sponsor config (REQ-p01053-H)
3. App determines user's language preference (REQ-p01052-I)
4. Load questionnaire definition for content_version
5. Load translation for user's language and translation_version
6. Render using specified gui_version
7. On save, record all version identifiers (REQ-p01051-J/K/L)

### Viewing Historical Entries

1. Read stored version identifiers from response
2. If content_version matches current: use current definitions
3. If content_version older: load archived definition for display
4. Render using appropriate GUI (current or compatible)

This enables the reconstruction guarantees in REQ-p01051-M/N.

---

## GUI Version Code Organization

REQ-p01065-B requires questionnaires to be coded Flutter components. REQ-p01051-T requires deployed versions to be immutable. Together these mean GUI versions are frozen widget snapshots organized as isolated directory trees.

### Directory Structure

```text
questionnaire/
  der/                          # Daily Epistaxis Record
    gui/
      v1_0/
        der_page.dart           # Original layout
        der_widgets.dart
      v1_1/
        der_page.dart           # Redesigned layout
        der_widgets.dart
    der_factory.dart            # Picks version from sponsor config
```

A factory reads the sponsor's pinned GUI version (REQ-p01053-D) and returns the corresponding widget tree. Old versions are never modified -- they are frozen artifacts. New versions are created by copying and modifying the prior version.

### Shared Infrastructure Boundary

Not everything is versioned. The boundary:

| Versioned (inside `gui/vX_Y/`) | Unversioned (outside) |
| --- | --- |
| Widget layout and composition | Navigation flow |
| Visual styling and spacing | Submission pipeline |
| Interaction patterns (tap targets, gestures) | Accessibility infrastructure |
| Version-specific animations | Error handling |

Shared infrastructure lives outside the versioned directories so that bug fixes and platform updates apply to all versions without modifying frozen artifacts.

### Self-Containment at Lock Time

When a GUI version is locked, its dependency on shared code must be managed:

- **Option A: Copy in.** Copy any shared utilities into the version directory at lock time. Full isolation -- the hash covers everything the version needs.
- **Option B: Semver boundary.** Shared infrastructure maintains its own semver contract with tests. Locked versions depend on a stable API rather than specific code.

Option A is safer for regulatory purposes (the locked hash covers the complete artifact). Option B is more practical for shared infrastructure that evolves frequently. The choice should be made per-component based on how tightly coupled it is to the versioned presentation.

---

## Version Locking System

REQ-d80064 assertions E-L define what the locking system must do. This section describes how.

### Lifecycle

```text
Development          Locking              Post-Lock
+-----------+       +-----------+        +-----------+
| Edit code |       | GH Action |        | CI rejects|
| freely    | ----> | computes  | -----> | any change|
| no hash   |       | hash, adds|        | to locked |
|           |       | to table  |        | version   |
+-----------+       +-----------+        +-----------+
```

### Lock Table Format

A single append-only file (`questionnaire-locks.json`) at the repository root:

```json
{
  "locks": [
    {
      "questionnaire": "der",
      "dimension": "gui",
      "version": "1.0",
      "hash": "sha256:a1b2c3d4...",
      "locked_at": "2026-03-04T12:00:00Z",
      "locked_by": "CUR-1057",
      "paths": [
        "apps/questionnaire/der/gui/v1_0/**"
      ]
    },
    {
      "questionnaire": "der",
      "dimension": "content",
      "version": "1.0",
      "hash": "sha256:e5f6a7b8...",
      "locked_at": "2026-03-04T12:00:00Z",
      "locked_by": "CUR-1057",
      "paths": [
        "apps/questionnaire/der/content/v1_0.yaml"
      ]
    }
  ]
}
```

Fields map to REQ-d80064 assertion K: questionnaire type, dimension, version identifier, hash, and covered paths. The `locked_at` and `locked_by` fields provide audit context.

### Hash Algorithm

The hash must be deterministic and reproducible on any checkout:

1. Expand the glob patterns in `paths`
2. Sort the resulting file list lexicographically
3. For each file: `sha256(relative_path + "\0" + file_contents)`
4. Concatenate all per-file hashes in sorted order
5. `sha256(concatenated)` = the lock hash

Including the relative path in each per-file hash means renaming a file breaks the lock (desired behavior). The Merkle-style structure allows pinpointing which file changed when a lock check fails.

### CI Validation: Two-Check Structure

**Check 1: Locked content integrity** (implements REQ-d80064-F).
For each entry in `questionnaire-locks.json`, recompute the hash from the files on disk. If the hash differs from the recorded value, fail with a message directing the developer to create a new version instead.

**Check 2: Lock table is append-only** (implements REQ-d80064-G/H/I/J).
Compare `questionnaire-locks.json` in the PR against the same file on the base branch (main). Reject the PR if any existing entry is modified or removed. Only appending new entries is permitted. Branch protection on main is the trust anchor.

### Locking GitHub Action

A GitHub Action (triggered via `workflow_dispatch`) performs the locking:

1. Accept inputs: `questionnaire`, `dimension` (gui/content/schema), `version`, `ticket`
2. Validate that the version directory/files exist
3. Compute the hash using the algorithm above
4. Verify the version is not already locked (fail if so)
5. Append the new entry to `questionnaire-locks.json`
6. Open a PR for review of the new lock entry

### Handling Bugs in Locked Versions

A locked version is never unlocked or modified. If a bug is found:

1. Create a new version (e.g., v1.0.1) with the fix
2. Update the sponsor configuration to point to the new version (REQ-p01053-D)
3. Lock the new version
4. The old lock entry remains as a historical record

This preserves REQ-p01051-T (deployed versions are immutable).

### Schema Dimension Specifics

For the schema dimension, the locked artifact includes:

- The JSON Schema definition for that version's JSONB structure
- The migration function from the prior version (REQ-d80064-L)

The migration function is part of the locked contract. Changing how v1-to-v2 migrates after locking would silently alter how historical data is interpreted, violating the reconstruction guarantees in REQ-p01051-M/N.

---

## References

- **spec/dev-data-models-jsonb.md**: JSONB schema documentation (base EventRecord structure)
- **spec/prd-event-sourcing-system.md**: REQ-p01051 (Versioning Model), REQ-p01052 (Localization)
- **spec/prd-questionnaire-system.md**: REQ-p01065 (Clinical Questionnaire System)
- **spec/dev-questionnaire.md**: REQ-d80064 (Version Integrity Enforcement)
- **spec/dev-diary-app-linking.md**: REQ-d00107 (Response Collection and Storage)
