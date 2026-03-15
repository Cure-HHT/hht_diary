# Questionnaire Architecture: Separate-Repo-Per-Questionnaire

**Version**: 2.0
**Date**: 2026-03-15
**Status**: Proposal

---

## Summary

Each questionnaire is split into two distinct pieces: the **widget** (Flutter UI code, scoring logic, layout) and the **data** (question text, response labels, preamble, translations). The widget is an independent Dart/Flutter package compiled into the app at build time. The data is served at runtime by the sponsor's portal — the same portal that is already a separate binary per sponsor.

The mobile app is a single "pluripotent" binary with all questionnaire widgets compiled in. After sponsor selection, the app downloads the questionnaire data from that sponsor's portal, receiving the approved, audited content in the correct language. Content updates (wording, translations) deploy through the portal without an app store release.

---

## Core Principles

1. **Widget / data split** — each questionnaire is cleanly separated into compiled UI code (widget) and server-delivered content (data). The widget knows *how* to render; the data knows *what* to render.
2. **One repo per questionnaire** — each questionnaire (NOSE HHT, QoL, EQ, future instruments) lives in its own Git repo with its own version history, CI, and release cycle.
3. **Build-time composition for widgets** — the diary app's `pubspec.yaml` lists questionnaire widget packages as dependencies. They compile into a single binary.
4. **Runtime data delivery from sponsor portal** — after sponsor selection, the app fetches questionnaire data from the sponsor's portal. The portal serves the approved, audited, correctly-translated content.
5. **Single store listing** — one app binary on iOS App Store and Google Play. No flavors, no per-sponsor store entries. The pluripotent binary serves all sponsors; the portal determines content.

---

## What Is a "Widget" vs. "Data"

### Widget (compiled into app binary)

The widget package contains everything that requires an app store release to change:

- **Flutter UI components** — screens, layouts, input controls, animations
- **Scoring algorithm** — how responses are computed into scores
- **Schema definition** — the structural contract (field names, types, validation rules)
- **Flow logic** — question ordering, skip logic, session management
- **GUI version constant** — tracks presentation changes

The widget knows: "this questionnaire has 3 categories, category 1 has 6 questions with a 5-point scale, and scoring sums all values."

### Data (served by sponsor portal at runtime)

The data payload contains everything that can change without an app store release:

- **Question text** — the actual wording shown to the patient
- **Response labels** — "No problem", "Mild problem", etc.
- **Preamble / instructions** — introductory text shown before questions
- **Category names and stems** — "Physical", "Please rate how severe..."
- **Translations** — all of the above in each enabled language
- **Content version** — tracks which approved revision of the text this is

The data knows: "question 1 says 'Blood running down the back of your throat' and in Spanish it says '...'"

### Why This Split Works

The widget defines the *shape* of the data it expects (a schema contract). The portal serves data that conforms to that shape. As long as the contract is satisfied, either side can evolve independently:

- **Wording fix?** Update data in the portal. No app release.
- **New translation?** Add language to portal. No app release.
- **New question added to instrument?** Update both widget (schema) and portal (data). App release required.
- **UI redesign?** Update widget only. App release required.

---

## Repository Structure

### Questionnaire Package Repo (e.g. `questionnaire-nose-hht`)

This is the **widget** — compiled into the app.

```
questionnaire-nose-hht/
├── lib/
│   ├── src/
│   │   ├── schema.dart             # Schema contract: field names, types, validation
│   │   ├── scorer.dart             # Scoring algorithm
│   │   ├── flow_screen.dart        # Questionnaire flow (or uses shared flow)
│   │   └── version.dart            # Schema version + GUI version constants
│   └── questionnaire_nose_hht.dart # Barrel export
├── test/
│   ├── schema_test.dart            # Validates data payloads against schema
│   └── scorer_test.dart            # Scoring algorithm tests
├── pubspec.yaml                     # Package metadata + version
├── CHANGELOG.md
└── README.md
```

Note: **no question text, no translations, no JSON definitions** — those live in the portal.

### Questionnaire Data (served by sponsor portal)

This is the **data** — fetched at runtime after sponsor selection.

```
# In sponsor portal repo (already separate per sponsor)
portal/
├── questionnaire_data/
│   ├── nose_hht/
│   │   ├── v2.1/                    # Matches widget schema version
│   │   │   ├── en-US.json          # English content
│   │   │   ├── es-MX.json          # Spanish content
│   │   │   └── manifest.json       # Content version, approved languages, audit metadata
│   ├── hht_qol/
│   │   ├── v1.0/
│   │   │   ├── en-US.json
│   │   │   └── manifest.json
│   └── eq/
│       └── v1.0/
│           ├── en-US.json
│           └── manifest.json
```

