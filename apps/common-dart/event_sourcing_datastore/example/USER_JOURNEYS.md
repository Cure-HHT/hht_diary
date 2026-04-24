# Append-Only Datastore Demo — User Journeys

> **Source**: `docs/superpowers/2026-04-22-dynamic-destinations-and-demo-design.md`

These journeys are the acceptance contract for the Phase 4.6 demo app (`apps/common-dart/event_sourcing_datastore/example/`), which exercises the library features built in Phase 4.3. Each journey is a manual walkthrough a developer runs end-to-end to validate one invariant of the Phase-4-plus-4.3 append-only datastore. They are not automated tests; the demo's value is being seen with the eyes, not asserted in a test harness.

The actor is **Alex**, a developer phase-reviewing the `event_sourcing_datastore` package prior to Phase 5 cutover.

REQ identifiers in *Validates* lines use the topic-names from the parent plan's README plus the new topics introduced in Phase 4.3 (`REQ-DEST`, `REQ-FIFO`, `REQ-SYNCPOLICY`, `REQ-SYNCCYCLE`, `REQ-ENTRY`, `REQ-BOOTSTRAP`, `REQ-DYNDEST`, `REQ-REPLAY`, `REQ-TIMEWINDOW`, `REQ-BATCH`, `REQ-SKIPMISSING`). Numeric REQ-d IDs get claimed at implementation time via `discover_requirements("next available REQ-d")` and are substituted in before commit.

---

# JNY-Datastore-Demo-01: Exercising the full demo_note lifecycle

**Actor**: Alex (Developer)
**Goal**: Confirm a single DiaryEntry aggregate can be started, completed, edited, and deleted with every event correctly persisted, materialized, and fanned out to destinations.
**Context**: Alex has just squashed Phase 4 and wants a live end-to-end check before starting Phase 5. Both destinations are set to `connection: ok`, `sendLatency: 10s`. No prior data.

**Validates**: REQ-p00004, REQ-p00006, REQ-p00013, REQ-d00004, REQ-ENTRY, REQ-FIFO, REQ-SYNCCYCLE

## Steps

1. Alex clicks **Reset all** to clear any residual state.
2. Alex enters `title="Monday"`, `body=""`, `mood=5` and clicks **Start** — a new demo_note aggregate is created at checkpoint state.
3. Alex updates the body to `"Had a good day"` on the same selected aggregate and clicks **Complete** — a `finalized` event is appended to the same aggregate.
4. Alex changes `mood` to `7` and clicks **Edit selected** → **Complete** — another `finalized` event is appended with a new `change_reason`.
5. Alex clicks **Delete selected** — a `tombstone` event is appended.
6. Alex watches each event flow through both FIFOs (yellow draining → green sent) over ~10 seconds per send.

## Expected Outcome

The **Event stream** panel shows four events for one `aggregate_id` in order: checkpoint, finalized, finalized, tombstone. The **Materialized view** shows that aggregate's row state change through `[ptl]` → `[ok]` (first answers) → `[ok]` (updated answers, whole-replacement semantics) → `[del]`. Both FIFOs show each event transitioning from `pending` to `sent`, independently and at their own send-latency pace. The hash chain across all four events is intact — clicking the most recent event reveals its `previous_event_hash` pointing at event #3's `event_hash`.

*End* *Exercising the full demo_note lifecycle*

---

# JNY-Datastore-Demo-02: Confirming the CQRS invariant

**Actor**: Alex (Developer)
**Goal**: Confirm that non-DiaryEntry action events appear in the event log and the outbound FIFOs but never in the materialized view.
**Context**: Alex wants to see with his own eyes that the `aggregate_type` discriminator is honored by the materializer. Both destinations `connection: ok`, `sendLatency: 10s`. Some demo_note history may already exist — the materialized view's row count is noted before starting.

**Validates**: REQ-p00004, REQ-DEST, REQ-SYNCCYCLE

## Steps

