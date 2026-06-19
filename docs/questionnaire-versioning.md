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
| **Content** | Clinical/Scientific | Catalog entry authored or revised through formal validation |
| **Renderer class** | Product/UX (Engineering) | New class added to taxonomy, or existing class version revised |

The "GUI version" recorded on each response (REQ-p01051-L) identifies the renderer class and class version that rendered the questionnaire at the moment of capture. Renderer classes are platform-controlled and may be shared across multiple questionnaires whose catalog entries reference them.

---

## Response Storage Format

Concrete example of a versioned questionnaire response event (see `spec/dev-shared-events-catalog.md` for the base `EventRecord` structure):

```json
{
  "versioned_type": "nose-hht-v2.1",
  "event_data": {
    "content_version": "2.1.3",
    "renderer_class": "standard-survey",
    "renderer_version": "3.0",
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

### Response Field Reference

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `versioned_type` | string | Yes | Schema version (e.g., "nose-hht-v2.1") |
| `content_version` | string | Yes | Catalog entry content version (e.g., "2.1.3") |
| `renderer_class` | string | Yes | Renderer class identifier from the closed taxonomy (e.g., "standard-survey") |
| `renderer_version` | string | Yes | Renderer class version actually used to render (e.g., "3.0") |
| `localization.language` | string | Yes | BCP 47 language tag (e.g., "es-MX") |
| `localization.translation_version` | string | Yes | Translation version for that language |
| `responses[].question_id` | string | Yes | Stable question identifier |
| `responses[].response_canonical` | any | Yes | Normalized value for analysis (REQ-p01052-F) |
| `responses[].response_displayed` | any | No | Value as shown to participant (REQ-p01052-E) |
| `responses[].translation_method` | string | No | "auto", "manual", or "verified" (REQ-p01052-G) |

The `renderer_class` + `renderer_version` pair together satisfy REQ-p01051-L (record the GUI version identifier).

Values must be human-readable strings, not numeric codes (REQ-d00107-L).

---

## Sponsor Configuration Format

Sponsor configuration is purely selection: enable a catalog entry, allow languages, set frequency. Catalog entry content (questions, options, scoring) is not customizable by the sponsor (REQ-p01065-O).

```yaml
# sponsor/{sponsor-id}/config/questionnaires.yaml

enabled_questionnaires:
  - catalog_id: epistaxis-daily
    catalog_version: "1.0.0"
    min_catalog_version: "1.0.0"
    frequency: daily
    required: true

    enabled_languages:
      - language: en-US
        translation_version: "1.0"
        is_source: true
      - language: es-MX
        translation_version: "1.2"
        is_source: false

  - catalog_id: nose-hht
    catalog_version: "2.1.3"
    min_catalog_version: "2.0.0"
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
| `catalog_id` | string | Yes | Catalog entry identifier (e.g., "nose-hht"); resolves to a catalog entry whose content, schema, and renderer binding are pinned by `catalog_version` |
| `catalog_version` | string | Yes | Pinned catalog entry version for new entries (REQ-p01053-D). The catalog entry itself encodes the schema, content, and renderer-class binding. |
| `min_catalog_version` | string | No | Minimum acceptable catalog entry version for historical data (REQ-p01053-E) |
| `frequency` | enum | Yes | "daily", "weekly", "on_demand" |
| `required` | boolean | Yes | Whether completion is mandatory |
| `enabled_languages` | array | Yes | Available language configurations (REQ-p01053-C) |
| `enabled_languages[].language` | string | Yes | BCP 47 language tag |
| `enabled_languages[].translation_version` | string | Yes | Translation version |
| `enabled_languages[].is_source` | boolean | Yes | Whether this is the source language (REQ-p01052-D) |

A catalog entry version (e.g., `nose-hht v2.1.3`) is the unit of selection. The catalog entry pins `schema_version`, `content_version`, `renderer_class`, and `min_renderer_version` internally; sponsors do not pin these dimensions independently. This collapses the previous separate `schema_version` / `content_version` / `gui_version` selection knobs into a single `catalog_version` selection.

---

## Application Behavior

### Startup Flow

