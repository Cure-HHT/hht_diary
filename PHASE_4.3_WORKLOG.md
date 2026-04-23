# Phase 4.3 Worklog

One section per completed task. Current state only — no diff narration.

---

## Task 2 — Parent plan file updates

### Status
- `README.md` phase table has rows for 4.3 and 4.6 inserted between Phase 4 and Phase 5; Phase 4 description references the 2026-04-22 batch-FIFO/skip-exhausted revision; Phase 5 description flags the shrink.
- `PLAN_PHASE5_cutover.md` has a top-of-file `> **Note (2026-04-22):** ...` block naming the three moved tasks (3, 5, 6) and pointing each at its new Phase 4.3 task number. Each moved heading carries a `> Moved to Phase 4.3 (2026-04-22)` prefix.
- `PHASE4.3_TASK_2.md` records the discrepancy between the PLAN_PHASE4.3 Task-2 spec text ("Tasks 3, 4, 5") and the bullet-list intent that matches the actual PLAN_PHASE5 numbering (Tasks 3, 5, 6). Tasks 3, 5, 6 were annotated.
- `spec/dev-event-sourcing-mobile.md` already exists from Phase 1 — no action needed.

### Review decisions

Subagent review of commit `a3a06038` returned three findings (no CRITICAL, no HIGH).

**Addressed:**
- **MEDIUM — pending "Review decisions" field.** This block is now filled in (addressing the concern).
- **NIT — "One section per task" header overclaims completeness.** Header softened to "One section per completed task".

**Not addressed:**
- **LOW — commit-message task-numbering discrepancy is self-referential.** No action required; the reviewer explicitly rated this as "internally consistent and defensible". The annotation-only approach is deliberate.

---

## Task 3 — Spec additions: nine new REQ-d topics

### Status
- `spec/dev-event-sourcing-mobile.md` carries REQ-d00115 through REQ-d00134. The nine new entries (REQ-d00126..REQ-d00134) cover `SyncPolicy` as a value object, `markFinal`/`appendAttempt` missing-row tolerance, batch-FIFO shape + `fill_cursor`, the dynamic destination lifecycle and its time window, historical replay on past `startDate`, `unjamDestination`, `rehabilitate*`, `EntryService.record` (with D revised per design §6.8), and `bootstrapAppendOnlyDatastore`. Assertion text matches PLAN_PHASE4.3 verbatim.
- `spec/INDEX.md` lists all nine new REQs with content hashes computed by `elspais fix`. File is auto-regenerated; do not hand-edit.
- `elspais checks` passes 31/31 with 310 requirements validated.

### Review decisions

Subagent review of commit `9f39991b` returned two HIGH, three MEDIUM, one LOW, one NIT. No CRITICAL.

**Addressed:**
- **HIGH — REQ-d00128-F parenthetical rationale in assertion.** Stripped "(indicating a size cap)".
- **HIGH — REQ-d00129-D / REQ-d00130-A circular citation.** Removed "(per REQ-d00130)" from REQ-d00129-D. REQ-d00130's inbound reference to REQ-d00129-I is left intact — it remains a one-directional citation (the replay assertion references the window definition), not a cycle.
- **MEDIUM — REQ-d00128 Rationale used symbolic label `REQ-DYNDEST`.** Replaced with canonical `REQ-d00129`.
- **MEDIUM — REQ-d00129-F `applied` enum semantics unclear.** Added a Rationale paragraph spelling out all three `SetEndDateResult` variants with concrete triggering scenarios.
- **MEDIUM — Task 3 "Review decisions" placeholder.** Filled in with this block; workflow-designed two-commit cycle.

**Not addressed:**
- **LOW — REQ-d00133-I "migration-bridge" fields are unenforceable per REQ-d00118-C.** REQ-d00118-C's enforceability note explicitly ends "becomes active when the `EntryService.record()` path introduces `ProvenanceEntry` stamping in a later phase" — REQ-d00133 *is* that phase. REQ-d00133-I is exactly the assertion that makes REQ-d00118-C testable, and the tests live in Phase 4.3 Task 16 (`EntryService.record`). The two assertions are complementary, not contradictory.
- **NIT — REQ-d00134-C cites REQ-d00129-A.** Single one-directional cross-assertion reference is standard spec style (refine → refined-by); the reviewer's own circularity standard is met (one direction only).

