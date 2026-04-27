# Merge-Semantics Materialization (Design Spec)

**Date**: 2026-04-23
**Ticket**: CUR-1154 (Phase 4.8 on the existing `mobile-event-sourcing-refactor` branch)
**Scope**: `event_sourcing_datastore` library — materializer semantics, `EntryService.record` contract interpretation, REQs that define the fold.

## 1. Problem

REQ-d00121-B/C as currently defined have the materializer **whole-replace** `current_answers` on every `finalized` or `checkpoint` event: the event's `data.answers` is treated as the new full state, and any field present in a prior row but absent from the event is dropped. Three consequences follow:

- Each event must carry the complete current state. An update that changes one field still emits the whole form's payload on the wire and in storage.
- The audit trail can't answer "what did the user change at this moment" from a single event. It can only answer "what was the full state after this moment," and reconstructing the change requires diffing event N against event N-1.
- The fold-based rebuild machinery (`rebuildMaterializedView`, `Materializer.apply` invoked per event in sequence) is structurally over-engineered for whole-replace semantics, which could be computed trivially by taking the latest event per aggregate.

Merge semantics make each event carry **only the keys the caller chose to include**; the materializer folds those deltas over prior state; the event IS the change. The fold-based implementation becomes correctly-sized for the semantics. No caller API change is required — the existing `EntryService.record({answers: Map, ...})` shape continues to work, it just interprets `answers` as a delta.

## 2. Design

### 2.1 Merge rule

On a `finalized` or `checkpoint` event, the new `current_answers` is:

```text
current = {...prior.current_answers}
for each key k in event.data.answers:
  current[k] = event.data.answers[k]   // explicit value, including null
```

Concretely in Dart:

```dart
final merged = Map<String, Object?>.from(prior.currentAnswers ?? const {});
for (final key in event.data['answers'].keys) {
  merged[key] = event.data['answers'][key];
}
```

The event determines a key's fate by **presence**, not by value:

- **Key absent from `event.data.answers`** → prior value survives unchanged.
- **Key present with non-null value** → field set to that value (or changed, or confirmed with the same value).
- **Key present with value `null`** → field explicitly cleared; `current_answers[key]` becomes `null` (present in the map, value null).

Dart's `Map<String, Object?>` distinguishes "key absent" from "key present with null value" via `containsKey`; `jsonEncode` / `jsonDecode` round-trip both cases correctly. The materializer uses `containsKey`-style iteration (via `for ... in keys`) rather than indexing, so the distinction is preserved.

### 2.2 `is_complete` under merge

`finalized` sets `is_complete: true`; `checkpoint` sets `is_complete: false`. The `is_complete` field remains a top-level property of `DiaryEntry` (not inside `current_answers`), unchanged from current REQ-d00121-B/C. Only the `current_answers` field's semantics change.

### 2.3 Tombstone

REQ-d00121-D is unchanged. `tombstone` events preserve `current_answers` and `is_complete` from prior, flip `is_deleted` to true. Tombstone does NOT merge — it is an orthogonal flag.

### 2.4 Hash-chain identity

REQ-d00120 (canonical event hashing) hashes the event's identity fields including `data`. Under merge, `data.answers` is the delta; under whole-replace it was the full state. The hash still uniquely identifies the event. Callers receiving events can still verify `event_hash` against the canonicalized event. No protocol-layer change; only the semantic of `data.answers` shifts.

### 2.5 No-op detection

The existing REQ-d00133-F defines no-op detection by comparing canonical content hashes of `(event_type, canonical(answers), checkpoint_reason, change_reason)`. Under merge, a more precise no-op rule is also available: an event is a no-op if merging its `data.answers` over `prior.current_answers` produces a map equal to `prior.current_answers` — i.e., every key in `data.answers` is either absent, or present with the same value the prior already had.

Both rules catch "the user saved a form identical to prior state." The merge-aware rule additionally catches "the user submitted a delta whose values all match prior" — which under whole-replace would be indistinguishable from "user submitted whole state identical to prior." The library adopts the merge-aware rule. Implementation: compute the merged result, compare (`DeepCollectionEquality.equals`) against prior; on equality, return without writing.

### 2.6 Rebuild semantics

`rebuildMaterializedView` already folds events through `Materializer.apply` in sequence per aggregate (REQ-d00121-G). The implementation does not change; only the per-event apply function changes. Rebuild is now a meaningful fold rather than "take the latest event per aggregate," matching the implementation's shape.

### 2.7 Caller API shape

`EntryService.record({aggregateId, entryType, eventType, answers: Map<String, Object?>, checkpointReason?, changeReason?})` is unchanged. The semantic of `answers` changes from "full new state" to "delta." Callers that already construct their `answers` map via conditional spread (`if (x != null) 'key': x`) — such as `NosebleedService.addRecord` today — are naturally delta-shaped and land correctly under merge without code change.

Callers that want to clear a previously-set field pass `field: null` explicitly. Callers that never want to set or clear a field simply omit the key.

The library does not provide a `computeDelta(prior, newState)` helper. Callers that want whole-form-state semantics over this API compute their own diff; the library's contract is only "store what I give you; merge it at read time."

