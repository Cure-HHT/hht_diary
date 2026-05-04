# PHASE 4.3 TASK 13 — Drain continues past exhausted (REQ-d00124-D+E)

## Summary

Flipped `drain()`'s `SendPermanent` and `SendTransient`-at-`maxAttempts`
switch cases from `return` to `continue`. Combined with Phase-4.3 Task 8
(which made `readFifoHead` skip `exhausted` rows and return the next
pending row in `sequence_in_queue` order), `drain` no longer wedges on
an exhausted row: within a single drain invocation, the loop marks the
head exhausted, iterates back to `readFifoHead`, observes the next
pending row, and attempts it.

`SendTransient` below the `maxAttempts` cap still `return`s so the
backoff (REQ-d00124-F) applies on the next drain tick — no change
there.

REQ-d00124-D, REQ-d00124-E, REQ-d00124-H, and REQ-d00124-A's
"wedge-preserved-by-drain" parenthetical were revised in
`spec/dev-event-sourcing-mobile.md` to describe continue-past-exhausted
semantics. The Rationale paragraphs that described the wedge as
"load-bearing" were revised to describe exhaustion as an audit-trail
marker that does not block later pending rows.

Implements: REQ-d00124-D (revised), REQ-d00124-E (revised).

## TDD sequence

1. **Baseline**: `flutter test` in
   `apps/common-dart/append_only_datastore` — **358 / 358 green**.
   `dart analyze` clean.
2. **Red — tests first**: updated four tests in
   `test/sync/drain_test.dart` to encode the new semantics:
   - `REQ-d00124-D`: enqueue `e1` and `e2`; script `[SendPermanent,
     SendOk]`; assert `dest.sent.length == 2` (e2 was attempted) and
     `readFifoHead == null` (e1 exhausted, e2 sent).
   - `REQ-d00124-E`: enqueue `e1` (pre-seeded with `maxAttempts-1`
     transient attempts) and `e2`; script `[SendTransient, SendOk]`;
     assert `dest.sent.length == 2` (e2 was attempted) and
     `readFifoHead == null`.
   - `REQ-d00124-G`: extended script to `[SendOk, SendPermanent,
     SendOk]` across `e1/e2/e3`; assert `attemptsByEntry['e3'] == 1`
     instead of `== 0` (e3 was reached because drain continued past
     the exhausted e2).
   - `REQ-d00124-H`: renamed from "wedge on e1 prevents attempting
     e2/e3" to "drain attempts e1, e2, e3 in enqueue order"; script
     `[SendPermanent, SendOk, SendOk]`; decode each
     `WirePayload.bytes` as JSON and assert `event_id` sequence
     `['e1', 'e2', 'e3']` (FIFO ordering preserved, exhaustion skipped
     in-place).
   Ran `flutter test test/sync/drain_test.dart` — **4 failed** as
   expected (D, E, G, H).
3. **Green — implementation**: changed two cases in
   `lib/src/sync/drain.dart`:
   - `case SendPermanent():` — `return` → `continue`.
   - `case SendTransient():` when `attempts.length + 1 >=
     effective.maxAttempts` — `return` → `continue`; the
     below-cap branch still `return`s to honor backoff (REQ-d00124-F).
   Added `// Implements: REQ-d00124-D+E — ...` comment on the switch
   block; rewrote the function's doc comment to describe the
   continue-past-exhausted flow (previously described the wedge).
   Reran drain tests — **13 / 13 green**.
4. **Full-suite verify**: `flutter test` — **358 / 358 green**
   (no net change; four tests updated in-place, zero added/removed).
5. **Analyze**: `dart analyze` (append_only_datastore) — **No issues
   found.** `flutter analyze` (clinical_diary) — **No issues found!**