### Hash updates

REQ-d00128 and REQ-d00129 bodies changed; `elspais fix` recomputed hashes; no other REQs affected.

---

## Task 4 — SyncPolicy value-object refactor (REQ-d00126)

### Status
- `apps/common-dart/append_only_datastore/lib/src/sync/sync_policy.dart` is a value class: `final` fields, `const` constructor, `backoffFor(...)` as an instance method. `SyncPolicy.defaults` is the `static const` instance carrying the REQ-d00123 curve (60s / ×5 / 2h cap / ±10% jitter / 20 attempts / 15-min interval).
- `drain(...)` and `SyncCycle(...)` accept `SyncPolicy? policy` (nullable; defaults to `SyncPolicy.defaults`). `SyncCycle` stores `_policy` and forwards it to per-destination `drain`.
- No `@Deprecated` shims; call sites reference `SyncPolicy.defaults.<field>` directly.
- `flutter test` inside `append_only_datastore` passes 305 tests (baseline was 298; +7 new tests cover REQ-d00126-A, B and a custom-policy curve sanity check). `dart analyze` and `flutter analyze` both clean.

### Review decisions

Subagent review of commit `ff1b37b9` returned one HIGH, one MEDIUM, one NIT. No CRITICAL.

**Addressed:**
- **HIGH — comment in `sync_cycle.dart` claimed exceptions are rethrown but `_drainOrSwallow` silently swallows them.** Fixed the misleading comment inside `call()` to point readers at `_drainOrSwallow` and note that exceptions are swallowed rather than re-thrown. The underlying behavior (swallowing backend exceptions in addition to `destination.send` exceptions) is a Phase-4 scope concern and is **logged below as out-of-scope** for Phase 4.3.
- **MEDIUM — `_OrderRecordingSyncCycle` test subclass did not forward `super.policy`.** Initially added `super.policy`, but `dart analyze` correctly flagged it as an unused optional parameter (no caller passes it). Reverted. If a future test needs policy injection through this subclass, the parameter can be added at that point; adding it speculatively now introduces dead code.

**Not addressed:**
- **NIT — test comment about `backoffFor(3)` cap arithmetic.** Reviewer concluded "the test assertion itself is correct; the comment is just a notation curiosity, not a defect." No change.

### Out-of-scope for Phase 4.3 (log for follow-up)
- `SyncCycle._drainOrSwallow` silently swallows all exceptions from `drain`, including backend write errors that are not captured by drain's inner `try/catch` on `destination.send`. For the audit trail this means a Sembast-layer write failure inside `drain` is lost. Fixing this is out of Phase 4.3 scope (it would touch Phase-4 behavior); file a follow-up ticket after the refactor lands.

---

## Task 5 — markFinal/appendAttempt tolerate missing (REQ-d00127)

### Status
- `SembastBackend.markFinal` and `SembastBackend.appendAttempt` no-op cleanly when the targeted FIFO row is absent, whether because the destination's store has never had writes (sembast lazy-creates stores on first write, so "unknown destination" manifests as `records.isEmpty`) or the row was deleted by a concurrent `unjamDestination` / `deleteDestination`.
- Both methods log at warning level via a package-level `_defaultLogSink` that writes through `developer.log`. A `debugLogSink` test hook on the backend captures the log in a `List<String>.add` closure without touching global logger state.
- The one-way `pending → sent|exhausted` rule in `markFinal` is retained: re-transitioning an already-terminal entry still throws `StateError`. Only the missing-row branch changed.
- Abstract `StorageBackend` documents the race this closes inline on the contract's doc comments.
- `flutter test` inside `append_only_datastore` passes 310 tests. `dart analyze` clean.

### Review decisions

Subagent review of commit `ce486bf0` returned one MEDIUM. No CRITICAL, no HIGH. Everything else clean.

**Addressed:**
- **MEDIUM — REQ-d00127-C tests only checked `drain/unjam` in the log line.** Added `expect(line, contains('drain/delete'))` to both tests so a future log-message trim that dropped either race name would be caught.

---

## Task 6 — FifoEntry batch shape migration (REQ-d00128)