### Diary App `pubspec.yaml`

```yaml
dependencies:
  # Core platform
  clinical_diary_core: ^1.0.0

  # Questionnaire widget packages — each is its own repo
  questionnaire_nose_hht: ^2.1.0    # Widget only — UI, scoring, schema
  questionnaire_qol: ^1.3.0
  questionnaire_eq: ^1.0.0
  # Future questionnaires added here as new dependencies
```

Adding a new questionnaire = adding one line to `pubspec.yaml` + deploying data to the portal.

---

## Versioning Model

The widget/data split maps naturally onto the three-layer versioning model:

| Layer | Lives in | Changes require |
|-------|----------|-----------------|
| **Schema version** | Widget package (compiled) | App store release |
| **GUI version** | Widget package (compiled) | App store release |
| **Content version** | Portal data (served at runtime) | Portal deployment only |

### Widget Package Version (pubspec.yaml)

Follows semver. Covers schema and GUI changes.

- **Major**: Breaking schema change (restructured categories, removed questions, changed scoring)
- **Minor**: Backward-compatible schema addition (new optional field)
- **Patch**: GUI-only fix (layout tweak, animation improvement)

### Content Version (in portal data manifest)

Follows semver independently. Covers text and translation changes.

- **Major**: Structural content change (reworded question that changes clinical meaning)
- **Minor**: New language added
- **Patch**: Typo fix, wording clarification, translation correction

### Version Constants

```dart
// In questionnaire_nose_hht/lib/src/version.dart (compiled into app)
class NoseHhtVersion {
  static const schemaVersion = '2.1';     // Schema contract version
  static const guiVersion = '3.0';        // Presentation version
  static const packageVersion = '2.1.0';  // Matches pubspec.yaml
}
```

```json
// In portal: questionnaire_data/nose_hht/v2.1/manifest.json (served at runtime)
{
  "questionnaire_id": "nose_hht",
  "schema_version": "2.1",
  "content_version": "2.1.3",
  "approved_languages": ["en-US", "es-MX"],
  "approved_at": "2026-03-10T14:30:00Z",
  "approved_by": "clinical-review-board"
}
```

### Schema Contract Enforcement

The widget declares the schema version it expects. The portal data declares the schema version it conforms to. The app validates compatibility at data-fetch time:

```dart
// At runtime, after fetching data from portal
if (fetchedData.schemaVersion != NoseHhtVersion.schemaVersion) {
  // Schema mismatch — data doesn't match what this widget expects
  // Log error, show user-friendly message, prevent questionnaire from launching
}
```

### Response Storage

Every response records all three layers — two from the compiled widget, one from the portal-served data:

```json
{
  "versioned_type": "nose-hht-v2.1",
  "widget_package_version": "2.1.0",
  "schema_version": "2.1",
  "gui_version": "3.0",
  "content_version": "2.1.3",
  "localization": {
    "language": "es-MX",
    "translation_version": "1.2"
  },
  "responses": [...]
}
```

---

## Data Flow: Sponsor Selection → Questionnaire Data

### Sequence

1. **User selects sponsor** (or sponsor is determined by enrollment)
2. **App calls sponsor portal**: `GET /api/v1/questionnaires/data?lang=es-MX`
3. **Portal returns** questionnaire data for all enabled questionnaires, in the requested language, at the current approved content version
4. **App validates** schema version compatibility between widget and data
5. **App caches** the data locally for offline use
6. **Registry is populated** — widgets are matched with their data

### What the Portal Serves