1. Alex notes the current row count in the **Materialized view** panel (N rows).
2. Alex clicks **Red** three times in succession.
3. Alex clicks **Green** once.
4. Alex clicks **Blue** twice.
5. Alex waits for the six events to drain through both FIFOs.

## Expected Outcome

The **Event stream** gains six new rows with `aggregate_type` values of `RedButtonPressed`, `GreenButtonPressed`, and `BlueButtonPressed` — each row with a fresh `aggregate_id`. The **Materialized view** panel's row count is still N — none of the action events have produced a `diary_entries` row. Both FIFOs gain six new entries that drain normally. Clicking any action event in the event stream shows `aggregate_type` ≠ `DiaryEntry` and `data = {pressed_at: <ISO>}`.

*End* *Confirming the CQRS invariant*

---

# JNY-Datastore-Demo-03: Observing per-destination isolation under a rejection storm

**Actor**: Alex (Developer)
**Goal**: Confirm that a permanently-rejecting destination wedges at its head and halts its own drain while leaving the other destination unaffected — the per-destination FIFO boundary is the isolation mechanism.
**Context**: Alex is validating per-destination isolation. Each destination owns its own FIFO and its own strict-order drain loop; a permanent failure on one destination halts only that destination's drain, and the other destination continues delivering on its own cadence. Both destinations `connection: ok` initially, drained to empty. Both at `batchSize = 1` for this journey (one event per batch — makes the isolation easy to see).

**Validates**: REQ-DEST, REQ-BATCH, REQ-DYNDEST, REQ-p01001

## Steps

1. Alex flips **Secondary** connection dropdown from `ok` to `rejecting`.
2. Alex clicks **Start** and **Complete** on a new demo_note — two new events appended.
3. Alex clicks **Red** once — one more event appended.
4. Alex waits ~30 seconds for both FIFOs to process.
5. Alex clicks the wedged Secondary head row, then **Tombstone & Refill** to recover and unblock the destination.

## Expected Outcome

On the **Secondary** FIFO, the first new batch-row becomes the drain head, flips yellow `draining`, then magenta `[wdg]` after its single permanent-rejection attempt records `error = "simulated rejection"`. The two later batch-rows enqueue behind the wedged head with `final_status = null` and stay pending — Secondary's drain has halted at the wedged head and does not attempt them. On the **Primary** FIFO, the same three batches drain to green `[SENT]` normally at Primary's send-latency cadence, entirely unaffected by Secondary's wedge. Clicking the wedged Secondary row populates the Detail panel with its `attempts[]` (one entry) and `final_status = wedged`. The system-wide `wedgedFifos()` probe (visible in the Detail panel when no row is selected) returns a single `WedgedFifoSummary` naming Secondary — Primary is absent. Subsequent events appended by the user continue to enqueue to Secondary behind the wedged head as pending rows; the rejection storm never blocks Primary's progress, and Secondary stays isolated at a single wedge until the operator intervenes. After step 5, Secondary's head unwedges via `tombstoneAndRefill` (see JNY-09 for the full recovery walkthrough) and the queued rows drain to green `[SENT]` on Secondary's next syncCycle ticks.

*End* *Observing per-destination isolation under a rejection storm*

---

# JNY-Datastore-Demo-04: Transient disconnect and recovery

**Actor**: Alex (Developer)
**Goal**: Confirm that a transient-failure destination holds entries `pending`, continues retrying, and catches up when the connection is restored — without any event being lost or duplicated.
**Context**: Alex is validating the SendTransient retry path. Default sync policy sliders (initialBackoff=1s, multiplier=1.0, maxAttempts=1000) — transient failures never wedge via exhaustion. Primary `ok`, Secondary `ok`. All prior events drained.

**Validates**: REQ-FIFO, REQ-SYNCPOLICY, REQ-p01001

## Steps