### Status
- `FifoEntry` carries `eventIds: List<String>` (non-empty), `eventIdRange: ({int firstSeq, int lastSeq})`, and a single `wirePayload` / `wireFormat` / `transformVersion` per row covering the whole batch. The `entryId` row identifier is derived from the first event of the batch. Constructor rejects empty batches at construction; sembast persistence uses `event_ids` (array) and `event_id_range` (`{first_seq, last_seq}` object).
- `StorageBackend.enqueueFifo(destinationId, List<StoredEvent> batch, WirePayload wirePayload)` returns the constructed `FifoEntry`; the backend opens its own transaction, assigns `sequence_in_queue`, and rejects empty batches with `ArgumentError`. `SembastBackend.enqueueFifo` decodes `WirePayload.bytes` to a `Map` for row storage.
- Test helpers `singleEventFifoEntry`, `storedEventFixture`, `wirePayloadJson`, and `enqueueSingle` live in `test/test_support/fifo_entry_helpers.dart` to keep existing single-event test sites concise under the new signature.
- Three pre-existing Phase-4 tests that enforced caller-supplied `FifoEntry` invariants (pending/attempts-empty/sent-at-null) were removed because the new signature constructs the row internally, eliminating the caller-supplied values those tests rejected.
- `flutter test` inside `append_only_datastore` passes 319 tests. `dart analyze` and `flutter analyze` are clean.

### Review decisions

Subagent review of commit `a0ae8c1e` returned one HIGH, two MEDIUM, one LOW, one NIT. No CRITICAL. All five findings addressed.

**Addressed:**
- **HIGH — `eventIds` non-empty was `assert`-only (stripped in release).** Replaced with explicit `ArgumentError` in the `FifoEntry` constructor body. The invariant now fires in release builds.
- **MEDIUM — `firstSeq > lastSeq` on `eventIdRange` was never validated.** Added an `ArgumentError` check in the constructor; added a new REQ-d00128-B test exercising the reversed-range case.
- **MEDIUM — `entryId` field doc comment said "aggregate_id of the originating entry", which is stale.** Rewrote the doc to name it the row identifier derived from `eventIds.first`, with a forward note that a future task may introduce a distinct batch id.
- **LOW — REQ-d00119-B still listed the old `event_id` scalar field.** Updated to `event_ids` + `event_id_range`, with a cross-reference to REQ-d00128. `elspais fix` recomputed the hash.
- **NIT — test expected `AssertionError`.** Changed to `throwsArgumentError`, consistent with finding 1.

Test count: 319 → 320 (+1 for the new REQ-d00128-B reversed-range test).

---

## Task 7 — fill_cursor persistence (REQ-d00128-G)

### Status
- `StorageBackend` exposes `readFillCursor(destId)`, `writeFillCursor(destId, seq)`, and `writeFillCursorTxn(txn, destId, seq)`. `SembastBackend` implements them against the existing `backend_state` store under key `fill_cursor_$destId`. An unset cursor reads as `-1`. The transactional variant writes through the surrounding `Txn` so a rollback restores the pre-transaction value.
- Test-only `_InMemoryBackend` and `_SpyBackend` subclasses implement the new abstract methods (unimplemented stubs and forwarders respectively) so the contract remains satisfied.
- `flutter test` inside `append_only_datastore` passes 324 tests (+4 new REQ-d00128-G tests: unset default, round-trip, transactional rollback, per-destination isolation). `dart analyze` clean.

### Review decisions

Subagent review of commit `120681e1` returned two MEDIUM and one NIT. No CRITICAL, no HIGH.

**Addressed:**
- **MEDIUM — `-1` sentinel conflation between "unset" and "explicit rewind".** Updated `readFillCursor` dartdoc to document the overlap. Added a `_validateFillCursorValue` guard that rejects `sequenceNumber < -1` on both `writeFillCursor` and `writeFillCursorTxn`, so the legal domain is explicit rather than implicit. Added a REQ-d00128-G test covering the rejection.
- **MEDIUM — no contract test for fill_cursor behavior.** Added a comment in `storage_backend_contract_test.dart` pointing at where the behavioral tests live (sembast_backend_fifo_test.dart) and noting that a second `StorageBackend` implementation should replicate the tests as implementation-agnostic contract tests. Full contract-test implementation deferred until a second backend exists.