```json
// GET /api/v1/questionnaires/data?lang=es-MX
{
  "questionnaires": [
    {
      "id": "nose_hht",
      "schema_version": "2.1",
      "content_version": "2.1.3",
      "language": "es-MX",
      "session_config": {
        "readiness_check": true,
        "readiness_message": "Este cuestionario toma aproximadamente 10-12 minutos...",
        "estimated_minutes": "10-12",
        "session_timeout_minutes": 30,
        "timeout_warning_minutes": 5
      },
      "preamble": [
        {"id": "nose_preamble_1", "content": "Puntuación Nasal de Resultado para Epistaxis en..."}
      ],
      "categories": [
        {
          "id": "physical",
          "name": "Físico",
          "stem": "Califique la gravedad de los siguientes problemas debido a sus hemorragias nasales:",
          "response_scale": [
            {"value": 0, "label": "Sin problema"},
            {"value": 1, "label": "Problema leve"},
            {"value": 2, "label": "Problema moderado"},
            {"value": 3, "label": "Problema severo"},
            {"value": 4, "label": "Lo peor posible"}
          ],
          "questions": [
            {"id": "nose_physical_1", "number": 1, "text": "Sangre que baja por la parte posterior de su garganta", "required": true}
          ]
        }
      ]
    },
    {
      "id": "hht_qol",
      "schema_version": "1.0",
      "content_version": "1.0.1",
      "language": "es-MX",
      "categories": [...]
    }
  ],
  "sponsor_config": {
    "enabled_questionnaires": ["nose_hht", "hht_qol", "eq"],
    "settings": {
      "nose_hht": {"frequency": "on_demand", "required": false},
      "hht_qol": {"frequency": "on_demand", "required": false},
      "eq": {"frequency": "daily", "required": true, "study_start_gate": true}
    }
  }
}
```

The sponsor portal already exists as a separate binary per sponsor. It already manages sponsor-specific configuration. Now it also manages the approved, audited questionnaire content — a natural extension of its existing role.

### Offline / Caching

- Data is cached locally after first fetch
- Cache is keyed by `(questionnaire_id, schema_version, content_version, language)`
- App can function offline using cached data
- On each app launch (when online), the app checks for updated content versions and refreshes the cache if newer data is available
- Stale cache is acceptable — the response records the content version used, so traceability is maintained regardless

---

## Questionnaire Registry

The registry maps questionnaire IDs to their compiled widget implementations. Each widget package registers itself. The registry is later hydrated with portal-served data.

```dart
// In core platform
abstract class QuestionnaireWidget {
  String get id;
  String get schemaVersion;
  String get guiVersion;
  String get packageVersion;

  /// Validates that portal-served data is compatible with this widget's schema
  bool isCompatible(QuestionnaireData data);

  /// Builds the questionnaire flow using the portal-served data for content
  Widget buildFlow({
    required QuestionnaireData data,       // From portal (text, labels, translations)
    required QuestionnaireFlowContext context,
  });
}

// Registry
class QuestionnaireRegistry {
  static final Map<String, QuestionnaireWidget> _widgets = {};

  static void register(QuestionnaireWidget widget) {
    _widgets[widget.id] = widget;
  }

  static QuestionnaireWidget? get(String id) => _widgets[id];

  /// Returns widgets that have both:
  /// 1. A compiled widget in the binary
  /// 2. Compatible data from the portal
  /// 3. Are enabled in the sponsor config
  static List<HydratedQuestionnaire> getAvailable(
    SponsorConfig config,
    Map<String, QuestionnaireData> portalData,
  ) {
    return config.enabledQuestionnaireIds
        .map((id) {
          final widget = _widgets[id];
          final data = portalData[id];
          if (widget == null || data == null) return null;
          if (!widget.isCompatible(data)) return null;
          return HydratedQuestionnaire(widget: widget, data: data);
        })
        .whereType<HydratedQuestionnaire>()
        .toList();
  }
}
```

### Widget Registration (in each questionnaire package)

```dart
// questionnaire_nose_hht/lib/questionnaire_nose_hht.dart
class NoseHhtWidget implements QuestionnaireWidget {
  @override String get id => 'nose_hht';
  @override String get schemaVersion => '2.1';
  @override String get guiVersion => '3.0';
  @override String get packageVersion => '2.1.0';

  @override
  bool isCompatible(QuestionnaireData data) {
    return data.schemaVersion == schemaVersion;
  }

  @override
  Widget buildFlow({
    required QuestionnaireData data,
    required QuestionnaireFlowContext context,
  }) {
    return QuestionnaireFlowScreen(
      data: data,        // Portal-served text, labels, translations
      scorer: NoseHhtScorer(),  // Compiled scoring algorithm
      context: context,
    );
  }
}
```

### App Initialization

```dart
void main() {
  // 1. Register all compiled-in questionnaire widgets
  QuestionnaireRegistry.register(NoseHhtWidget());
  QuestionnaireRegistry.register(QolWidget());
  QuestionnaireRegistry.register(EqWidget());

  // 2. App starts → user selects sponsor → fetch data from sponsor portal
  // 3. Registry hydrates widgets with portal data
  // 4. Only show questionnaires that are enabled + compatible + have data
  runApp(ClinicalDiaryApp());
}
```

---

## Release Workflow

### Content-Only Change (No App Release)

Example: Clinical team requests a wording change to NOSE HHT question 5.