1. Alex flips **Primary** connection to `broken`.
2. Alex clicks **Red**, **Green**, **Blue** — three events appended.
3. Alex observes for ~10 seconds: the head of Primary's FIFO shows a red `retrying` badge; attempts accumulate in its detail panel; no entry flips to `sent`.
4. Alex flips **Primary** back to `ok`.
5. Alex waits ~35 seconds for the three entries to drain sequentially at 10s each.

## Expected Outcome

During the broken window, Primary's FIFO shows the head row in red `retrying` state with a growing `attempts[]` array on the detail panel (spaced at ~1-second intervals). No entry exhausts its retry budget because `maxAttempts` is effectively unbounded, so nothing wedges; `wedgedFifos()` returns an empty list throughout. Secondary continues to drain its own copies of the same three events normally throughout. After Primary is flipped back to `ok`, the head flips yellow `draining` within ~1 second, then green `[sent]`; the next entry takes the head and drains; the third follows. The final attempt-count on each drained entry is visible in its detail panel (one successful send preceded by several failed attempts).

*End* *Transient disconnect and recovery*

---

# JNY-Datastore-Demo-05: Tuning sync policy via sliders

**Actor**: Alex (Developer)
**Goal**: Confirm that the demo's SyncPolicy sliders directly control the drain loop's retry cadence and exhaustion threshold, verifying the Phase-4.5 retrofit that makes `SyncPolicy` injectable.
**Context**: Alex wants to see `SyncPolicy.backoffFor()` and `maxAttempts` behavior live. Both destinations `connection: ok` to start. No prior pending entries.

**Validates**: REQ-SYNCPOLICY, REQ-FIFO

## Steps

1. Alex sets **initialBackoff** slider to `3s`, **backoffMultiplier** to `2.0`, **maxBackoff** to `60s`, **maxAttempts** to `1000`.
2. Alex flips **Primary** to `broken`.
3. Alex clicks **Red** once.
4. Alex clicks the Primary FIFO's retrying head row to pin it in the **Detail** panel.
5. Alex watches the `attempts[]` list grow over ~1 minute.
6. Alex sets **maxAttempts** slider to `3`.
7. Alex clicks **Green** once and waits.

## Expected Outcome

For the first event (step 3), the Detail panel shows `attempts[]` entries at successive timestamps approximately 3 seconds, 6 seconds, 12 seconds, 24 seconds, 48 seconds, 60 seconds (capped), 60 seconds, … apart — matching the 2× growth curve capped at `maxBackoff`. For the second event (step 7), after exactly 3 attempts the FIFO head flips to magenta `wedged`; the transient-retry-exhaustion path produces the same terminal `final_status = wedged` as the permanent-rejection path, proving the two code paths converge on the same terminal state.

*End* *Tuning sync policy via sliders*

---

# JNY-Datastore-Demo-06: Rebuilding the materialized view from the event log

**Actor**: Alex (Developer)
**Goal**: Confirm that `rebuildMaterializedView()` reconstructs the `diary_entries` view as a pure projection of the `event_log` — idempotent, lossless, and with no effect on the event log itself or the FIFOs.
**Context**: Alex is validating that the materialized view is a cache, never source of truth (design §7.4). The demo has accumulated diverse history: several demo_note aggregates in various states (partial, complete, edited, deleted) and a mix of action events. Both destinations either wedged or drained — the state of the FIFOs must be preserved across the rebuild.

**Validates**: REQ-p00004, REQ-p00013

## Steps

1. Alex notes the current contents of all four panels — counts in each panel, the `[ptl]`/`[ok]`/`[del]` marks on each materialized row, and the `final_status` of each FIFO entry.
2. Alex clicks **Rebuild view**.
3. Alex observes the **Materialized view** panel clear briefly, then repopulate.
4. Alex re-examines all four panels.

## Expected Outcome

