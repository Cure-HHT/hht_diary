# Phase 2 Task 3: Storage-layer value types

**Date:** 2026-04-21
**Status:** COMPLETE

## Files created

Pure-Dart value types under `apps/common-dart/append_only_datastore/lib/src/storage/`:

- `append_result.dart` — sequence_number + event_hash round-trip
- `attempt_result.dart` — one historical send attempt (attempted_at, outcome, error_message, http_status)
- `diary_entry.dart` — materialized view row (8 fields, currentAnswers deep-equals)
- `exhausted_fifo_summary.dart` — wedged-FIFO diagnostic payload
- `fifo_entry.dart` — FIFO row carrying all 10 documented columns
- `final_status.dart` — enum pending|sent|exhausted
- `send_result.dart` — sealed `SendOk | SendTransient | SendPermanent`

Tests: `test/storage/value_types_test.dart` (32 cases).

## APPLICABLE_ASSERTIONS

- REQ-d00117-C (appendEvent advances sequence counter) — AppendResult shape.
- REQ-d00117-D (upsertEntry whole-row replace) — DiaryEntry value type.
- REQ-d00119-B (FIFO entry field list) — FifoEntry test asserts all 10 fields.
- REQ-d00119-C (final_status is pending|sent|exhausted) — FinalStatus enum +
  REQ-d00119-C: prefixed tests: `FinalStatus has exactly three values` and
  `final_status is typed as FinalStatus`.
- REQ-d00119-D (non-pending entries retained forever) — documented on
  AttemptResult and ExhaustedFifoSummary class dartdoc, reinforced at runtime
  by SembastBackend (Task 8).
- REQ-p01001-L (three-category send classification) — SendResult sealed
  hierarchy with exhaustiveness test.

## Plan deviations

- **Field count on FifoEntry**: the plan text said "nine design-doc-§7.1
  columns." The design doc §7.1 and REQ-d00119-B both list ten columns
  (entry_id, event_id, sequence_in_queue, wire_payload, wire_format,
  transform_version, enqueued_at, attempts, final_status, sent_at). Test and
  implementation carry all ten. Plan-text miscount noted here.

- **copyWithEffectiveNull helper on DiaryEntry**: added as a test-support
  affordance to let the round-trip test construct an explicit
  `effectiveDate=null` variant cleanly. Minimal surface; documented as a test
  helper in its dartdoc. Will be removed (or promoted to a general
  `copyWith`) if the production code paths in Phase 3 need it.

## New dependency

- `collection: ^1.19.0` added as a direct dep (was previously only
  transitive). Used for `DeepCollectionEquality` on `currentAnswers` and
  `wirePayload`, and `ListEquality<AttemptResult>` on `attempts`. Same
  pattern adopted by trial_data_types in Phase 1.

## Dartdoc cross-reference discipline

The analyzer initially flagged 6 `comment_references` warnings from
`[TypeName]` references to types that live in files this package doesn't
yet import (`SendResult` on AttemptResult docs, `SyncPolicy` on SendResult
docs, `FifoEntry` on FinalStatus docs, etc.). Resolution: degrade those to
unbracketed plain text so the dartdoc link is dead-obvious rather than
silently broken. Full cross-references get re-added in the Tasks that
introduce the missing type (Task 5 for `StorageBackend`/`Txn`).

## Type-guard + flow analysis notes

For nullable-optional fields (`effectiveDate`, `sentAt`, `transformVersion`),
the pattern

```dart
final raw = json['x'];
if (raw != null && raw is! String) throw ...;
// raw's static type here is Object?, not String? — Dart's flow analysis
// does not combine the negative-on-is check with null-check narrowing.
sentAt: raw == null ? null : DateTime.parse(raw as String),
```

keeps the `as String` cast deliberately (the analyzer marks it necessary; my
earlier removal of the cast broke the build). The cast is runtime-unreachable
because the preceding type guard already excluded non-String non-null values;
it exists only for type-system satisfaction.

By contrast for required-non-null fields, the positive `is!` throw promotes
the variable:

```dart
if (answersRaw is! Map) throw ...;
// answersRaw promoted to Map here — no `as Map` needed.
Map<String, Object?>.from(answersRaw);
```

Both patterns are in use across the six files; comments not added because
the pattern is self-evident to any Dart developer familiar with flow
analysis.

## Verification

- `flutter test` in `append_only_datastore`: 122 tests pass (baseline 90 +
  32 new).
- `flutter analyze` in `append_only_datastore`: No issues found.

## Commit

Next step: commit as
"[CUR-1154] Add storage-layer value types".
