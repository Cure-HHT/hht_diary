# Questionnaire Architecture: Separate-Repo-Per-Questionnaire

**Version**: 1.0
**Date**: 2026-03-15
**Status**: Proposal

---

## Summary

Each questionnaire is an independent Dart/Flutter package in its own Git repository. The diary app composes questionnaires at build time by declaring them as package dependencies. A sponsor configuration file controls which questionnaires are active at runtime, but all questionnaires for a given app build are compiled in — the app is "pluripotent."

---

## Core Principles

1. **One repo per questionnaire** — each questionnaire (NOSE HHT, QoL, EQ, future instruments) lives in its own Git repo with its own version history, CI, and release cycle.
2. **Build-time composition** — the diary app's `pubspec.yaml` lists questionnaire packages as dependencies. `pub get` pulls them in; they compile into a single binary.
3. **Runtime activation via sponsor config** — a sponsor configuration (fetched at startup or bundled) declares which questionnaires are enabled, their version constraints, and per-questionnaire settings. The app only presents activated questionnaires to the user.
4. **Single store listing** — one app binary on iOS App Store and Google Play. No flavors, no per-sponsor store entries. The pluripotent binary serves all sponsors; config determines behavior.

---

## Repository Structure

### Questionnaire Package Repo (e.g. `questionnaire-nose-hht`)

```
questionnaire-nose-hht/
├── lib/
│   ├── src/
│   │   ├── definition.dart         # QuestionnaireDefinition (questions, categories, scales)
│   │   ├── definition.json         # Structured definition data
│   │   ├── scorer.dart             # Scoring algorithm
│   │   ├── flow_screen.dart        # Questionnaire flow (or uses shared flow)
│   │   └── version.dart            # Schema, content, GUI version constants
│   └── questionnaire_nose_hht.dart # Barrel export
├── test/
├── assets/
│   └── translations/               # Per-language translation files
├── pubspec.yaml                     # Package metadata + version
├── CHANGELOG.md
└── README.md
```

### Diary App `pubspec.yaml`

```yaml
dependencies:
  # Core platform
  clinical_diary_core: ^1.0.0

  # Questionnaire packages — each is its own repo
  questionnaire_nose_hht: ^2.1.0
  questionnaire_qol: ^1.3.0
  questionnaire_eq: ^1.0.0
  # Future questionnaires added here as new dependencies
```

Adding a new questionnaire = adding one line to `pubspec.yaml` + a sponsor config update.

---

## Versioning Model

### Package Version (pubspec.yaml `version` field)

Follows semver. This is the **release version** of the questionnaire package and is the single version that matters for dependency resolution.

- **Major**: Breaking changes (schema restructure, removed questions, changed scoring)
- **Minor**: Backward-compatible additions (new optional field, new translation)
- **Patch**: Content fixes (typo correction, wording clarification, GUI polish)

### Three-Layer Traceability (Preserved)

The existing three-layer model (schema / content / GUI) is preserved *inside* each package as metadata constants. Every response record still captures all three layers for ALCOA+ traceability. But the **dependency management** uses only the single semver package version.

```dart
// In questionnaire_nose_hht/lib/src/version.dart
class NoseHhtVersion {
  static const schemaVersion = '2.1';
  static const contentVersion = '2.1.3';
  static const guiVersion = '3.0';
  static const packageVersion = '2.1.3'; // matches pubspec.yaml
}
```

### Response Storage (Unchanged)

```json
{
  "versioned_type": "nose-hht-v2.1",
  "package_version": "2.1.3",
  "content_version": "2.1.3",
  "gui_version": "3.0",
  "localization": {
    "language": "es-MX",
    "translation_version": "1.2"
  },
  "responses": [...]
}
```

---

## Sponsor Configuration

### Fetch Mechanism

On app startup, the app fetches the sponsor config from the backend. The config declares the active questionnaires and their settings.

### Configuration Schema

```yaml
# Fetched from: GET /api/v1/sponsor/config/questionnaires
# Or bundled at: sponsor/{sponsor-id}/config/questionnaires.yaml

sponsor_id: "cure-hht"

questionnaires:
  - id: "nose_hht"
    enabled: true
    frequency: on_demand
    required: false
    session_timeout_minutes: 30
    enabled_languages:
      - language: en-US
        is_source: true
      - language: es-MX
        is_source: false

  - id: "hht_qol"
    enabled: true
    frequency: on_demand
    required: false
    session_timeout_minutes: 30
    enabled_languages:
      - language: en-US
        is_source: true

  - id: "eq"
    enabled: true
    frequency: daily
    required: true
    study_start_gate: true
    enabled_languages:
      - language: en-US
        is_source: true
```

Version constraints are **not** in the sponsor config — they are locked at build time via `pubspec.yaml` and `pubspec.lock`. The sponsor config only controls runtime activation and behavioral settings.

---

## Questionnaire Registry