1. Load sponsor configuration from environment
2. Resolve enabled catalog entries: for each `(catalog_id, catalog_version)`, locate the bundled catalog entry
3. Cache translation bundles for enabled languages
4. Resolve renderer class bindings: for each catalog entry, identify the renderer class and verify the bundled renderer class version is >= the catalog entry's `min_renderer_version`

All catalog entries, translations, and renderer classes are bundled with the application; offline availability is automatic (REQ-p00006-E).

### New Entry Creation

1. User selects entry type (e.g., epistaxis diary)
2. App resolves the catalog entry from sponsor config (REQ-p01053-H)
3. App determines user's language preference (REQ-p01052-I)
4. Load translation for user's language at the configured translation_version
5. Render using the renderer class pinned by the catalog entry, at the bundled renderer class version
6. On save, record `versioned_type`, `content_version`, `renderer_class`, `renderer_version`, and localization fields (REQ-p01051-J/K/L)

### Viewing Historical Entries

1. Read stored version identifiers from response
2. Locate the catalog entry version that produced the response
3. Locate the renderer class version that rendered it; render via that version (or a compatible later version) using the same content
4. Use the recorded translation_version to display question text in the participant's original language

This enables the reconstruction guarantees in REQ-p01051-M/N.

---

## Catalog and Renderer Class Organization

REQ-p01065 (assertions A-O) defines questionnaires as bespoke catalog entries rendered by a closed taxonomy of renderer classes. REQ-p01051-T requires deployed versions to be immutable. Together these mean the locked artifacts are catalog entry JSON files and renderer class source bundles, not per-questionnaire widget directories.

### Directory Structure

```text
catalog/
  questionnaires/                              # one subdirectory per questionnaire
    der/                                       # Daily Epistaxis Record
      v1_0_0.json                              # catalog entry: content + renderer binding
      v1_1_0.json                              # later catalog version
    nose-hht/
      v2_1_3.json
    qol/
      v1_0_0.json
  translations/                                # one subdirectory per (questionnaire, language)
    nose-hht/
      es-MX_v1_2.json
      fr-FR_v1_1.json
  renderer-classes/                            # closed taxonomy
    standard-survey/                           # generic preamble + categories + scaled responses
      v3_0/
        renderer.dart
      v3_1/
        renderer.dart
    epistaxis-diary/                           # bespoke renderer (single-member class)
      v1_0/
        renderer.dart
```

A catalog entry JSON file is a self-contained validated artifact. It declares the schema_version, content_version, renderer_class, and min_renderer_version, plus the questionnaire content (questions, options, scoring, recall period, preamble). Translations are independent JSON files referenced by `(questionnaire, language, translation_version)`.

Renderer classes belong to a closed platform taxonomy. A class may have many catalog entries pointing at it (e.g. `standard-survey` renders both NOSE HHT and QoL) or just one (e.g. a bespoke class like `epistaxis-diary`). Adding a new renderer class requires a platform-level requirement amendment (REQ-p01065-L).

### Catalog Entry Schema (sketch)

```json
{
  "catalog_id": "nose-hht",
  "catalog_version": "2.1.3",
  "schema_version": "2.1",
  "content_version": "2.1.3",
  "renderer_class": "standard-survey",
  "min_renderer_version": "3.0",
  "validation_provenance": {
    "source": "JAMA Otolaryngol Head Neck Surg. 2020;146(11):999-1005",
    "validated_at": "2024-08-12",
    "ticket": "CUR-NNNN"
  },
  "content": {
    "preamble": [...],
    "categories": [...],
    "scoring": {...},
    "recall_period": "2 weeks"
  }
}
```

The catalog entry version follows the convention `{schema_version}.{content_revision}` -- e.g. `2.1.3` is content revision 3 within schema 2.1. A new schema version starts a new minor (`2.2.0`) or major (`3.0.0`) line.

### Renderer Class Compatibility