**Not addressed:**
- **NIT — `writeFillCursor` bypasses the shared `transaction()` wrapper.** Reviewer explicitly rated "not a bug", noting the standalone method's own docstring already says it opens its own transaction. Low value for the effort.

Test count: 324 → 325 (+1 for the new REQ-d00128-G validation test).

---

## Task 8 — readFifoHead skips exhausted rows (REQ-d00124-A)

### Status
- `SembastBackend.readFifoHead` returns the first row with `final_status == pending`, ordered by `sequence_in_queue`, or null when no pending rows remain. Sent and exhausted rows are skipped. `StorageBackend.readFifoHead` dartdoc revised to match.
- `spec/dev-event-sourcing-mobile.md` REQ-d00124-A is revised to describe the new head semantics; `elspais fix` updated REQ-d00124's content hash.
- Drain-loop switch cases are untouched (Task 13 will flip the SendPermanent / SendTransient-at-max cases to `continue`); readFifoHead's change alone enables the upcoming refactor while preserving drain's current wedge behavior at the switch level.
- `flutter test` inside `append_only_datastore` passes 327 tests. A Phase-4 drain-wedge test was rewritten to the new semantics (drain still returns after SendPermanent — that part moves to Task 13 — but the "readFifoHead returns null after wedge" assertion was replaced with "readFifoHead returns the next pending row").

### Review decisions

Subagent review of commit `6cde4e34` returned one LOW and one NIT. No CRITICAL, HIGH, or MEDIUM. All dimensions clean otherwise.

**Addressed:**
- **LOW + NIT — stale `// wedged` comments in `drain_test.dart`.** Updated two test-assertion comments to describe the Task-8 semantics accurately: `readFifoHead` returns null when no pending row remains after the terminal row, not because it "wedges at head" (the old semantics).

---

## Task 9 — Destination interface widened for batching

### Status
- `Destination` exposes `maxAccumulateTime: Duration`, `allowHardDelete: bool` (default `false` in the abstract), `canAddToBatch(List<StoredEvent> current, StoredEvent candidate): bool`, and `transform(List<StoredEvent> batch): Future<WirePayload>`. `transform` rejects empty batches.
- `FakeDestination` carries a `batchCapacity` constructor parameter (default 1), a default `maxAccumulateTime: Duration.zero`, `allowHardDelete: false`, and a JSON-encoded batch transform.
- `spec/dev-event-sourcing-mobile.md` REQ-d00122-D is revised for the batch-aware signature; `elspais fix` updated REQ-d00122's content hash.
- No production call site invoked `destination.transform` directly — drain reads `head.wirePayload` from the stored FIFO row — so the signature change has zero impact on drain. `fillBatch` (Task 11) will be the first consumer of the new surface.
- `flutter test` inside `append_only_datastore` passes 332 tests. `dart analyze` and `flutter analyze` clean.

### Review decisions

Subagent review of commit `c8ff70ca` returned one HIGH, one MEDIUM, one NIT. No CRITICAL. All three addressed.

**Addressed:**
- **HIGH — `transform` empty-batch contract said "implementations MAY throw".** Changed to "SHALL throw" with rationale (silent empty-bytes payload would corrupt FIFO audit semantics). The fakes already enforce it; the doc now matches.
- **MEDIUM — `canAddToBatch([], candidate)` semantics undocumented.** Added a paragraph to the method's doc comment stating that a `false` return on an empty `currentBatch` is legal but means the destination will never form a row; most destinations should return `true` for the empty-current case.
- **NIT — `_DefaultDestination.transform` silently accepted empty batches.** Added the `ArgumentError` guard so it matches the pattern established by `FakeDestination` and `_EchoDestination`.

### Incidental commit content
- `TODO4.4.md` (user-authored Phase 4.4 scope note) was in the worktree and got swept into the review-fix commit by `git add -A`. Unrelated to Task 9; kept in the commit to avoid history juggling.

---

## Task 10 — DestinationRegistry dynamic mutation (REQ-d00129)