The app maintains a registry that maps questionnaire IDs to their package implementations. Each questionnaire package registers itself.

```dart
// In core platform
abstract class QuestionnaireRegistryEntry {
  String get id;
  String get displayName;
  QuestionnaireDefinition get definition;
  String get packageVersion;
  String get schemaVersion;
  String get contentVersion;
  String get guiVersion;
  Widget buildFlow(QuestionnaireFlowContext context);
}

// Registry — populated at app startup
class QuestionnaireRegistry {
  static final Map<String, QuestionnaireRegistryEntry> _entries = {};

  static void register(QuestionnaireRegistryEntry entry) {
    _entries[entry.id] = entry;
  }

  static QuestionnaireRegistryEntry? get(String id) => _entries[id];

  static List<QuestionnaireRegistryEntry> getEnabled(SponsorConfig config) {
    return config.questionnaires
        .where((q) => q.enabled)
        .map((q) => _entries[q.id])
        .whereType<QuestionnaireRegistryEntry>()
        .toList();
  }
}
```

### Registration (in each questionnaire package)

```dart
// questionnaire_nose_hht/lib/questionnaire_nose_hht.dart
class NoseHhtRegistration implements QuestionnaireRegistryEntry {
  @override String get id => 'nose_hht';
  @override String get displayName => 'NOSE HHT';
  @override String get packageVersion => NoseHhtVersion.packageVersion;
  // ... other fields ...

  @override
  Widget buildFlow(QuestionnaireFlowContext context) {
    return QuestionnaireFlowScreen(
      definition: definition,
      context: context,
    );
  }
}
```

### App Initialization

```dart
void main() {
  // Register all compiled-in questionnaires
  QuestionnaireRegistry.register(NoseHhtRegistration());
  QuestionnaireRegistry.register(QolRegistration());
  QuestionnaireRegistry.register(EqRegistration());

  // Fetch sponsor config, then only show enabled ones
  runApp(ClinicalDiaryApp());
}
```

---

## Release Workflow

### Updating a Single Questionnaire

1. Clinical team requests a wording change to NOSE HHT question 5
2. Developer updates text in `questionnaire-nose-hht` repo
3. Bumps `contentVersion` and package patch version (e.g., `2.1.3` → `2.1.4`)
4. PR, review, merge, tag `v2.1.4`
5. In diary app repo: update `pubspec.yaml` to `questionnaire_nose_hht: ^2.1.4`
6. App CI builds, tests, deploys to TestFlight / Play Internal

### Adding a New Questionnaire

1. Create new repo `questionnaire-new-instrument`
2. Implement package following the standard structure
3. Add dependency to diary app `pubspec.yaml`
4. Add registration call in `main.dart`
5. Update sponsor config to enable for target sponsors
6. Deploy

### Coordinated Release (Multiple Questionnaires)

When a study protocol change affects multiple instruments:
1. Update each questionnaire repo independently
2. Update diary app `pubspec.yaml` with all new versions
3. Single app release captures all changes
4. `pubspec.lock` provides exact reproducibility

---

## Accepted Trade-offs

### All Questionnaires Compiled In

Every questionnaire package in `pubspec.yaml` ships in every binary, regardless of sponsor config. A sponsor who only uses EQ still has NOSE HHT and QoL code in their binary.

**Why this is acceptable:**
- Questionnaire packages are small (kilobytes of Dart code + JSON definitions)
- Binary size impact is negligible
- Simplifies build pipeline (one binary, not N)
- Single store listing eliminates app management overhead
- Sponsor config controls what users actually see — compiled-in but disabled questionnaires are invisible and unreachable
- No risk of data leakage (disabled questionnaires have no UI entry points, no API calls, no data flow)

### Dependency Coordination

Updating the diary app requires bumping versions in `pubspec.yaml`. This is intentional — it means questionnaire changes don't silently propagate. Every questionnaire version change is an explicit, reviewable commit in the diary app repo.

---

## FDA / Compliance Considerations

| Concern | How Addressed |
|---------|---------------|
| **Traceability** | Package version + three-layer versions stored with every response |
| **Reproducibility** | `pubspec.lock` pins exact versions; git tags on each questionnaire repo |
| **Audit trail** | Unchanged — event sourcing captures all interactions |
| **Validation** | Each questionnaire package has its own test suite; diary app has integration tests |
| **Change control** | Questionnaire changes are isolated PRs in their own repo; diary app update is a separate, reviewable PR |
| **ALCOA+** | Response storage format unchanged; all version metadata preserved |

---

## Migration Path from Current System

1. Extract each questionnaire's definition from `questionnaires.json` into its own package
2. Move questionnaire-specific Flutter UI code into the relevant package (or keep shared flow screen in core)
3. Replace `QuestionnaireService.loadDefinitions()` with registry lookup
4. Update sponsor config fetch to drive the registry filter
5. Remove bundled `questionnaires.json` asset
6. No database migration needed — response format is backward compatible