1. Update question text in the portal's `questionnaire_data/nose_hht/v2.1/en-US.json`
2. Bump `content_version` in manifest (`2.1.3` → `2.1.4`)
3. Clinical review and approval (audit trail in portal)
4. Deploy to sponsor portal
5. App picks up new content on next launch — **no app store release needed**

### Translation Update (No App Release)

Example: Add Spanish translation for QoL questionnaire.

1. Add `es-MX.json` to the portal's `questionnaire_data/hht_qol/v1.0/`
2. Update manifest to include `es-MX` in approved languages
3. Clinical review of translation
4. Deploy to sponsor portal
5. App fetches new language on next launch

### Schema / UI Change (App Release Required)

Example: A new validated version of NOSE HHT adds 2 questions to the Physical category.

1. Update widget package: new schema version, updated scorer, UI adjustments
2. Bump widget package major/minor version (e.g., `2.1.0` → `2.2.0`)
3. In portal: create new `v2.2/` data directory with updated content
4. Update diary app `pubspec.yaml` to `questionnaire_nose_hht: ^2.2.0`
5. App CI builds, tests, deploys to TestFlight / Play Internal
6. Portal serves `v2.2` data to apps that request schema `2.2`, continues serving `v2.1` to older app versions

### Adding a New Questionnaire

1. Create new widget repo `questionnaire-new-instrument`
2. Implement widget package (UI, scoring, schema)
3. Add widget dependency to diary app `pubspec.yaml`
4. Add registration call in `main.dart`
5. Deploy questionnaire data to sponsor portal(s)
6. Enable in sponsor config
7. App release + portal deployment

---

## Accepted Trade-offs

### All Questionnaire Widgets Compiled In

Every widget package in `pubspec.yaml` ships in every binary. A sponsor who only uses EQ still has the NOSE HHT and QoL *widgets* in their binary — but never receives the *data* to activate them.

**Why this is acceptable:**
- Widget packages are small (kilobytes of Dart code — no content, no translations)
- Binary size impact is negligible
- Simplifies build pipeline (one binary, not N)
- Single store listing eliminates app management overhead
- Without portal-served data, a widget is inert — it has no text, no labels, nothing to display
- The portal only serves data for questionnaires the sponsor has enabled
- Defense in depth: widget + data + sponsor config must all align for a questionnaire to appear

### Portal as Content Authority

The sponsor portal becomes the single source of truth for questionnaire content. This is a natural fit because:
- The portal is already a separate binary per sponsor
- The portal already manages sponsor-specific configuration
- Clinical review and approval workflows already exist in the portal context
- Content versioning and audit trails are a portal responsibility

### Requires Network for First Use

The app cannot present a questionnaire until it has fetched data from the portal at least once. After the initial fetch, cached data supports offline use. This is acceptable because:
- Sponsor selection (which triggers the fetch) already requires network
- Clinical enrollment workflows already assume connectivity
- Cache refresh is opportunistic — stale content is still valid and traceable

---

## FDA / Compliance Considerations

| Concern | How Addressed |
|---------|---------------|
| **Traceability** | Widget package version (schema + GUI) + portal content version + language — all stored with every response |
| **Reproducibility** | `pubspec.lock` pins widget versions; portal manifests pin content versions; git tags on both |
| **Audit trail** | Unchanged — event sourcing captures all interactions; portal adds content approval audit trail |
| **Validation** | Widget packages have schema tests; portal validates content against schema; diary app has integration tests |
| **Change control** | Widget changes = PRs in widget repo + app repo. Content changes = PRs in portal repo. Separate review tracks. |
| **ALCOA+** | Response records all three version layers + exact language used. Content served by portal is approved and audited. |
| **Content integrity** | Portal serves only clinically-approved content. Content version in response proves which approved text the patient saw. |

---

## Migration Path from Current System

1. **Split `questionnaires.json`** — separate widget concerns (schema, structure) from data concerns (text, labels, translations)
2. **Extract widgets** — move each questionnaire's UI, scoring, and schema into its own package repo
3. **Deploy data to portal** — load the question text, labels, and translations into the sponsor portal's data directory
4. **Add portal endpoint** — `GET /api/v1/questionnaires/data` serves the content for enabled questionnaires
5. **Update app** — replace `QuestionnaireService.loadDefinitions()` (JSON asset) with registry + portal fetch
6. **Add schema validation** — widget validates portal data matches expected schema version
7. **Add caching** — local cache of portal data for offline support
8. **Remove bundled `questionnaires.json`** — content now comes from portal
9. No database migration needed — response format adds fields but is backward compatible