### 2.8 Sync-through compatibility

`Materializer.apply` is a pure function of `(prior, event, def, firstEventTimestamp)` (REQ-d00121-A). Under merge semantics this purity extends to a composition property: folding the same sequence of events in the same order produces the same `current_answers`, whether the fold runs on the device that originated the events, on a server that received them via sync, or on any later rebuild. Sync-through is therefore a wire-level concern — the receiving side stores the event bytes verbatim (via a destination-specific ingest path, out of scope for this design) and its materializer applies the same merge rule to produce a bit-identical materialized view.

This composition property requires in-order fold: the deltas in event `N` are defined against the prior state that events `1..N-1` produced, so out-of-order application of a delta over the wrong prior state produces wrong results. Incremental materialization therefore depends on REQ-d00124-H's strict-order delivery guarantee per destination (Phase 4.7 drain-halt semantics); rebuild-from-scratch (REQ-d00121-G) sorts by `sequence_number` before folding and is safe regardless of arrival order.

Sync-through does not introduce any new event type and does not require `Materializer.apply` to distinguish "originated here" from "received from elsewhere." The identity encoded in `event_id` (a v4 UUID minted by the originator — see REQ-d00141 / REQ-d00118), `initiator` (REQ-d00135), `metadata.provenance` (REQ-d00115), and `event_hash` (REQ-d00120) is preserved on the wire by carbon-copy transforms; the materializer treats received events identically to locally-originated ones. A receiver that wishes to add its own hop to the provenance chain interacts with a separate ingest-path design (deferred, tracked in the project's deferred-items memory as item 1) and is beyond the scope of this spec.

- Rewriting `NosebleedService` (or any consumer app) to take advantage of merge. Consumer apps are restored to main and cut over in Phase 5.
- Removing `isIncomplete` as a stored field (nosebleed-specific). It becomes derivable from `current_answers` membership under merge, but the consumer app's data model is not touched in this PR.
- Removing supersession-chain patterns (`parentRecordId` in nosebleed data). Consumer app concern; Phase 5.
- Changing `EntryService.record` call-site signatures. The param list stays the same.
- Adding flags, helpers, or policy knobs to the record API. The semantic is fixed: absent key = untouched, present key = set, `null` = clear.
- Schema migration machinery. Greenfield; no deployed callers.

## 4. Specification changes

### 4.1 REQ-d00121 (diary_entries Materialization from Event Log)

**Assertion B rewrite** (was: whole-replace on finalized; now: merge):

> B. When `event.event_type` equals `"finalized"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_complete` is `true` and whose `current_answers` equals the key-wise merge of `prior.current_answers` (or the empty map when `prior` is null) under `event.data.answers`: every key present in `event.data.answers` overwrites the prior value (including an explicit `null`), and every key absent from `event.data.answers` preserves the prior value.

**Assertion C rewrite** (checkpoint, same merge rule):

> C. When `event.event_type` equals `"checkpoint"`, `Materializer.apply` SHALL return a `DiaryEntry` whose `is_complete` is `false` and whose `current_answers` is produced by the same merge rule as assertion B.

**Assertion D unchanged** (tombstone preserves current_answers, flips is_deleted).

**New assertion J** (presence vs value):

> J. `Materializer.apply` SHALL distinguish "key absent from `event.data.answers`" from "key present with value `null`" when computing the merged `current_answers`: the first preserves the prior value for that key; the second sets the merged `current_answers[key]` to `null` (the key is present in the merged map with a null value). Implementations SHALL iterate `event.data.answers` via its key set rather than indexing, so absent keys are not confused with present-null keys.

**Rationale paragraph rewrite**: strike whole-replacement language from REQ-d00121's rationale. Replace with merge framing: the event data is the delta the caller chose to apply; the materializer folds deltas onto prior state in sequence; each event captures its own change, not the resulting full state. Note that `jsonEncode`/`jsonDecode` preserve presence vs. null-valued distinction, which the wire format depends on.

### 4.2 REQ-d00133 (EntryService.record Contract)

**Assertion F rewrite** (no-op detection under merge):

> F. `EntryService.record` SHALL detect no-ops against the merged result: if the merge of `answers` over the prior `current_answers` (computed by the same rule as REQ-d00121-B) equals the prior `current_answers` — including `is_complete` matching the event_type — the call SHALL return successfully without writing a new event. Other no-op dimensions (`checkpoint_reason`, `change_reason`) SHALL still be compared against the most recent event on the aggregate.

Assertions A, B, C, D, E unchanged.

**Rationale update**: replace references to "canonical content hash of (event_type, canonical(answers), ...)" with the merge-aware rule. Note that the caller's `answers` param is now a delta; the no-op check computes the merge result and compares it against prior.

### 4.3 No new REQ needed

The merge rule, presence vs null distinction, and no-op semantics all fit into the existing REQ-d00121 and REQ-d00133. No REQ number is claimed for this phase.

## 5. Implementation

### 5.1 Code delta

- `lib/src/materialization/materializer.dart` — `DiaryEntriesMaterializer.apply` (or wherever the finalized/checkpoint branches live): replace whole-replace with key-wise merge. `tombstone` branch unchanged.
- `lib/src/entry_service.dart` — `EntryService.record`'s no-op detection: replace the canonical-content-hash comparison with the merge-compare rule.
- Spec text updates to REQ-d00121 rationale + assertions B/C, REQ-d00133 rationale + assertion F.
- Tests:
  - `test/materialization/materializer_test.dart` — update existing finalized/checkpoint tests to assert merge behavior; add new tests for the three merge cases (absent key preserves, present-non-null overwrites, present-null clears).
  - `test/entry_service_test.dart` — update no-op detection tests to the merge rule; delete tests that relied on the content-hash comparison if they're now redundant.
  - Any integration test that implicitly relied on whole-replace semantics: audit and update.
- No library surface change (no new exports, no API signature changes).

### 5.2 Tests to add

- **Merge — absent key preserves prior**: Prior `{a: 1, b: 2}`; event `{a: 9}`; merged `{a: 9, b: 2}`.
- **Merge — present-null clears**: Prior `{a: 1, b: 2}`; event `{b: null}`; merged `{a: 1, b: null}`. Verify `containsKey('b')` is true and `merged['b']` is null.
- **Merge — present-non-null overwrites**: Prior `{a: 1}`; event `{a: 2}`; merged `{a: 2}`.
- **Merge — empty delta on empty prior**: Prior null; event `{}`; merged `{}`.
- **Merge — empty delta on non-empty prior**: Prior `{a: 1}`; event `{}`; merged `{a: 1}`. (Under merge semantics, this is valid; the event changes nothing. No-op detection should catch it before persisting.)
- **No-op detection — whole-state-identical**: Prior `{a: 1}`; caller passes `{a: 1}`; no event written.
- **No-op detection — delta-all-match-prior**: Prior `{a: 1, b: 2}`; caller passes `{a: 1}`; no event written. (Under whole-replace this was a no-op; under merge with merge-aware rule it's still a no-op.)
- **Not-no-op — delta adds new field**: Prior `{a: 1}`; caller passes `{b: 2}`; event written; merged `{a: 1, b: 2}`.
- **Not-no-op — delta clears field**: Prior `{a: 1}`; caller passes `{a: null}`; event written; merged `{a: null}`.
- **JSON round-trip preserves null-vs-absent**: Build event with `{a: null}`, serialize to JSON, decode, re-serialize, verify the `a` key remains present with null value.

### 5.3 Tests to update

- Every test that previously asserted "finalized whole-replaces current_answers" and was constructed to verify that specific behavior (a prior field being dropped when the event didn't include it) should be re-cast to assert merge semantics — the prior field is now preserved if the event omits the key, dropped only if the event has the key with `null`.
- Tests that constructed a whole-state payload for a single-field change should be simplified to pass just the changed field.

### 5.4 Tests to delete

- Any test whose assertion is literally "absent key drops prior value" (the whole-replace invariant) — this is now false and the test is wrong rather than just stale.

## 6. Risks and open questions

**Risk 1 — Caller discipline for forms that present empty fields.** Callers that build `answers` with `{'field': ''}` (empty string) for untouched fields, or `{'field': null}` when they mean "not touched," will write wrong deltas. Mitigation: document the contract in the `EntryService.record` doc comment; the nosebleed service's conditional-spread pattern is the reference style and can be called out. No library-level enforcement.

**Risk 2 — No-op detection expense.** Computing the merged result for every `record()` call to detect no-ops adds work that whole-replace's content-hash rule didn't require. The cost is one map copy and one iteration over the event's keys; not significant for typical entry-type maps (5–20 keys). If it ever matters, fall back to the content-hash shortcut for cases where `event.data.answers` has every key the prior had, with the same values — but not worth optimizing until measured.

**Risk 3 — Wire protocols that don't preserve null.** Some serialization paths drop null-valued keys by default. Dart's `jsonEncode` / `jsonDecode` preserve them; sembast's `Map<String, Object?>` storage preserves them. If a future destination transforms events through a library that strips null keys, the "explicit clear" semantic would silently become "untouched" — a real data-integrity issue. Mitigation: add a test that exercises a destination's `transform` with a null-containing event and asserts the wire bytes include the null. Document the expectation on `Destination.transform`.

**Open question (out-of-scope for this design)**: `isIncomplete` on NosebleedRecord (computed at write-time today) could become derivable from `current_answers` under merge. This is a consumer-app concern for Phase 5; the library doesn't care either way.

## Requirements

Applicable assertions defined in `spec/dev-event-sourcing-mobile.md`:

- REQ-d00115, REQ-d00118 (event schema)
- REQ-d00120 (hash chain)
- REQ-d00121 (Materializer.apply purity, key-wise merge for finalized/checkpoint, tombstone preservation)
- REQ-d00124 (drain semantics)
- REQ-d00133 (EntryService no-op detection under merge)
- REQ-d00135, REQ-d00141 (initiator, source identity)

Per-implementation `// Implements:` and per-test `// Verifies:` annotations required on every implementation/test file this phase touches. Implementation plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.8_merge_materialization.md`.