A renderer class advertises a semver contract. The catalog entry pins `min_renderer_version`; the runtime selects the bundled renderer class version that satisfies it. Renderer class versions within the same major are forward-compatible by definition: bumping `standard-survey` from v3.0 to v3.1 (e.g., accessibility improvement) does not require revising any catalog entry. Bumping to v4.0 (breaking presentation change) requires updating each catalog entry's `min_renderer_version` -- which produces a new catalog entry version, not a silent change.

This separation is what lets the renderer evolve independently of validated content while preserving REQ-p01051-T immutability: each rendered view is fully described by `(catalog_version, renderer_class, renderer_version, translation_version)`, all four recorded on every response.

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

A single append-only file (`questionnaire-locks.json`) at the repository root. Locked units fall into three kinds: catalog entries, translation bundles, and renderer class versions.

```json
{
  "locks": [
    {
      "kind": "catalog_entry",
      "catalog_id": "nose-hht",
      "catalog_version": "2.1.3",
      "hash": "sha256:a1b2c3d4...",
      "locked_at": "2026-03-04T12:00:00Z",
      "locked_by": "CUR-1057",
      "paths": [
        "catalog/questionnaires/nose-hht/v2_1_3.json"
      ]
    },
    {
      "kind": "translation",
      "catalog_id": "nose-hht",
      "language": "es-MX",
      "translation_version": "1.2",
      "hash": "sha256:e5f6a7b8...",
      "locked_at": "2026-03-10T12:00:00Z",
      "locked_by": "CUR-NNNN",
      "paths": [
        "catalog/translations/nose-hht/es-MX_v1_2.json"
      ]
    },
    {
      "kind": "renderer_class",
      "renderer_class": "standard-survey",
      "renderer_version": "3.0",
      "hash": "sha256:9c8d7e6f...",
      "locked_at": "2026-03-04T12:00:00Z",
      "locked_by": "CUR-1057",
      "paths": [
        "catalog/renderer-classes/standard-survey/v3_0/**"
      ]
    }
  ]
}
```

Fields map to REQ-d80064 assertion K. The `locked_at` and `locked_by` fields provide audit context; `kind` discriminates the locked artifact type. Catalog entries and translations are typically single-file locks; renderer class locks cover a directory tree (renderer class source plus any class-private utilities).

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

1. Accept inputs: `kind` (catalog_entry / translation / renderer_class), identifying fields (e.g. `catalog_id` + `catalog_version`, or `renderer_class` + `renderer_version`), `ticket`
2. Validate that the artifact files exist at the expected paths
3. Compute the hash using the algorithm above
4. Verify the artifact is not already locked (fail if so)
5. Append the new entry to `questionnaire-locks.json`
6. Open a PR for review of the new lock entry

The lock PR is the point at which clinical sign-off is recorded. A reviewer with clinical authority approves the lock, and engineering approves the mechanical correctness of the bundled artifact.

### Handling Bugs in Locked Artifacts

A locked artifact is never unlocked or modified. If a bug is found:

1. Create a new version of the artifact (e.g., catalog entry v2.1.4, or renderer class v3.1) with the fix
2. Lock the new version
3. Update the sponsor configuration (for catalog entries) or update affected catalog entries' `min_renderer_version` (for renderer class fixes that require pin updates) and lock the resulting catalog entry revisions
4. The old lock entry remains as a historical record

This preserves REQ-p01051-T (deployed versions are immutable).

### Schema Dimension Specifics

The `schema_version` is encoded in the catalog entry. When a catalog entry version bumps the schema version, the locked catalog entry includes:

- The JSON Schema definition for that version's JSONB structure (embedded or referenced)
- The migration function from the prior schema version (REQ-d80064-L)

The migration function is part of the locked contract. Changing how v1-to-v2 migrates after locking would silently alter how historical data is interpreted, violating the reconstruction guarantees in REQ-p01051-M/N.

---

## References

- **spec/dev-shared-events-catalog.md**: JSONB schema documentation (base EventRecord structure)
- **spec/prd-questionnaire-versioning.md**: REQ-p01051 (Versioning Model), REQ-p01052 (Localization)
- **spec/prd-questionnaire-management.md**: REQ-p01065 (Clinical Questionnaire System)
- **spec/prd-device-linking.md**: REQ-d00107 (Response Collection and Storage)
