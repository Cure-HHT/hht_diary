# Phase 1 review follow-up round 2

**Date:** 2026-04-21 (same day as round 1)
**Status:** COMPLETE

Second round of review-driven changes, applied on top of the round-1 state captured in `PHASE1_REVIEW_FOLLOWUP.md` and folded into the same squashed Phase 1 commit.

## Items implemented

### 1. `Map.unmodifiable` / `List.unmodifiable` on parsed EntryTypeDefinition fields

`apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart` — `fromJson` now wraps the parsed `widgetConfig` with `Map<String, Object?>.unmodifiable(...)` and the parsed `destinationTags` with `List<String>.unmodifiable(...)`. Runtime callers that receive an `EntryTypeDefinition` from `fromJson` cannot mutate its internal collections in place, matching the unmodifiable pattern established by `appendHop`.

The `const` constructor path is untouched: callers passing `const {'key': 'val'}` literals already get effectively-immutable collections (mutating a const map throws). Wrapping inside the constructor body would have required dropping `const`, which breaks ~8 test-site `const EntryTypeDefinition(...)` uses and the `prefer_const_constructors` lint. Wrapping at the JSON boundary catches the case the reviewer was concerned about (runtime-origin maps) without surrendering the const-friendly value-type contract.

### 2. CHANGELOG note: `toJson` emits null keys for optional fields

Both `CHANGELOG.md` files updated. The wire contract distinguishes *absent-because-null* (the key is present with `null` value) from *absent-because-missing* (the key is not in the map at all). This is a deliberate behavioral choice covered by the existing tests (`REQ-d00115-C: toJson emits snake_case keys including null transform_version`, `REQ-d00116-F,G: toJson emits null for absent effective_date_path and destination_tags`) that was not previously flagged in the changelog. Round-tripping a JSON payload from a different producer that omits these keys works too — `fromJson` defaults them — but when this package emits, it emits the explicit null.

### 3. Regex now leading-anchored to a digit via lookbehind

`apps/common-dart/provenance/lib/src/provenance_entry.dart` — `_offsetPattern` changed from `(Z|[+-]\d{2}(:?\d{2})?)$` to `(?<=\d)(Z|[+-]\d{2}(:?\d{2})?)$`. The positive lookbehind requires the offset marker to immediately follow a digit, so a pathological payload like `"foo+0500"` fails at the regex step with the `ProvenanceEntry`-specific error message rather than relying on `DateTime.parse` to catch it with a more generic one.

`DateTime.parse` still rejects such inputs as a second line of defense, so this is a clarity improvement rather than a correctness fix.

### 4. Remove empty `dependencies:` key from `provenance/pubspec.yaml`

The trailing empty `dependencies:` key with no children is unnecessary — pubspec treats no-key and empty-key identically, and `dart pub get` does not complain, but the key adds visual noise. Removed.

## Verification

| Command | Result |
| --- | --- |
| `(cd apps/common-dart/provenance && dart pub get)` | Resolved; no direct runtime deps |
| `(cd apps/common-dart/provenance && dart test)` | 31 tests pass |
| `(cd apps/common-dart/provenance && dart analyze)` | No issues found |
| `(cd apps/common-dart/trial_data_types && dart test)` | 54 tests pass |
| `(cd apps/common-dart/trial_data_types && dart analyze)` | No issues found |

## Task complete

All Phase 1 review items from both rounds resolved or accepted. Ready to re-squash and force-push.