6. **Spec revision**: updated `spec/dev-event-sourcing-mobile.md`
   REQ-d00124-A parenthetical, REQ-d00124-D, REQ-d00124-E, REQ-d00124-H
   assertion text, and the two Rationale paragraphs that described
   the wedge as load-bearing. Ran `elspais fix` — refreshed
   REQ-d00124's content hash; five unrelated PRD changelog sections
   were auto-added by elspais's maintenance pass.

## Test counts

- Baseline: **358 / 358**.
- Final: **358 / 358**. Delta: **0**. Four drain tests were updated
  in-place; no tests added or removed.

## Analyze results

- `dart analyze` (append_only_datastore): **No issues found.**
- `flutter analyze` (clinical_diary): **No issues found!**

## Files touched

### Modified

- `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart`
  - `case SendPermanent():` — `return` → `continue`.
  - `case SendTransient():` at-max branch — `return` → `continue`;
    below-cap branch unchanged (still `return` for backoff).
  - Rewrote function doc comment: "wedge" narrative replaced with
    continue-past-exhausted description; REQ-d00124-H now described
    as within-pass ordering.
  - Added `// Implements: REQ-d00124-D+E` comment on the switch block.
- `apps/common-dart/append_only_datastore/test/sync/drain_test.dart`
  - `dart:convert` import added for the REQ-d00124-H payload decode.
  - REQ-d00124-D: new two-row assertion (continue past exhausted).
  - REQ-d00124-E: new two-row assertion (same shape as D).
  - REQ-d00124-G: extended script + assertion (e3 now has 1 attempt).
  - REQ-d00124-H: reframed from "wedge prevents later attempts" to
    "drain attempts e1, e2, e3 in enqueue order"; decodes `WirePayload`
    bytes to verify the FIFO order of `event_id`s across send calls.
- `spec/dev-event-sourcing-mobile.md`
  - Rationale paragraphs 2–3: rewritten to describe continue-past-
    exhausted semantics (exhaustion as audit marker, not FIFO wedge).
    REQ-p01001-D (FIFO delivery order) is explicitly preserved: send
    invocations still match `sequence_in_queue` order.
  - REQ-d00124-A: stripped the "wedge-preserved-by-drain"
    parenthetical; replaced with an audit-trail note citing
    REQ-d00119-D.
  - REQ-d00124-D: "return" → "CONTINUE to the next pending row";
    cites REQ-d00124-A for the skip-exhausted read path.
  - REQ-d00124-E: same revision shape as D; explicit "same continue-
    past-exhausted semantics as D".
  - REQ-d00124-H: dropped "or exhausted" from the ordering constraint;
    added an explicit clause that exhausted rows are skipped in-place.
  - `elspais fix` refreshed REQ-d00124's content hash.

### Created

- `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/task_files/PHASE4.3_TASK_13.md`
  (this file).

## Notes

- The `multi-destination independence` drain test (SendPermanent on
  d1's only row, SendOk on d2's only row) did not need updating: with
  one row per destination, `continue` reads `readFifoHead == null` on
  the next iteration and returns the same way `return` did. The
  observable behavior is identical.
- The `REQ-d00126-B: SyncCycle propagates injected policy to drain`
  test in `sync_cycle_test.dart` did not need updating for the same
  reason — one row per destination means continue and return collapse.
- The `REQ-d00124-F+B` backoff test is unchanged: SendTransient below
  the cap still returns, so the subsequent re-drain without elapsed
  backoff still is a no-op.
- `SendTransient` at max: the current code path runs `markFinal` then
  `continue`s. It does NOT clear the attempts log on transition from
  pending to exhausted — that is correct per REQ-d00119-E/F (append-
  only audit). The exhausted row stays in the store at its original
  `sequence_in_queue` for audit, and `readFifoHead` (REQ-d00124-A)
  skips over it on the next iteration.
- No changes to `StorageBackend`, `SembastBackend`, `SyncCycle`, or
  any other module: Task 13 is strictly a drain.dart switch-case flip
  plus test + spec maintenance.