### Status
- `DestinationRegistry` is instance-based, constructed with a `StorageBackend`. No singleton. Runtime-open surface: `addDestination`, `byId`, `all`, `scheduleOf`, `setStartDate` (one-shot immutable), `setEndDate` returning `SetEndDateResult { closed, scheduled, applied }`, `deactivateDestination` (shorthand for `setEndDate(id, now)`), `deleteDestination` (gated on `allowHardDelete`, drops FIFO store + schedule in one transaction, removes the id from `known_fifo_destinations`).
- New value types: `DestinationSchedule` (`startDate`, `endDate`, `isDormant`, `isActiveAt(now)`), `SetEndDateResult` enum, `UnjamResult` (parked for Task 14).
- `StorageBackend` exposes `readSchedule`, `writeSchedule`, `writeScheduleTxn`, `deleteScheduleTxn`, `deleteFifoStoreTxn`. Schedules persist under `backend_state` key `schedule_$destId`. `deleteFifoStoreTxn` drops the sembast store, the fill-cursor record, and removes the id from `known_fifo_destinations`.
- `DestinationRegistry.matchingDestinations` removed — `fillBatch` (Task 11) is the consumer and iterates per-destination.
- `setStartDate` has a `TODO(Task 12)` at the past-date branch; replay wiring lands in Task 12.
- REQ-d00122-G revised to describe the dynamic lifecycle; `elspais fix` updated REQ-d00122's hash.
- `flutter test` inside `append_only_datastore` passes 343 tests. `dart analyze` and `flutter analyze` clean.

### Review decisions

Subagent review of commit `92f28eca` returned one CRITICAL, one HIGH, one MEDIUM. All three addressed.

**Addressed:**
- **CRITICAL — `startDate` immutability broken across process restart.** `addDestination` unconditionally overwrote any persisted schedule with a dormant one, so bootstrap's re-run wiped the `setStartDate` value. Now `addDestination` reads the persisted schedule first: if one exists, it seeds the in-memory cache from persistence and skips the write; only when no schedule is persisted does it seed the dormant default. Added a REQ-d00129-C cold-restart test.
- **HIGH — `setEndDate` returned `scheduled` for future→future replacement on an active destination.** REQ-d00129-F says `applied` is the right code when no active/closed transition happens AND no new close is newly scheduled. Added a `wasScheduled` predicate: `scheduled` now fires only when `endDate` newly becomes future (i.e., `isScheduled && !wasScheduled`). Added a REQ-d00129-F test for the future→future case.
- **MEDIUM — no cold-restart test.** Covered by the REQ-d00129-C test above (register, setStartDate, simulate restart with a fresh registry over the same backend, re-addDestination with the same id, verify persisted startDate survives and re-assignment throws).

Test count: 343 → 345 (+2).

---

## Task 11 — fillBatch algorithm (REQ-d00128 + REQ-d00129-I)

### Status
- `lib/src/sync/fill_batch.dart` implements `fillBatch(destination, backend, schedule, clock)`:
  - Walks the event log past `fill_cursor` for the destination.
  - Filters candidates by the destination's `filter` and the `[startDate, min(endDate, now)]` window.
  - Assembles a batch greedily via `canAddToBatch` until the destination says stop.
  - Holds single-event batches until `maxAccumulateTime` elapses.
  - Non-matching tail advances `fill_cursor` without enqueuing (idempotent).
  - Enqueue and cursor-advance happen in one transaction via `enqueueFifoTxn` + `writeFillCursorTxn`.
- `StorageBackend.enqueueFifoTxn(Txn, destId, batch, wirePayload)` is the transactional variant; `enqueueFifo` now delegates to it so row-construction lives in one place.
- `flutter test` inside `append_only_datastore` passes 354 tests (+9 new REQ-d00128-E/F/G/H + REQ-d00129-I tests). `dart analyze` and `flutter analyze` clean.

### Review decisions

*(pending — dispatched after commit)*

---

## Per-task controller workflow (user instructions — re-read each task)

> After each phase I want you to:
> - append to `PHASE_4.3_WORKLOG.md` a very brief outline of the work done. Don't say "it was like that before, now its like this." Just say "it works like this". I.e. don't keep repeating history, just report the status.
> - commit the changes
> - Launch a sub-agent to review the commit. Tell it NOT to read the `docs/` folder. I want an unbiased code review.
> - decide which of the review comments to address and which to not address. Log both to WORKLOG.
> - commit again
> - include these instructions at the end of WORKLOG each phase.
> - re-read these instructions.
> Then proceed to the next phase.

("phase" here denotes each numbered task of Phase 4.3; the full Phase 4.3 is a single commit after the phase-squash at Task 20.)
