# Questionnaire Architecture Comparison

**Date**: 2026-03-15
**Version**: 2.0
**Purpose**: Compare the current monolithic questionnaire architecture with the proposed widget/data split approach.

---

## Architecture Overview

| Aspect | Current (Monolithic) | Proposed (Widget/Data Split) |
|--------|---------------------|------------------------------|
| **Where UI code lives** | Shared Flutter screens in `apps/common-flutter/eq/` | Each questionnaire is a separate widget package in its own Git repo |
| **Where content lives** | Single `questionnaires.json` bundled as an app asset | Served at runtime by the sponsor's portal (already a separate binary per sponsor) |
| **How UI gets into the app** | Hard-coded screens compiled into the monorepo | Widget packages declared in `pubspec.yaml`, compiled into a single binary |
| **How content gets into the app** | Bundled JSON loaded at runtime by `QuestionnaireService` | Fetched from sponsor portal after sponsor selection |
| **How versions are tracked** | Three-layer model (schema/content/GUI) as metadata in the JSON file | Schema + GUI versions in compiled widget; content version in portal-served data |
| **How sponsors configure** | `sponsor/{id}/config/questionnaires.yaml` (planned, not yet implemented) | Portal serves only enabled questionnaires with approved content in the correct language |
| **How content updates deploy** | Modify `questionnaires.json`, rebuild app, app store release | Update portal data, deploy portal — no app store release needed |
| **How new questionnaires are added** | Add to `questionnaires.json`, add UI code, update `QuestionnaireType` enum | Create widget package repo, add to `pubspec.yaml`, deploy data to portal |

---

## Detailed Comparison

### 1. Code Organization

**Current**: Questionnaire logic is spread across multiple locations in the monorepo:
- Definitions: `apps/common-dart/trial_data_types/assets/data/questionnaires.json`
- Data models: `apps/common-dart/trial_data_types/lib/src/questionnaire_*.dart`
- UI flow: `apps/common-flutter/eq/lib/src/` (shared across all questionnaires)
- Service: `apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart`
- Type enum: `apps/common-dart/trial_data_types/lib/src/questionnaire_type.dart`

Adding or modifying a questionnaire touches files in 3-5 different directories within the monorepo. Content and code are interleaved in the same repo.

**Proposed**: Clean separation across three locations:
- **Widget package** (own repo): Schema, scoring, UI — compiled into app
- **Portal data** (sponsor portal repo): Question text, labels, translations — served at runtime
- **Core platform** (main repo): Shared flow screen, registry, data-fetch logic

Content changes happen in the portal. Code changes happen in widget repos. The diary app repo only changes when adding a new questionnaire or updating widget versions.

### 2. Versioning & Change Control

**Current**:
- Three independent version numbers (schema, content, GUI) managed manually in one place
- All three must be coordinated — there's no single "questionnaire version" for dependency resolution
- A content-only change (typo fix) requires updating `questionnaires.json`, rebuilding the app, and an app store release
- No built-in mechanism to pin "which exact questionnaire version does this app build contain?"

**Proposed**:
- Three-layer versioning is preserved but split by ownership:
  - Schema + GUI versions → in widget package (semver, `pubspec.lock`)
  - Content version → in portal data manifest (semver, portal audit trail)
- Content-only changes (wording, translations) deploy through the portal — no app release
- `pubspec.lock` pins widget versions deterministically
- Portal manifests pin content versions with clinical approval metadata
- Every response records all three layers, proving exactly what the patient saw

### 3. Release Independence

**Current**:
- All questionnaires are versioned together in the monorepo
- A change to NOSE HHT question wording requires a commit to the main repo, rebuild, and app store release
- No way to release-manage questionnaires independently
- Changelog for questionnaire changes is mixed in with platform changes

**Proposed**:
- **Content changes don't require app releases.** The portal is deployed independently.
- Widget packages have their own release cycles, CHANGELOGs, and git tags
- Clinical team can update question wording or add translations through the portal without touching app code
- A Spanish translation can go live the same day it's approved — no app review queue
- Schema/UI changes still require an app release, but these are rare compared to content changes

### 4. Testing

**Current**:
- Questionnaire definition tests live in `trial_data_types/test/`
- UI tests live in `common-flutter/eq/test/`
- All tests run together — a broken test in one questionnaire blocks the entire CI

**Proposed**:
- Each questionnaire package has its own test suite and CI pipeline
- Questionnaire-specific tests run in isolation
- Diary app integration tests verify the composed result
- A broken test in NOSE HHT doesn't block QoL development

### 5. Team Workflow

**Current**:
- Everyone works in the same monorepo
- Questionnaire content changes go through the same PR process as platform features
- Clinical team changes are interleaved with engineering changes in the commit history
- A wording fix requires a developer to modify JSON, open a PR, wait for CI, merge, build, release