Immediately after clicking Rebuild, the Materialized view panel empties. Within a moment (proportional to event count) it refills with rows that are byte-identical to the pre-rebuild state — same aggregate_ids, same `[ptl]`/`[ok]`/`[del]` marks, same answer values, same effective-dates. The **Event stream**, **Primary** FIFO, and **Secondary** FIFO panels are completely unchanged — same row counts, same statuses, same wedged entries still wedged at the same head, same pending entries still pending. Clicking any rebuilt materialized row and any original event reveals a valid hash-chain linkage — the rebuild touches the view store only, never the event log.

*End* *Rebuilding the materialized view from the event log*

---

# JNY-Datastore-Demo-07: Adding a destination with past startDate triggers historical replay

**Actor**: Alex (Developer)
**Goal**: Confirm that adding a destination at runtime and activating it with a past startDate drives a synchronous historical replay that batches previously-logged events matching the subscription filter into the new destination's FIFO.
**Context**: Alex is validating REQ-DYNDEST (runtime add) and REQ-REPLAY (historical replay on startDate set). The demo has accumulated N events across several days, drained to both boot-time destinations. Alex needs a new "Backup" destination that captures everything from the beginning. `sendBatchSize = 5`, `maxAccumulateTime = 0`, `connection: ok`.

**Validates**: REQ-DYNDEST, REQ-REPLAY, REQ-BATCH

## Steps

1. Alex clicks **Add destination** in the top bar. In the dialog Alex sets `id = "Backup"`, `allowHardDelete = true`, and submits.
2. Alex observes a new **BACKUP** column appear in the observation grid, state labeled `DORMANT`. The column is empty — no FIFO rows.
3. Alex enters a start date earlier than any event in the event log (e.g., a date 30 days ago) into Backup's start-date editor and confirms.
4. Alex observes the Backup FIFO populate in one burst.

## Expected Outcome

After step 3, Backup's schedule-state flips to `ACTIVE`. Within the same transaction, the library walks `event_log` in sequence order, matches each event against Backup's subscription filter (any), batches events into groups of up to 5 using the destination's `canAddToBatch` rule, and inserts the resulting FIFO rows. The Backup column shows ceil(N/5) new rows, all `pending`, in sequence order. The first row's `event_ids` includes events #1 through #5; the second #6 through #10; and so on. Backup's `fill_cursor` now points at the last event's `sequence_number`. On the subsequent syncCycle tick, drain begins processing Backup's FIFO at the configured sendLatency — entries flip yellow `DRAINING` then green `[SENT]`, one at a time. Neither **Primary**, **Secondary**, nor **EVENTS**, nor **MATERIALIZED** are affected; historical replay only produces new rows in the newly-activated destination's FIFO.

*End* *Adding a destination with past startDate triggers historical replay*

---

# JNY-Datastore-Demo-08: setEndDate — closed vs scheduled return semantics

**Actor**: Alex (Developer)
**Goal**: Confirm that `setEndDate` returns `closed` on a past end-date and `scheduled` on a future one, with correct downstream enqueue behavior for each.
**Context**: Alex is validating REQ-DYNDEST assertion on setEndDate return codes and time-window enqueue filtering. Two destinations are active and drained to empty: **Primary** (will receive a future end-date) and **Secondary** (will receive a past end-date). Both `connection: ok`.

**Validates**: REQ-DYNDEST, REQ-TIMEWINDOW

## Steps

