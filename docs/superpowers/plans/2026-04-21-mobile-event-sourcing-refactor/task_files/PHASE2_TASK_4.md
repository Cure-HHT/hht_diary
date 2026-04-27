# Phase 2 Task 4: Refactor Event schema — add entry_type, drop server_timestamp

**Date:** 2026-04-21
**Status:** COMPLETE

## Scope delta from plan

The plan's Files list named only `event_repository.dart` and its test file.
In practice, making `entryType` a required named argument on
`EventRepository.append()` requires updating every existing call site so
Dart doesn't reject the build. Four call sites updated:

1. `apps/daily-diary/clinical_diary/lib/services/nosebleed_service.dart:190`
   — record nosebleed / no-nosebleed / unknown-day; `entryType: 'epistaxis_event'`.
2. `nosebleed_service.dart:268` — record nosebleed deletion (still the same
   entry kind: `epistaxis_event`).
3. `nosebleed_service.dart:514` — pull from cloud on startup;
   `epistaxis_event`.
4. `apps/daily-diary/clinical_diary/lib/services/data_export_service.dart:231`
   — re-import from exported JSON; `epistaxis_event`. (The `eventType`
   variable there is `NosebleedRecorded` / `NosebleedDeleted` — the entry
   type is the same epistaxis_event for both.)

Also updated: one integration-test call site
`apps/common-dart/append_only_datastore/integration_test/datastore_integration_test.dart:210`.

QoL/NOSE-HHT survey writes today live in QuestionnaireService and do NOT
currently call `EventRepository.append()` — they take a different path to
the server. So the plan's note "for QoL the existing code has no entry_type
today — defer that to Phase 5" is correct: Phase 2 does not need to touch
QuestionnaireService, and Phase 5 will introduce `entry_type:
nose_hht_survey` / `hht_qol_survey` as part of the EntryService cutover.

## Plan-text deviation (called out in PHASE2_TASK_1.md)

Plan Task 4 bullet said the `client_timestamp = metadata.provenance[0].received_at` duplication rule (REQ-d00118-C) "is checked by the `EventRepository.append` code path in Task 6." That's a typo — Task 6 is SembastBackend-level; the duplication happens in `EventRepository.append()` which is refactored in Task 9. REQ-d00118-C verification test therefore deferred to Task 9 per the Phase 2 Task 1 note.

## APPLICABLE_ASSERTIONS

- REQ-d00118-A — tested via `REQ-d00118-A: entryType round-trips through append`.
- REQ-d00118-B — tested via `REQ-d00118-B: no server_timestamp on
  StoredEvent.toMap output` and by the fact that `StoredEvent` no longer has a
  `serverTimestamp` field (compile-time guarantee).
- REQ-d00118-C — deferred to Task 9.
- REQ-d00118-D — out of scope for Task 4 (this concerns `aggregate_id` format
  via the new `EntryService.record()` path, which lands in Phase 5).

## Implementation notes

- Hash input extended: `_calculateEventHash` now includes `entry_type` in the
  canonical hash input, so tampering with `entry_type` is detected by chain
  verification. Pre-existing events on a freshly-initialized datastore do
  not exist (greenfield), so there is no hash migration to worry about.
- `server_timestamp` removed from `StoredEvent` (field and constructor),
  from `toMap`/`fromMap` (no read, no write), and from the `eventRecord`
  map built inside `append()`. A stale event record would fail to decode at
  `fromMap` because `entry_type` is now `as String` (required); again
  greenfield so no live records exist.
- Legacy `synced_at` field is kept on the event for Phase 2 because the
  sync-marker methods (`getUnsyncedEvents`, `markEventsSynced`,
  `getUnsyncedCount`) still use it until Phase 5. The plan Task 9 will add
  a `TODO(CUR-1154, Phase 5)` comment when those methods are looked at.
- The existing two direct-construction `StoredEvent` tests had a `serverTimestamp`
  field removed; those remaining 25 `repository.append(...)` call sites in the
  same test file had `entryType: 'epistaxis_event'` inserted above their
  `eventType:` line by a python one-shot script. Script logic: skip any
  `eventType:` whose immediately-preceding line already starts with `entryType:`
  (so the three manually-prepared tests weren't double-inserted).

## Verification

- `(cd apps/common-dart/append_only_datastore && flutter test)` — 124 tests
  pass (baseline 122 + 2 new REQ-d00118 tests).
- `(cd apps/common-dart/append_only_datastore && flutter analyze)` — No issues.
- `(cd apps/daily-diary/clinical_diary && flutter test)` — 1098 tests pass
  (unchanged; all nosebleed flows still work through the modified append
  API).
- `(cd apps/daily-diary/clinical_diary && flutter analyze)` — No issues.

## Task complete

Ready for Task 5 (`StorageBackend` and `Txn` abstract classes).