**Proposed**:
- Three distinct workflows with clear ownership:
  - **Clinical team** owns portal content — question text, translations, approval
  - **Questionnaire developers** own widget packages — UI, scoring, schema
  - **Platform team** owns the diary app — registry, data-fetch, integration
- Content reviews (clinical) and code reviews (engineering) are separate processes
- Clinical team can deploy content changes through the portal without developer involvement
- The portal already has its own access controls per sponsor

### 6. Binary Size & Content Delivery

**Current**:
- All questionnaire JSON (text, labels, translations for all questionnaires) bundled in the app asset
- JSON is loaded and parsed at runtime
- Minimal impact on binary size (JSON is small)
- Every language for every questionnaire ships in every binary

**Proposed**:
- Widget packages (Dart code only, no text content) compiled into the binary — even smaller per-questionnaire footprint
- Content downloaded from portal only for the questionnaires and languages the sponsor needs
- A Spanish-only deployment never downloads English content; a sponsor using only EQ never receives NOSE HHT text
- Widgets without matching portal data are inert — no UI, no entry points

### 7. Sponsor Configuration & Language Delivery

**Current** (as designed, not yet implemented):
- `questionnaires.yaml` per sponsor declares enabled questionnaires with specific versions
- All languages for all questionnaires ship in the binary
- Language selection is a client-side concern

**Proposed**:
- The sponsor portal is the single authority for "what questionnaires are enabled" and "what languages are available"
- The portal serves content in the requested language — the approved, audited translation
- Adding a new language = deploying a new JSON file to the portal. No app release.
- Version management is split: widget versions in `pubspec.lock`, content versions in portal manifests
- No version mismatch possible — the widget validates the portal data's schema version at fetch time

---

## Risk Comparison

| Risk | Current | Proposed |
|------|---------|----------|
| **Version drift** | Three independent versions managed manually; can get out of sync | Schema+GUI pinned in `pubspec.lock`; content version pinned in portal manifest; natural separation |
| **Content-code mismatch** | JSON content and Dart code can diverge silently | Widget validates portal data against its schema version at fetch time — mismatches caught immediately |
| **Accidental breakage across questionnaires** | One bad commit can break all questionnaires | Isolation — each widget repo has independent CI; portal data is per-questionnaire |
| **Stale content** | JSON bundled at build time; typo fix requires app release | Portal serves current content; updates deploy independently of app store cycle |
| **Reproducibility** | Requires tracking three version numbers per questionnaire per build | `pubspec.lock` for widgets + portal manifest versions for content; response records prove both |
| **Operational complexity** | One repo to manage | Multiple widget repos + portal data management (mitigated by clear conventions) |
| **Requires network** | Content available offline (bundled) | Requires initial portal fetch; cached after that for offline use |
| **Portal availability** | N/A — no portal dependency for content | If portal is unreachable and no cache exists, questionnaire cannot launch (mitigated by caching) |

---

## What Stays the Same

Both architectures share these fundamentals — they are not affected by the architecture choice:

- **FDA compliance model** — event sourcing, ALCOA+, audit trails
- **Three-layer version traceability** — schema, content, GUI versions stored with every response
- **Questionnaire lifecycle** — Not Sent → Sent → In Progress → Ready to Review → Finalized
- **Investigator approval workflow** — unchanged
- **Session management** — readiness gate, timeouts
- **Single store listing** — one app binary on each platform
- **RLS-based access control** — database policies unchanged
- **Soft-delete pattern** — unchanged
- **Scoring algorithms** — same logic, just lives in the widget package instead of shared code

---

## What Changes for the Better

The widget/data split specifically improves on pain points in the current architecture:

| Pain Point | Current | Proposed |
|------------|---------|----------|
| Typo in question text | Modify JSON → rebuild → app store release (days/weeks) | Update portal data → deploy portal (minutes/hours) |
| Add Spanish translation | Add to bundled JSON → rebuild → release | Add `es-MX.json` to portal → deploy |
| Clinical team wants to review wording | Must access monorepo, find JSON file | Reviews content in portal context, familiar tooling |
| "Which version did this patient see?" | Hope the three version numbers were updated correctly | Response records widget version + content version + language; each is independently auditable |
| New sponsor needs subset of questionnaires | Build contains all content for all sponsors | Portal serves only what that sponsor needs; widgets without data are inert |

---

## Recommendation

The widget/data split with separate repos is better suited for this project because:

1. **Content is the most frequent change.** Wording fixes, translations, and clinical revisions should not require app store releases.
2. **The sponsor portal already exists as the right delivery vehicle.** It's already per-sponsor, already manages config, already has access controls.
3. **The three-layer versioning model becomes natural** — schema+GUI live in compiled code, content lives in served data. The split matches how the layers actually evolve.
4. **Clinical teams can own content directly** through the portal, without needing monorepo access or developer involvement for text changes.
5. **Migration is non-disruptive** — response format adds fields but is backward compatible, no database migration needed, and the transition can be done one questionnaire at a time.
