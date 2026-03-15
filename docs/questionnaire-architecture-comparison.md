# Questionnaire Architecture Comparison

**Date**: 2026-03-15
**Purpose**: Compare the current monolithic questionnaire architecture with the proposed separate-repo-per-questionnaire approach.

---

## Architecture Overview

| Aspect | Current (Monolithic) | Proposed (Separate Repos) |
|--------|---------------------|--------------------------|
| **Where definitions live** | Single `questionnaires.json` bundled as an app asset | Each questionnaire is an independent Dart package in its own Git repo |
| **How they get into the app** | Hard-coded JSON loaded at runtime by `QuestionnaireService` | Declared as `pubspec.yaml` dependencies, compiled in at build time |
| **How versions are tracked** | Three-layer model (schema/content/GUI) as metadata in the JSON file + versioning doc | Three-layer model preserved inside each package; package semver used for dependency management |
| **How sponsors configure** | `sponsor/{id}/config/questionnaires.yaml` (planned, not yet implemented) | Same sponsor config concept, but version pinning happens in `pubspec.yaml` instead of config |
| **How new questionnaires are added** | Add definition to `questionnaires.json`, add UI code to `apps/common-flutter/eq/`, update `QuestionnaireType` enum | Create new repo, `pub` package, add one line to `pubspec.yaml`, register in `main.dart` |

---

## Detailed Comparison

### 1. Code Organization

**Current**: Questionnaire logic is spread across multiple locations in the monorepo:
- Definitions: `apps/common-dart/trial_data_types/assets/data/questionnaires.json`
- Data models: `apps/common-dart/trial_data_types/lib/src/questionnaire_*.dart`
- UI flow: `apps/common-flutter/eq/lib/src/` (shared across all questionnaires)
- Service: `apps/daily-diary/clinical_diary/lib/services/questionnaire_service.dart`
- Type enum: `apps/common-dart/trial_data_types/lib/src/questionnaire_type.dart`

Adding or modifying a questionnaire touches files in 3-5 different directories within the monorepo.

**Proposed**: Each questionnaire is self-contained in its own package:
- Definition, version constants, scorer, and (optionally) custom UI all live in one repo
- Shared UI flow screen remains in the core platform
- Adding a questionnaire = creating one new repo + one `pubspec.yaml` line

### 2. Versioning & Change Control

**Current**:
- Three independent version numbers (schema, content, GUI) managed manually
- All three must be coordinated — there's no single "questionnaire version" for dependency resolution
- A content-only change (wording fix) still requires updating the monorepo, even though no code changed
- No built-in mechanism to pin "which exact questionnaire version does this app build contain?"

**Proposed**:
- Single semver package version drives dependency resolution
- Three-layer versions preserved as internal metadata for traceability
- `pubspec.lock` provides deterministic, reproducible builds — you always know exactly which questionnaire versions are in a given binary
- Content changes are isolated PRs in the questionnaire repo, then an explicit version bump in the app repo
- Git tags on questionnaire repos provide precise audit trail

### 3. Release Independence

**Current**:
- All questionnaires are versioned together in the monorepo
- A change to NOSE HHT question wording requires a commit to the main repo
- No way to release-manage questionnaires independently
- Changelog for questionnaire changes is mixed in with platform changes

**Proposed**:
- Each questionnaire has its own release cycle, CHANGELOG, and git tags
- Clinical team can own a questionnaire repo's content changes without touching platform code
- NOSE HHT can be at v2.1.4 while QoL is at v1.3.0 — versions are independent
- The diary app explicitly opts in to each version bump

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

**Proposed**:
- Questionnaire repos can have different access controls and review requirements
- Clinical team can have write access to questionnaire repos without needing full platform repo access
- Content reviews (clinical) and code reviews (engineering) happen in separate PRs in separate repos
- Clear ownership boundaries

### 6. Binary Size & Compilation

**Current**:
- All questionnaire JSON definitions bundled in the asset directory
- JSON is loaded and parsed at runtime
- Minimal impact on binary size (JSON is small)

**Proposed**:
- All questionnaire Dart code compiled into the binary
- Slightly larger binary (compiled Dart vs. JSON), but still negligible
- No runtime JSON parsing — definitions are compile-time constants
- All questionnaires ship in every binary regardless of sponsor (accepted trade-off)

### 7. Sponsor Configuration

**Current** (as designed, not yet implemented):
- `questionnaires.yaml` per sponsor declares enabled questionnaires with specific schema, content, and GUI versions
- Config includes version constraints (`min_schema_version`)
- App fetches definitions for the configured versions

**Proposed**:
- Sponsor config is simpler — it only controls enablement and behavioral settings (frequency, timeout, languages)
- Version pinning happens in `pubspec.yaml` / `pubspec.lock`, not in sponsor config
- No version mismatch risk between what the config requests and what's compiled in

---

## Risk Comparison

| Risk | Current | Proposed |
|------|---------|----------|
| **Version drift** | Three independent versions can get out of sync; no single source of truth | Single package version is the source of truth; three-layer versions are derived metadata |
| **Accidental breakage across questionnaires** | One bad commit can break all questionnaires | Isolation — each repo has independent CI |
| **Stale definitions** | JSON definitions can diverge from code expectations | Definition and code are in the same package — they must be consistent |
| **Reproducibility** | Requires tracking three version numbers per questionnaire per build | `pubspec.lock` captures everything deterministically |
| **Operational complexity** | One repo to manage | Multiple repos to manage (mitigated by automation and clear conventions) |
| **All questionnaires in binary** | Same — JSON for all questionnaires is bundled | Same — Dart code for all questionnaires is compiled in |
| **Dependency coordination** | N/A — everything is in-tree | Version bumps in `pubspec.yaml` are explicit but add a step |

---

## What Stays the Same

Both architectures share these fundamentals — they are not affected by the repo structure choice:

- **FDA compliance model** — event sourcing, ALCOA+, audit trails
- **Response storage format** — JSONB with version metadata
- **Three-layer version traceability** — schema, content, GUI versions stored with every response
- **Questionnaire lifecycle** — Not Sent → Sent → In Progress → Ready to Review → Finalized
- **Investigator approval workflow** — unchanged
- **Session management** — readiness gate, timeouts
- **Sponsor config concept** — config determines which questionnaires are active
- **Single store listing** — one app binary on each platform
- **RLS-based access control** — database policies unchanged
- **Soft-delete pattern** — unchanged

---

## Recommendation

The separate-repo architecture is better suited for this project's trajectory because:

1. **Questionnaires are the primary unit of change** in a clinical diary platform. Isolating them reflects how changes actually happen.
2. **Clinical content changes should not require platform PRs.** Separating repos enables clinical teams to own their instruments.
3. **Reproducibility via `pubspec.lock`** is simpler and more robust than manually coordinating three version numbers.
4. **The cost is manageable** — a handful of small repos with clear conventions and automated CI.
5. **Migration is non-disruptive** — response format doesn't change, no database migration needed, and the transition can be done one questionnaire at a time.