1. Alex sets Primary's end-date to 10 minutes from now. Observes the returned status label.
2. Alex sets Secondary's end-date to 1 hour ago. Observes the returned status label.
3. Alex clicks **Start** and **Complete** on a new demo_note.
4. Alex waits ~15 seconds.
5. Alex waits another 12 minutes (until Primary's end-date has passed).
6. Alex clicks **Red** once.
7. Alex waits ~15 seconds.

## Expected Outcome

Step 1 returns `scheduled`; Primary's schedule-state label reads `SCHEDULED until HH:MM:SS`. Step 2 returns `closed`; Secondary's schedule-state label reads `CLOSED @ (1h ago)`. In step 3-4, the two new events enqueue and drain through **Primary** (because their `client_timestamp` falls before Primary's scheduled end-date) but do NOT appear in **Secondary**'s FIFO at all (their `client_timestamp` is after Secondary's end-date — filter rejects). After step 5-7, Primary is now `CLOSED @ (12m ago)`; the Red event does NOT enqueue to Primary (now past its end-date) and does NOT enqueue to Secondary. The event still appears in EVENTS — the event log is source of truth and does not care about destination schedules. Setting an endDate does not delete any previously-enqueued FIFO rows; Primary's pre-close rows continue to drain normally.

*End* *setEndDate — closed vs scheduled return semantics*

---

# JNY-Datastore-Demo-09: Recovery via tombstoneAndRefill

**Actor**: Alex (Developer)
**Goal**: Confirm that when a FIFO row becomes wedged on a specific sequence position, the operator can click "Tombstone & Refill" to mark the wedged row as terminal (retained for audit), gap the sequence, and trigger fillBatch to enqueue fresh rows that can proceed unblocked.
**Context**: Alex is validating the tombstoneAndRefill recovery primitive. Secondary destination has been set to trigger a permanent send failure on a specific row (e.g., via `DemoDestination`'s **Wedge row** control, or by setting a row's condition to `SendPermanent`). The wedged row blocks the head of Secondary's FIFO; drain halts and later rows remain pending behind it.

**Validates**: REQ-FIFO, REQ-BATCH, REQ-DYNDEST

## Steps

1. Alex sets up Secondary destination with `connection: ok` and a past `startDate` to have pre-populated history.
2. Alex uses the **Wedge row** control in the demo ops drawer to mark a specific FIFO row (e.g., sequence #59) as `SendPermanent`.
3. Alex clicks **Drain** and observes Secondary's FIFO: the wedged row (sequence #59) becomes the drain head and flips yellow `draining`, then magenta `wedged` after the first permanent rejection. Later rows (e.g., sequence #60+) remain in the panel with `final_status = null` (not yet terminal).
4. Alex verifies no further deliveries occur: drain halts waiting for the head to resolve.
5. Alex clicks the wedged row (#59) in the FifoPanel to select it.
6. Alex clicks the **Tombstone & Refill** button that appears on the wedged head row.

## Expected Outcome

After step 6, the wedged row (#59) flips from `wedged` to `tombstoned` in the panel — a terminal, audit-retained state with its `attempts[]` and `final_status` still visible. The later rows (sequence #60+) that were pending behind #59 are gone from the panel (they were in the "trail" behind the wedged head and are now deleted). The `sequence_in_queue` column shows a gap: #59 (tombstoned) is followed by a new fresh row (e.g., sequence #61+) whose `sequence_in_queue` starts from 1 again after the gap. The new fresh rows have distinct `entry_id` values (fresh UUIDs, not the tombstoned row's).

On the next **syncCycle** tick, fillBatch processes events that were in the deleted trail and any new events that have arrived. Secondary's FIFO populates new pending rows covering those events with the new `entry_id` values. Drain resumes: the fresh rows flip yellow `draining`, then green `[sent]` at Secondary's configured send-latency pace. The deliveries proceed unblocked.

The audited outcome: the event originally carried by the tombstoned row (#59) is now also present in a fresh sent bundle (with a different `entry_id`, so the audit trail shows two separate delivery attempts). Later events that were stuck behind the wedge now deliver in sequence order.

*End* *Recovery via tombstoneAndRefill*

---

## How these journeys relate to automated tests

These are deliberately *not* widget tests or golden tests. The Phase-4 and Phase-4.3 library code carries its own unit tests in each package's `test/` directory (TDD cadence per the plan's README). The demo's value is visual: some invariants of an event-sourced system are best confirmed by producing the state and seeing it — per-destination isolation, the CQRS separation, historical replay, wedge recovery, and the rebuild idempotence are prime examples.

A reviewer accepting Phase 4.6 runs these nine journeys in order, checks each *Expected Outcome* against what the screen shows, and flags any discrepancy as blocking.
